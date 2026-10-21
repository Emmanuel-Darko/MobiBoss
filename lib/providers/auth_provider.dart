import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Subscription tiers — determines what features are gated.
enum SubscriptionState { loading, trial, active, expired }

/// Manages Supabase authentication state and subscription status.
///
/// The reconciliation screen is the only feature gated behind a paid
/// subscription. All other screens remain freely accessible.
class AuthProvider extends ChangeNotifier {
  User? _user;
  SubscriptionState _subState = SubscriptionState.loading;
  Map<String, dynamic>? _profile;
  RealtimeChannel? _profileChannel;
  bool _isInitialized = false;
  bool _isClockTampered = false;
  String? _deviceId;

  // ─── Public Getters ───
  User? get user => _user;
  SubscriptionState get subscriptionState => _subState;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;
  bool get isClockTampered => _isClockTampered;
  String? get deviceId => _deviceId;

  /// True if user has reconciliation access (active subscription OR live trial)
  /// and device clock has not been tampered.
  bool get hasReconciliationAccess =>
      !_isClockTampered &&
      (_subState == SubscriptionState.active ||
       _subState == SubscriptionState.trial);

  /// Days remaining on the trial / subscription (0 if expired).
  int get daysRemaining =>
      _profile != null ? SupabaseService.daysRemaining(_profile!) : 0;

  /// Human-readable plan name.
  String get planDisplayName {
    if (_profile == null) return 'Free';
    final plan = _profile!['plan'] as String? ?? 'free';
    switch (plan) {
      case 'pro':
        return 'Pro';
      case 'business':
        return 'Business';
      default:
        return 'Free';
    }
  }

  AuthProvider() {
    _init();
  }

  // ─── Initialization ───

  Future<void> _init() async {
    // Restore existing session (persisted by supabase_flutter)
    _user = SupabaseService.currentUser;
    if (_user != null) {
      await _loadSubscription();
      _listenToProfileRealtime();
    } else {
      _subState = SubscriptionState.expired;
    }
    _isInitialized = true;
    notifyListeners();

    // React to auth state changes going forward
    SupabaseService.onAuthStateChange.listen((data) {
      final newUser = data.session?.user;
      if (newUser != null && _user?.id != newUser.id) {
        // New login
        _user = newUser;
        _loadSubscription();
        _listenToProfileRealtime();
      } else if (newUser == null && _user != null) {
        // Signed out
        _user = null;
        _profile = null;
        _subState = SubscriptionState.expired;
        _profileChannel?.unsubscribe();
        _profileChannel = null;
      }
      notifyListeners();
    });
  }

  // ─── Subscription ───

  Future<void> _loadSubscription() async {
    final prevState = _subState;
    _subState = SubscriptionState.loading;
    if (prevState != SubscriptionState.loading) notifyListeners();

    _deviceId ??= await SupabaseService.getDeviceId();

    // 1. Hardware Device Fingerprint verification via Supabase RPC
    if (_deviceId != null && _deviceId != 'unknown_device') {
      final deviceResult = await SupabaseService.claimOrVerifyDeviceTrial(_deviceId!);
      if (deviceResult != null) {
        final serverTimeStr = deviceResult['server_time'] as String?;
        if (serverTimeStr != null) {
          final serverTime = DateTime.tryParse(serverTimeStr);
          if (serverTime != null) {
            _isClockTampered = await SupabaseService.isClockTampered(serverTime);
          }
        }

        final isAllowed = deviceResult['is_allowed'] == true;
        final status = (deviceResult['status'] ?? 'expired').toString();

        if (!isAllowed || status == 'expired' || _isClockTampered) {
          _subState = SubscriptionState.expired;
        } else {
          _subState = status == 'trial' ? SubscriptionState.trial : SubscriptionState.active;
        }

        _profile = await SupabaseService.fetchProfile();
        notifyListeners();
        return;
      }
    }

    // 2. Standard Profile fallback if RPC is not yet applied on Supabase
    _profile = await SupabaseService.fetchProfile();
    if (_profile == null) {
      // 3. Network unreachable: check if 48-hour offline lease is still valid
      final leaseValid = await SupabaseService.isOfflineLeaseValid();
      _subState = leaseValid ? SubscriptionState.active : SubscriptionState.expired;
    } else {
      final active = SupabaseService.isSubscriptionActive(_profile!);
      final isTrial = _profile!['subscription_status'] == 'trial';
      _subState = active
          ? (isTrial ? SubscriptionState.trial : SubscriptionState.active)
          : SubscriptionState.expired;
    }
    notifyListeners();
  }

  /// Dynamically verifies subscription on landing on the Reconcile tab
  Future<void> verifyAccessOnLanding() async {
    if (_user != null) {
      await _loadSubscription();
    }
  }

  void _listenToProfileRealtime() {
    _profileChannel?.unsubscribe();
    if (_user == null) return;
    _profileChannel = SupabaseService.subscribeToProfile(
      _user!.id,
      // When the MobiBoss website updates the user's subscription, re-fetch
      (_) => _loadSubscription(),
    );
  }

  /// Manually refresh subscription status (e.g. user taps "I've paid").
  Future<void> refreshSubscription() => _loadSubscription();

  // ─── Auth Actions ───

  /// Returns null on success, or an error message string.
  Future<String?> signIn(String email, String password) async {
    try {
      await SupabaseService.signIn(email, password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Returns null on success, or an error message string.
  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      await SupabaseService.signUp(
        email,
        password,
        fullName: fullName,
        phone: phone,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await SupabaseService.resetPassword(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    _user = null;
    _profile = null;
    _subState = SubscriptionState.expired;
    _profileChannel?.unsubscribe();
    _profileChannel = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    super.dispose();
  }
}
