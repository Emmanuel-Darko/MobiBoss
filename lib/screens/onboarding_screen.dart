import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../widgets/top_toast.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _shopNameCtrl = TextEditingController(text: 'My MoMo Kiosk');
  final TextEditingController _ownerNameCtrl = TextEditingController(text: 'Shop Owner');
  final TextEditingController _ownerPhoneCtrl = TextEditingController();
  final TextEditingController _openingCashCtrl = TextEditingController(text: '1500.00');

  @override
  void dispose() {
    _pageController.dispose();
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _openingCashCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final shopName = _shopNameCtrl.text.trim().isNotEmpty ? _shopNameCtrl.text.trim() : 'My MoMo Kiosk';
    final ownerName = _ownerNameCtrl.text.trim().isNotEmpty ? _ownerNameCtrl.text.trim() : 'Shop Owner';
    final ownerPhone = _ownerPhoneCtrl.text.trim();
    final openingCash = double.tryParse(_openingCashCtrl.text.trim()) ?? 1500.0;

    final profile = ShopProfile(
      shopName: shopName,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      branchLocation: 'Main Kiosk',
    );

    final provider = context.read<MoMoProvider>();
    await provider.completeOnboarding(profile: profile, openingCash: openingCash);

    if (mounted) {
      TopToast.show(
        context,
        title: 'Welcome to MobiBoss!',
        message: 'Your shop profile is ready. Start transacting or balancing!',
        icon: Icons.check_circle_rounded,
        backgroundColor: const Color(0xFF1E8E3E),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/app_logo.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.point_of_sale_rounded, color: Color(0xFF1A73E8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MobiBoss',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Skip Tour'),
                    ),
                ],
              ),
            ),

            // Carousel Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildSlide1(isDark),
                  _buildSlide2(isDark),
                  _buildSlide3(isDark),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  // Page Indicator Dots
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF1A73E8) : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Next / Get Started Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _nextPage,
                    icon: Icon(_currentPage == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      _currentPage == 2 ? 'Launch MobiBoss' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFE8F0FE),
            child: Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 28),
          const Text(
            'Smart SMS Balancing',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Never calculate manually again. MobiBoss automatically reads incoming MTN MoMo, Telecel Cash, and AT Money confirmation messages to balance cash with SIM float in seconds.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip('MTN • Telecel • AT', Icons.cell_tower_rounded, const Color(0xFF1A73E8)),
              _buildFeatureChip('Shift Bounded', Icons.schedule_rounded, const Color(0xFF1E8E3E)),
              _buildFeatureChip('Reversal Guard', Icons.security_rounded, const Color(0xFFE37400)),
              _buildFeatureChip('100% Offline', Icons.cloud_off_rounded, const Color(0xFF5F6368)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlide2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFE6F4EA),
            child: Icon(Icons.point_of_sale_rounded, size: 48, color: Color(0xFF1E8E3E)),
          ),
          const SizedBox(height: 28),
          const Text(
            'Cash Drawer & WhatsApp Reports',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Count Ghana Cedis notes and coins using the built-in Denomination Counter. When the shift ends, send an instant audit summary directly to the Boss via WhatsApp.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip('Note Denominations', Icons.payments_rounded, const Color(0xFF1E8E3E)),
              _buildFeatureChip('Petty Cash Tracker', Icons.shopping_bag_outlined, const Color(0xFFE37400)),
              _buildFeatureChip('1-Tap WhatsApp Report', Icons.send_rounded, const Color(0xFF1E8E3E)),
              _buildFeatureChip('Bluetooth 58mm POS', Icons.print_rounded, const Color(0xFF1A73E8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlide3(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFFF4CC),
                child: Icon(Icons.storefront_rounded, color: Color(0xFFF9AB00), size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Kiosk Setup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Step 3 of 3 • 1-Minute Setup',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _shopNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Kiosk Name',
                      hintText: 'e.g. KODETECH MoMo Kiosk',
                      prefixIcon: Icon(Icons.store_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ownerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Owner / Attendant Name',
                      hintText: 'e.g. Kwame Mensah',
                      prefixIcon: Icon(Icons.person_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ownerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Owner WhatsApp Number',
                      hintText: 'e.g. 0244123456',
                      prefixIcon: Icon(Icons.phone_rounded, size: 20),
                      helperText: 'Daily shift summaries will be sent here',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openingCashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening Drawer Cash Float (GHS)',
                      prefixText: 'GHS ',
                      prefixIcon: Icon(Icons.point_of_sale_rounded, size: 20),
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

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
