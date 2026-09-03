import 'package:flutter/material.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';

class CustomerTestScreen extends StatefulWidget {
  const CustomerTestScreen({super.key});

  @override
  State<CustomerTestScreen> createState() => _CustomerTestScreenState();
}

class _CustomerTestScreenState extends State<CustomerTestScreen> with WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '1');
  final TextEditingController _refController = TextEditingController(text: 'TEST');

  final TextEditingController _customRootCodeController = TextEditingController(text: '*170#');
  final TextEditingController _customStepsController = TextEditingController(text: '6, 1');

  String _lastStatus = '';
  bool _isAccessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await UssdService.isAccessibilityEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _customRootCodeController.dispose();
    _customStepsController.dispose();
    super.dispose();
  }

  Future<void> _executeAutomatedFlow({
    required String title,
    required String rootCode,
    required List<String> steps,
  }) async {
    if (!_isAccessibilityEnabled) {
      _showEnableAccessibilityDialog();
      return;
    }

    TopToast.show(
      context,
      title: 'USSD Session in Progress',
      message: 'Testing $title ($rootCode → ${steps.length} steps)... Enter PIN when prompted.',
      icon: Icons.science_rounded,
      backgroundColor: const Color(0xFF1A73E8),
    );

    try {
      final bool success = await UssdService.initiateCustomAutomatedSession(
        rootCode: rootCode,
        steps: steps,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _lastStatus += '\n   ✅ USSD dialed. Accessibility service will auto-navigate ${steps.length} steps.';
        });
      } else {
        setState(() {
          _lastStatus += '\n   ⚠️ Fallback: Opened dialer without auto-navigation.';
        });
      }
    } catch (e) {
      setState(() {
        _lastStatus = '❌ Error: $e';
      });
    }
  }

  void _showEnableAccessibilityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accessibility Service Required'),
        content: const Text(
          'The USSD Auto-Navigation service must be enabled in your Android Accessibility Settings. '
          'This allows MoMo Boss to automatically fill USSD menu prompts.\n\n'
          'Look for "MomoBoss" in the list and enable it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              UssdService.openAccessibilitySettings();
            },
            child: const Text('Open Accessibility Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneController.text.trim().isEmpty ? '0244123456' : _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 1.0;
    final amtStr = amount.toStringAsFixed(0);
    final ref = _refController.text.trim().isEmpty ? 'TEST' : _refController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accessibility Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isAccessibilityEnabled ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isAccessibilityEnabled ? const Color(0xFF1E8E3E) : const Color(0xFFD93025),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAccessibilityEnabled ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _isAccessibilityEnabled ? const Color(0xFF1E8E3E) : const Color(0xFFD93025),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAccessibilityEnabled
                              ? 'USSD Auto-Navigation: ENABLED ✓'
                              : 'USSD Auto-Navigation: DISABLED',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isAccessibilityEnabled ? const Color(0xFF1E8E3E) : const Color(0xFFD93025),
                          ),
                        ),
                        Text(
                          _isAccessibilityEnabled
                              ? 'Service will auto-fill USSD menus up to PIN prompt.'
                              : 'Enable the Accessibility Service to auto-navigate USSD menus.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                        ),
                      ],
                    ),
                  ),
                  if (!_isAccessibilityEnabled)
                    TextButton(
                      onPressed: () => UssdService.openAccessibilitySettings(),
                      child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lab Warning Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF7E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF9AB00)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_rounded, color: Color(0xFFE37400), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Temporary *170# Customer Test Lab — will be removed in production.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Customer Test Parameters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Input Parameters',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Recipient Number',
                        hintText: '0244123456',
                        prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Amount (GHS)',
                              prefixText: 'GHS ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _refController,
                            decoration: InputDecoration(
                              labelText: 'Reference',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Pre-Built Customer Flow Buttons
            const Text(
              'MTN Customer (*170#) Automated Flows',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF202124)),
            ),
            const SizedBox(height: 8),

            _buildTestCard(
              title: 'Send Money (Transfer)',
              subtitle: '*170# → 1 → 1 → $phone → $phone → GHS $amtStr → $ref → 🔒 PIN',
              icon: Icons.send_rounded,
              color: const Color(0xFF1E8E3E),
              onTap: () => _executeAutomatedFlow(
                title: 'Send Money',
                rootCode: '*170#',
                steps: ['1', '1', phone, phone, amtStr, ref],
              ),
            ),
            const SizedBox(height: 8),

            _buildTestCard(
              title: 'Check Balance (My Wallet)',
              subtitle: '*170# → # (next page) → 6 → 1 → 🔒 PIN',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF1A73E8),
              onTap: () => _executeAutomatedFlow(
                title: 'Check Balance',
                rootCode: '*170#',
                steps: ['#', '6', '1'],
              ),
            ),
            const SizedBox(height: 8),

            _buildTestCard(
              title: 'Allow Cash Out',
              subtitle: '*170# → 4 → 1',
              icon: Icons.lock_open_rounded,
              color: const Color(0xFFE37400),
              onTap: () => _executeAutomatedFlow(
                title: 'Allow Cash Out',
                rootCode: '*170#',
                steps: ['4', '1'],
              ),
            ),
            const SizedBox(height: 8),

            _buildTestCard(
              title: 'Buy Airtime (Self)',
              subtitle: '*170# → 3 → 1 → 1 → GHS $amtStr → 🔒 PIN',
              icon: Icons.phone_forwarded_rounded,
              color: const Color(0xFF9334E6),
              onTap: () => _executeAutomatedFlow(
                title: 'Buy Airtime',
                rootCode: '*170#',
                steps: ['3', '1', '1', amtStr],
              ),
            ),
            const SizedBox(height: 16),

            // Custom Step Sequence Tester
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom USSD Sequence Tester',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Test any multi-turn USSD menu on any telecom.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customRootCodeController,
                      decoration: InputDecoration(
                        labelText: 'Root USSD Code',
                        hintText: '*170# or *110# or *124#',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customStepsController,
                      decoration: InputDecoration(
                        labelText: 'Comma-Separated Steps',
                        hintText: 'e.g. 1, 1, 0244123456, 50',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Execute Custom Sequence'),
                      onPressed: () {
                        final root = _customRootCodeController.text.trim();
                        final steps = _customStepsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        _executeAutomatedFlow(title: 'Custom ($root)', rootCode: root, steps: steps);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Status Card
            if (_lastStatus.isNotEmpty) ...[
              Card(
                color: const Color(0xFFE8F0FE),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Automation Status:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A73E8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastStatus,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF202124), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8EAED)),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: const Text('Run', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
