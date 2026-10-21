import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service wrapping all Supabase interactions.
/// The app uses this for auth and subscription status — never for payments.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

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
