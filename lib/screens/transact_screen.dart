import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mobiboss_provider.dart';
import '../models/mobiboss_models.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';
import '../services/phone_helper.dart';
import 'services_screen.dart';

class TransactScreen extends StatefulWidget {
  const TransactScreen({super.key});

  @override
  State<TransactScreen> createState() => _TransactScreenState();
}

class _TransactScreenState extends State<TransactScreen> with WidgetsBindingObserver {
  int _transactMode = 0; // 0: Cash Operations, 1: Services & Bills
  TransactionType _selectedType = TransactionType.cashIn;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isUssdStepsExpanded = false;
  bool _useCrossNetworkMmi = false;

  final List<double> _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<MoMoProvider>();
      provider.checkAccessibilityState();
      provider.checkRecentCarrierSms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final activeTill = provider.selectedTill;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final rawPhone = _phoneController.text.trim();
    final customerPhone = rawPhone.isEmpty ? '024XXXXXXX' : rawPhone;
    final detectedNet = rawPhone.length >= 3 ? PhoneHelper.detectNetwork(PhoneHelper.normalize(rawPhone)) : null;
    final isCrossNetwork = detectedNet != null && detectedNet != activeTill.network;

    final MultiStepUssdPlan plan;
    if (_useCrossNetworkMmi && isCrossNetwork) {
      plan = UssdService.buildCrossNetworkMmiPlan(
        destinationNetwork: detectedNet,
        customerPhone: customerPhone,
        amount: amount,
      );
    } else {
      plan = UssdService.buildMultiStepPlan(
        till: activeTill,
        type: _selectedType,
        customerPhone: customerPhone,
        amount: amount,
      );
    }

    if (_transactMode == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildModeSwitcher(),
          ),
          const Expanded(child: ServicesScreen()),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeSwitcher(),
          const SizedBox(height: 12),

          // Accessibility Service Enablement Banner
          if (!provider.isAccessibilityEnabled) ...[
            Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF332600) : const Color(0xFFFEF7E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF7A5900) : const Color(0xFFF9AB00),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE37400),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Auto-USSD Automation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-navigates multi-step menus up to PIN entry and captures callbacks.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFFFD54F) : const Color(0xFF1A73E8),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => UssdService.openAccessibilitySettings(),
                        child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // 1. Till Selector Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: activeTill.network == NetworkProvider.mtn
                          ? const Color(0xFFFFF4CC)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sim_card_rounded,
                      color: activeTill.network == NetworkProvider.mtn
                          ? const Color(0xFFF9AB00)
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTill.tillName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Float: GHS ${activeTill.currentFloat.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E8E3E), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: activeTill.id,
                    underline: const SizedBox(),
                    items: provider.tills.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text(t.network.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.selectTill(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Transaction Type Segmented Pills
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.cashIn,
                label: Text('Cash In (Deposit)', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.arrow_downward_rounded, size: 16),
              ),
              ButtonSegment(
                value: TransactionType.cashOut,
                label: Text('Cash Out (Withdraw)', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.arrow_upward_rounded, size: 16),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (set) => setState(() => _selectedType = set.first),
          ),
          const SizedBox(height: 14),

          // 3. Customer Phone Input with Directory Picker
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (val) {
              setState(() {});
              if (val.length >= 3) {
                final norm = PhoneHelper.normalize(val);
                final net = PhoneHelper.detectNetwork(norm);
                if (net != null) {
                  final matching = provider.tills.where((t) => t.network == net);
                  if (matching.isNotEmpty) {
                    provider.selectTill(matching.first.id);
                  }
                }
              }
            },
            decoration: InputDecoration(
              labelText: 'Customer Mobile Number',
              hintText: '0244123456',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.contacts_rounded, color: Color(0xFF1A73E8)),
                tooltip: 'Customer Directory',
                onPressed: () => _showCustomerDirectoryModal(context, provider),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          if (_phoneController.text.trim().length >= 2) ...[
            Builder(
              builder: (ctx) {
                final typed = _phoneController.text.trim();
                final normTyped = PhoneHelper.normalize(typed);
                final suggestions = provider.customerContacts.where((c) {
                  final normC = PhoneHelper.normalize(c.phone);
                  return normC.contains(normTyped) || c.name.toLowerCase().contains(typed.toLowerCase());
                }).take(4).toList();

                if (suggestions.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: suggestions.map((c) {
                        final norm = PhoneHelper.normalize(c.phone);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.person_rounded, size: 14, color: Color(0xFF1A73E8)),
                            label: Text(
                              '${c.name.split(' ').first} (${PhoneHelper.formatDisplay(norm)})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              setState(() {
                                _phoneController.text = norm;
                              });
                              final net = PhoneHelper.detectNetwork(norm);
                              if (net != null) {
                                final matching = provider.tills.where((t) => t.network == net);
                                if (matching.isNotEmpty) {
                                  provider.selectTill(matching.first.id);
                                }
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
          if (isCrossNetwork) ...[
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF374151)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_calls_rounded, size: 18, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cross-network: ${detectedNet.name.toUpperCase()} recipient from ${activeTill.network.name.toUpperCase()} Till',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Use *170# MMI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: _useCrossNetworkMmi,
                    selectedColor: const Color(0xFF1A73E8),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _useCrossNetworkMmi ? Colors.white : null),
                    onSelected: (val) => setState(() => _useCrossNetworkMmi = val),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 4. Amount Input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Amount (GHS)',
              prefixText: 'GHS ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 10),

          // Quick Amount Chips
          Wrap(
            spacing: 8,
            children: _quickAmounts.map((amt) {
              return ActionChip(
                label: Text('+${amt.toInt()}', style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _amountController.text = amt.toStringAsFixed(0);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 5. Automated Multi-Step Navigation Breakdown (Collapsible)
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF1F3F4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _isUssdStepsExpanded = !_isUssdStepsExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF1A73E8)),
                            const SizedBox(width: 6),
                            Text(
                              'Auto USSD: ${plan.rootCode} (${plan.steps.length + 1} steps)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFE8EAED)
                                    : const Color(0xFF202124),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _isUssdStepsExpanded ? 'Hide Steps' : 'Show Steps',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF1A73E8), fontWeight: FontWeight.bold),
                            ),
                            Icon(
                              _isUssdStepsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: const Color(0xFF1A73E8),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_isUssdStepsExpanded) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStepChip('1. Dial ${plan.rootCode}'),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                          ...plan.steps.asMap().entries.map((entry) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStepChip('${entry.key + 2}. Enter "${entry.value}"'),
                                if (entry.key < plan.steps.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                                  ),
                              ],
                            );
                          }),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                          _buildStepChip('🔒 Pause at PIN', isPin: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 6. Dual Action Buttons: USSD Auto-Initiate OR Direct Offline Record
          Row(
            children: [
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text(
                    'Execute USSD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    if (amount <= 0 || _phoneController.text.length < 9) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid phone number and amount')),
                      );
                      return;
                    }

                    if (!provider.isAccessibilityEnabled) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Accessibility Service Required'),
                          content: const Text(
                            'The USSD Auto-Navigation service must be enabled in Android Accessibility Settings '
                            'so MobiBoss can auto-fill menus up to the PIN prompt.\n\n'
                            'Look for "MobiBoss" in the list and enable it.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                UssdService.openAccessibilitySettings();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    // Record as pending in ledger
                    await provider.recordPendingUssdTransaction(
                      till: activeTill,
                      type: _selectedType,
                      amount: amount,
                      customerPhone: _phoneController.text.trim(),
                      ussdCode: plan.rootCode,
                    );

                    if (context.mounted) {
                      TopToast.show(
                        context,
                        title: 'USSD Session in Progress',
                        message: 'Auto-navigating ${plan.steps.length} steps on ${activeTill.network.name.toUpperCase()}... Pause at PIN.',
                        icon: Icons.bolt_rounded,
                        backgroundColor: const Color(0xFF1A73E8),
                      );
                    }

                    // Trigger automated multi-step USSD session
                    if (_useCrossNetworkMmi && isCrossNetwork) {
                      await UssdService.initiateCustomAutomatedSession(
                        rootCode: plan.rootCode,
                        steps: plan.steps,
                        fallbackShortCode: plan.displayShortCode,
                        simSlot: activeTill.simSlot.contains('2') ? 1 : 0,
                      );
                    } else {
                      await UssdService.initiateAutomatedSession(
                        till: activeTill,
                        type: _selectedType,
                        customerPhone: _phoneController.text,
                        amount: amount,
                      );
                    }

                    _amountController.clear();
                    _phoneController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF1A73E8)),
                  label: const Text(
                    'Record Only',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                  ),
                  onPressed: () {
                    if (amount <= 0 || _phoneController.text.length < 9) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid phone number and amount')),
                      );
                      return;
                    }
                    _showDirectRecordModal(context, provider, activeTill, amount, _phoneController.text.trim(), _selectedType);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick Sync SMS banner button
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF5F6368)),
              label: const Text(
                'Sync Telco Confirmation SMS',
                style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
              ),
              onPressed: () async {
                final count = await provider.syncRecentSms();
                if (context.mounted) {
                  TopToast.show(
                    context,
                    title: count > 0 ? 'SMS Sync Complete' : 'Up to Date',
                    message: count > 0 ? 'Reconciled $count incoming telecom messages.' : 'No new MoMo confirmation SMS found.',
                    icon: count > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    backgroundColor: count > 0 ? const Color(0xFF1E8E3E) : const Color(0xFF5F6368),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDirectRecordModal(
    BuildContext context,
    MoMoProvider provider,
    Till till,
    double amount,
    String phone,
    TransactionType type,
  ) {
    final refCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF1A73E8), size: 22),
            SizedBox(width: 8),
            Text('Confirm Direct Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record transaction directly into ledger without dialing USSD. '
              'Used when transacting on a secondary button phone or manual POS.',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Type:', style: TextStyle(fontSize: 12)),
                      Text(type == TransactionType.cashIn ? 'Cash In' : type == TransactionType.cashOut ? 'Cash Out' : 'Airtime', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Customer:', style: TextStyle(fontSize: 12)),
                      Text(phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(fontSize: 12)),
                      Text('GHS ${provider.formatAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A73E8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Till / SIM:', style: TextStyle(fontSize: 12)),
                      Text('${till.tillName} (${till.network.name.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'Telco Reference (Optional)',
                hintText: 'e.g. 24891823901',
                prefixIcon: Icon(Icons.tag_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final tx = await provider.recordDirectTransaction(
                till: till,
                type: type,
                amount: amount,
                customerPhone: phone,
                reference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
              );

              _amountController.clear();
              _phoneController.clear();

              if (context.mounted) {
                TopToast.show(
                  context,
                  title: 'Transaction Recorded',
                  message: '${tx.type.name.toUpperCase()} GHS ${provider.formatAmount(tx.amount)} recorded to ${till.tillName}.',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFF1E8E3E),
                );
              }
            },
            child: const Text('Save to Ledger'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, {bool isPin = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isPin
            ? (isDark ? const Color(0xFF3E2E04) : const Color(0xFFFFF4CC))
            : (isDark ? const Color(0xFF2D2F31) : Colors.white),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPin
              ? const Color(0xFFF9AB00)
              : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isPin ? FontWeight.bold : FontWeight.w500,
          color: isPin
              ? const Color(0xFFF9AB00)
              : (isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043)),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Cash In / Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            icon: Icon(Icons.payments_rounded, size: 16),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Services & Bills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            icon: Icon(Icons.grid_view_rounded, size: 16),
          ),
        ],
        selected: {_transactMode},
        onSelectionChanged: (set) => setState(() => _transactMode = set.first),
      ),
    );
  }

  void _showCustomerDirectoryModal(BuildContext context, MoMoProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: provider.customerContacts.isEmpty
                      ? const Center(
                          child: Text(
                            'No contacts saved yet.\nContacts will auto-save from confirmed transactions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5F6368)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.customerContacts.length,
                          itemBuilder: (context, index) {
                            final contact = provider.customerContacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F0FE),
                                child: Text(
                                  contact.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                                ),
                              ),
                              title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${contact.phone} • ${contact.totalTransactions} transactions', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              onTap: () {
                                setState(() {
                                  _phoneController.text = contact.phone;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
