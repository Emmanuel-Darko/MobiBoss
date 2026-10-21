-- ==============================================================================
-- MOBIBOSS ANTI-ABUSE & DEVICE FINGERPRINTING SCHEMA
-- Prevents trial farming across app data clears, reinstalls, and clock rollbacks
-- ==============================================================================

-- 1. Create device_trials table tracking physical hardware IDs
CREATE TABLE IF NOT EXISTS public.device_trials (
  device_id TEXT PRIMARY KEY,
  first_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  first_trial_ends_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  last_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Enable RLS
ALTER TABLE public.device_trials ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view device records
DROP POLICY IF EXISTS "Allow authenticated read device_trials" ON public.device_trials;
CREATE POLICY "Allow authenticated read device_trials" ON public.device_trials
  FOR SELECT TO authenticated USING (true);

-- Allow service_role full control
DROP POLICY IF EXISTS "Service role full access device_trials" ON public.device_trials;
CREATE POLICY "Service role full access device_trials" ON public.device_trials
  FOR ALL TO service_role USING (true);

-- 2. Stored Function: Claim or Verify Device Trial
-- Callable by client RPC securely with SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.claim_or_verify_device_trial(
  p_device_id TEXT,
  p_user_id UUID,
  p_trial_days INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_device RECORD;
  v_profile RECORD;
  v_trial_ends TIMESTAMPTZ;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  -- Validate inputs
  IF p_device_id IS NULL OR p_device_id = '' OR p_device_id = 'unknown_device' THEN
    -- Fallback to standard profile check if device identifier unavailable
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
    IF v_profile IS NOT NULL AND (v_profile.subscription_status = 'active' OR (v_profile.subscription_status = 'trial' AND v_profile.trial_ends_at > v_now)) THEN
      RETURN jsonb_build_object(
        'is_allowed', TRUE,
        'status', v_profile.subscription_status,
        'trial_ends_at', v_profile.trial_ends_at,
        'server_time', v_now
      );
    ELSE
      RETURN jsonb_build_object(
        'is_allowed', FALSE,
        'status', 'expired',
        'server_time', v_now
      );
    END IF;
  END IF;

  -- 1. Check if user already has an active paid subscription
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;

  IF v_profile IS NOT NULL AND v_profile.subscription_status = 'active' THEN
    IF v_profile.subscription_ends_at IS NULL OR v_profile.subscription_ends_at > v_now THEN
      -- Record device for tracking
      INSERT INTO public.device_trials (device_id, first_user_id, first_trial_ends_at, last_seen_at, last_user_id)
      VALUES (p_device_id, p_user_id, v_now + (p_trial_days || ' days')::INTERVAL, v_now, p_user_id)
      ON CONFLICT (device_id) DO UPDATE SET last_seen_at = v_now, last_user_id = p_user_id;

      RETURN jsonb_build_object(
        'is_allowed', TRUE,
        'status', 'active',
        'subscription_ends_at', v_profile.subscription_ends_at,
        'server_time', v_now
      );
    END IF;
  END IF;

  -- 2. Check if this physical device already claimed a trial before
  SELECT * INTO v_device FROM public.device_trials WHERE device_id = p_device_id;

  IF v_device IS NULL THEN
    -- First time this physical device is seen: Grant 7-day trial bound to this device!
    v_trial_ends := v_now + (p_trial_days || ' days')::INTERVAL;
    
    INSERT INTO public.device_trials (device_id, first_user_id, first_trial_ends_at, last_seen_at, last_user_id)
    VALUES (p_device_id, p_user_id, v_trial_ends, v_now, p_user_id);

    -- Sync user profile
    UPDATE public.profiles
    SET subscription_status = 'trial',
        trial_ends_at = v_trial_ends,
        updated_at = v_now
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
      'is_allowed', TRUE,
      'status', 'trial',
      'trial_ends_at', v_trial_ends,
      'server_time', v_now,
      'device_registered', TRUE
    );
  ELSE
    -- Device was seen before!
    UPDATE public.device_trials
    SET last_seen_at = v_now,
        last_user_id = p_user_id
    WHERE device_id = p_device_id;

    -- Check if the device's original trial is still running
    IF v_device.first_trial_ends_at > v_now THEN
      -- Device is still in its original trial period
      UPDATE public.profiles
      SET subscription_status = 'trial',
          trial_ends_at = v_device.first_trial_ends_at,
          updated_at = v_now
      WHERE id = p_user_id;

      RETURN jsonb_build_object(
        'is_allowed', TRUE,
        'status', 'trial',
        'trial_ends_at', v_device.first_trial_ends_at,
        'server_time', v_now,
        'device_reused', TRUE
      );
    ELSE
      -- Device trial has expired! Block even if user cleared data or registered new account!
      UPDATE public.profiles
      SET subscription_status = 'expired',
          trial_ends_at = v_device.first_trial_ends_at,
          updated_at = v_now
      WHERE id = p_user_id;

      RETURN jsonb_build_object(
        'is_allowed', FALSE,
        'status', 'expired',
        'trial_ends_at', v_device.first_trial_ends_at,
        'server_time', v_now,
        'device_blocked', TRUE,
        'reason', 'Device trial period has expired'
      );
    END IF;
  END IF;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.claim_or_verify_device_trial(TEXT, UUID, INT) TO authenticated, service_role, anon;
