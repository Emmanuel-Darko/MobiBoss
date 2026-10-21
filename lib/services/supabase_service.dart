import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service wrapping all Supabase interactions.
/// The app uses this for auth and subscription status — never for payments.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static const MethodChannel _nativeChannel = MethodChannel('com.kodetech.mobiboss/ussd');

  // ─────────────────────── Hardware & Clock Security ───────────────────────

  /// Fetches unique hardware device ID (Android ID)
  static Future<String> getDeviceId() async {
    try {
      final String? id = await _nativeChannel.invokeMethod<String>('getDeviceId');
      if (id != null && id.isNotEmpty) return id;
    } catch (e) {
      debugPrint('[SupabaseService] getDeviceId error: $e');
    }
    return 'unknown_device';
  }

  /// Fetches monotonic hardware uptime (milliseconds since boot)
  static Future<Map<String, int>?> getSystemClockInfo() async {
    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getSystemClockInfo');
      if (res != null) {
        return {
          'elapsedRealtime': (res['elapsedRealtime'] as num).toInt(),
          'currentTimeMillis': (res['currentTimeMillis'] as num).toInt(),
        };
      }
    } catch (e) {
      debugPrint('[SupabaseService] getSystemClockInfo error: $e');
    }
    return null;
  }

  /// Validates whether the user's phone clock has been rolled backwards
  static Future<bool> isClockTampered(DateTime serverTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVerifiedMs = prefs.getInt('last_verified_server_time_ms') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Clock is at least 3 minutes behind a previously recorded verified server time
      if (lastVerifiedMs > 0 && nowMs < (lastVerifiedMs - 180000)) {
        return true;
      }

      final serverMs = serverTime.millisecondsSinceEpoch;
      if (serverMs > lastVerifiedMs) {
        await prefs.setInt('last_verified_server_time_ms', serverMs);
      }
    } catch (_) {}
    return false;
  }

  /// Records an offline lease valid for up to 48 hours
  static Future<void> recordOfflineLease({
    required String status,
    required DateTime serverTime,
    DateTime? expiresAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_verified_server_time_ms', serverTime.millisecondsSinceEpoch);

      // Max lease duration: 48 hours or subscription end date, whichever is earlier
      final maxLease = DateTime.now().add(const Duration(hours: 48));
      final effectiveLeaseEnd = (expiresAt != null && expiresAt.isBefore(maxLease))
          ? expiresAt
          : maxLease;

      await prefs.setInt('offline_lease_expires_ms', effectiveLeaseEnd.millisecondsSinceEpoch);
      await prefs.setString('offline_lease_status', status);
    } catch (_) {}
  }

  /// Checks if cached offline lease is still active (under 48 hours)
  static Future<bool> isOfflineLeaseValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leaseExpiresMs = prefs.getInt('offline_lease_expires_ms') ?? 0;
      final leaseStatus = prefs.getString('offline_lease_status') ?? 'expired';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (leaseExpiresMs <= 0 || nowMs > leaseExpiresMs) {
        return false;
      }
      return leaseStatus == 'active' || leaseStatus == 'trial';
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────── Auth ───────────────────────

  static Session? get currentSession => _client.auth.currentSession;
  static User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes (sign in, sign out, token refresh).
  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> signUp(
    String email,
    String password, {
    String? fullName,
    String? phone,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
        },
      );

  static Future<void> signOut() => _client.auth.signOut();

  static Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  // ─────────────────── Profile / Subscription ───────────────────

  /// Fetches the logged-in user's profile row from the `profiles` table.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('profiles')
          .select(
              'full_name, phone, shop_name, plan, subscription_status, trial_ends_at, subscription_ends_at')
          .eq('id', uid)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] fetchProfile error: $e');
      return null;
    }
  }

  /// Claims or verifies device-fingerprinted trial via Supabase RPC
  static Future<Map<String, dynamic>?> claimOrVerifyDeviceTrial(String deviceId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    try {
      final res = await _client.rpc('claim_or_verify_device_trial', params: {
        'p_device_id': deviceId,
        'p_user_id': uid,
      });

      if (res is Map<String, dynamic>) {
        final serverTimeStr = res['server_time'] as String?;
        final serverTime = serverTimeStr != null ? DateTime.tryParse(serverTimeStr) : null;
        final status = (res['status'] ?? 'expired').toString();
        final trialEndsStr = (res['trial_ends_at'] ?? res['subscription_ends_at']) as String?;
        final endsAt = trialEndsStr != null ? DateTime.tryParse(trialEndsStr) : null;

        if (serverTime != null) {
          await recordOfflineLease(status: status, serverTime: serverTime, expiresAt: endsAt);
        }
        return res;
      }
    } catch (e) {
      debugPrint('[SupabaseService] claimOrVerifyDeviceTrial error: $e');
    }
    return null;
  }

  /// Determines whether the user currently has access (active sub or live trial).
  static bool isSubscriptionActive(Map<String, dynamic> profile) {
    final status = profile['subscription_status'] as String? ?? 'expired';

    if (status == 'active') {
      final ends = DateTime.tryParse(
          (profile['subscription_ends_at'] ?? '').toString());
      // Active with no end date = lifetime, or end date in the future
      return ends == null || ends.isAfter(DateTime.now());
    }

    if (status == 'trial') {
      final ends =
          DateTime.tryParse((profile['trial_ends_at'] ?? '').toString());
      return ends != null && ends.isAfter(DateTime.now());
    }

    return false;
  }

  /// Calculates days remaining on trial or subscription.
  static int daysRemaining(Map<String, dynamic> profile) {
    final status = profile['subscription_status'] as String? ?? 'expired';
    final key =
        status == 'trial' ? 'trial_ends_at' : 'subscription_ends_at';
    final ends = DateTime.tryParse((profile[key] ?? '').toString());
    if (ends == null) return 0;
    return ends.difference(DateTime.now()).inDays.clamp(0, 999);
  }

  /// Subscribes to real-time Postgres changes on the user's profile row.
  /// When the MobiBoss website updates `subscription_status`, the callback fires.
  static RealtimeChannel subscribeToProfile(
    String userId,
    void Function(Map<String, dynamic> newRecord) onUpdate,
  ) {
    return _client
        .channel('profile:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Updates the user's own editable profile fields (name, phone, shop).
  /// Subscription fields are service-role-only (updated by website backend).
  static Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? shopName,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (shopName != null) updates['shop_name'] = shopName;
    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', uid);
  }
}
