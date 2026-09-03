import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/momo_provider.dart';
import '../models/momo_models.dart';
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
    final phone = _phoneController.text.isEmpty ? '024XXXXXXX' : _phoneController.text;

    final plan = UssdService.buildMultiStepPlan(
      till: activeTill,
      type: _selectedType,
      customerPhone: phone,
      amount: amount,
    );

    if (_transactMode == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF7E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF9AB00)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFE37400), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Auto-USSD Automation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Auto-navigates multi-step menus up to PIN entry and captures callbacks.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => UssdService.openAccessibilitySettings(),
                    child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
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
              fillColor: Colors.white,
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
              fillColor: Colors.white,
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

          // 5. Automated Multi-Step Navigation Breakdown
          Card(
            color: const Color(0xFFF1F3F4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Automated USSD Flow (Ghana Telecoms):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F6368)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          plan.rootCode,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 6. Action Button: 1-Tap Auto-Initiate & Record
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Initiate Automated USSD Session',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                      'so MoMo Boss can auto-fill menus up to the PIN prompt.\n\n'
                      'Look for "MomoBoss" in the list and enable it.',
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

              TopToast.show(
                context,
                title: 'USSD Session in Progress',
                message: 'Auto-navigating ${plan.steps.length} steps on ${activeTill.network.name.toUpperCase()}... Pause at PIN.',
                icon: Icons.bolt_rounded,
                backgroundColor: const Color(0xFF1A73E8),
              );

              // 1. Trigger automated multi-step USSD session
              await UssdService.initiateAutomatedSession(
                till: activeTill,
                type: _selectedType,
                customerPhone: _phoneController.text,
                amount: amount,
              );

              _amountController.clear();
              _phoneController.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(String label, {bool isPin = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isPin ? const Color(0xFFFFF4CC) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPin ? const Color(0xFFF9AB00) : const Color(0xFFDADCE0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isPin ? FontWeight.bold : FontWeight.w500,
          color: isPin ? const Color(0xFFB06000) : const Color(0xFF3C4043),
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
