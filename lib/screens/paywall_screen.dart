import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// Shown in place of ReconciliationScreen when the user is either:
/// 1. Not logged in (requires auth)
/// 2. Logged in, but trial / subscription has expired (behind paywall)
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isRefreshing = false;

  Future<void> _openSubscribePage(String email) async {
    final uri = Uri.parse(
        'https://mobiboss.com/subscribe?email=${Uri.encodeComponent(email)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refreshSubscription() async {
    setState(() => _isRefreshing = true);
    await context.read<AuthProvider>().refreshSubscription();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final auth = context.read<AuthProvider>();
    if (auth.hasReconciliationAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription activated! 🎉 Reconciliation is now unlocked.'),
          backgroundColor: Color(0xFF1E8E3E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active subscription found yet. If you just paid, please allow a moment for processing.'),
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final userEmail = auth.user?.email ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            // ── Top Icon & Status Badge ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isLoggedIn
                      ? const Color(0xFFFBBC04).withValues(alpha: 0.15)
                      : const Color(0xFF1A73E8).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLoggedIn ? Icons.lock_clock_rounded : Icons.lock_outline_rounded,
                  size: 42,
                  color: isLoggedIn ? const Color(0xFFD97706) : const Color(0xFF1A73E8),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isLoggedIn
                    ? const Color(0xFFD93025).withValues(alpha: 0.1)
                    : const Color(0xFF1E8E3E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLoggedIn ? Icons.timer_off_outlined : Icons.card_giftcard_rounded,
                    size: 14,
                    color: isLoggedIn ? const Color(0xFFD93025) : const Color(0xFF1E8E3E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLoggedIn
                        ? 'Trial Expired'
                        : '14-Day Free Trial Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLoggedIn ? const Color(0xFFD93025) : const Color(0xFF1E8E3E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Headline & Explainer ──
            Text(
              isLoggedIn
                  ? 'Upgrade to Unlock Reconciliation'
                  : 'Daily MoMo Reconciliation',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoggedIn
                  ? 'Your 14-day free trial has expired. Subscribe to MobiBoss Pro on our website to continue balancing your daily drawer with carrier SMS.'
                  : 'Automate your daily drawer balancing, catch shortages, and audit carrier SMS. Sign in or create an account to start your 14-day free trial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                height: 1.4,
              ),
            ),

            // ── Logged In User Pill ──
            if (isLoggedIn) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFF5F6368)),
                    const SizedBox(width: 6),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => auth.signOut(),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1A73E8), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Pro Feature List ──
            _buildFeatureCard(
              context,
              features: const [
                _Feature(Icons.fact_check_rounded, 'SMS Auto-Reconciliation',
                    'Scans your device SMS inbox and instantly checks all MTN, Telecel, AT Money, and G-Money alerts.'),
                _Feature(Icons.analytics_rounded, 'AI Variance Diagnosis',
                    'Automatically detects whether your drawer has a shortage or overage and suggests exact root causes.'),
                _Feature(Icons.swap_horiz_rounded, 'Shift Closing & Settlement',
                    'Settles attendant shifts cleanly — your closing physical cash carries forward to the next teller.'),
                _Feature(Icons.receipt_long_rounded, 'Smart Denomination Counter',
                    'Count 100, 50, 20, 10, and 5 cedi notes with instant variance calculation.'),
                _Feature(Icons.history_rounded, 'Shift History & Audit Trail',
                    'Permanent records of all past shifts with timestamped shortage/overage logs.'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Primary Call to Action ──
            if (!isLoggedIn) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _navigateToLogin,
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text(
                    'Sign In or Start 14-Day Free Trial',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No credit card required. All other screens (Transact, Ledger, SIM Floats) are 100% free to use.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF80868B),
                ),
              ),
            ] else ...[
              // Logged in, expired -> Website subscription flow
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _openSubscribePage(userEmail),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text(
                    'Subscribe on MobiBoss.com',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshSubscription,
                  icon: _isRefreshing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _isRefreshing ? 'Checking Status...' : "I've Paid — Check Status",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : const Color(0xFF202124))
                      .withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF8AB4F8)
                          : const Color(0xFF1A73E8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'When your payment is confirmed on our website, this tab will unlock automatically in real-time.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF9AA0A6)
                              : const Color(0xFF80868B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required List<_Feature> features}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Included with MobiBoss Pro',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 14),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(f.icon, size: 16, color: const Color(0xFF1A73E8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF9AA0A6)
                                : const Color(0xFF5F6368),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
}
