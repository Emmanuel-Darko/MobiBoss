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

  // ─── Public Getters ───
  User? get user => _user;
  SubscriptionState get subscriptionState => _subState;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;

  /// True if user has reconciliation access (active subscription OR live trial).
  bool get hasReconciliationAccess =>
      _subState == SubscriptionState.active ||
      _subState == SubscriptionState.trial;

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
    // Only notify if we transitioned — avoids unnecessary rebuilds on init
    if (prevState != SubscriptionState.loading) notifyListeners();

    _profile = await SupabaseService.fetchProfile();
    if (_profile == null) {
      _subState = SubscriptionState.expired;
    } else {
      final active = SupabaseService.isSubscriptionActive(_profile!);
      final isTrial = _profile!['subscription_status'] == 'trial';
      _subState = active
          ? (isTrial ? SubscriptionState.trial : SubscriptionState.active)
          : SubscriptionState.expired;
    }
    notifyListeners();
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
