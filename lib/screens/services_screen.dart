import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/momo_models.dart';
import '../providers/momo_provider.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  int _categoryIndex = 0; // 0: Airtime & Data, 1: Utilities, 2: Pay TV, 3: Bank Transfer

  // Controllers
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _extraController = TextEditingController();

  // Selected Service Options
  TransactionType _serviceType = TransactionType.airtime;
  String _selectedDataTier = '1'; // Package option code
  String _selectedPayTvProvider = 'DSTV';
  String _selectedBank = 'GCB Bank';
  bool _isUssdStepsExpanded = false;

  final List<double> _airtimeQuickAmounts = [2, 5, 10, 20, 50, 100];

  @override
  void dispose() {
    _targetController.dispose();
    _amountController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(int index) {
    setState(() {
      _categoryIndex = index;
      _targetController.clear();
      _amountController.clear();
      _extraController.clear();

      switch (index) {
        case 0:
          _serviceType = TransactionType.airtime;
          break;
        case 1:
          _serviceType = TransactionType.ecgElectricity;
          break;
        case 2:
          _serviceType = TransactionType.payTv;
          break;
        case 3:
          _serviceType = TransactionType.bankTransfer;
          break;
      }
    });
  }

  String _getCommissionLabel() {
    switch (_serviceType) {
      case TransactionType.airtime:
        return 'Agent Earns 3% Commission';
      case TransactionType.dataBundle:
        return 'Agent Earns 4% Commission';
      case TransactionType.ecgElectricity:
        return 'Agent Earns GHS 1.50 Fee';
      case TransactionType.ghanaWater:
        return 'Agent Earns GHS 1.50 Fee';
      case TransactionType.payTv:
        return 'Agent Earns GHS 2.00 Fee';
      case TransactionType.bankTransfer:
        return 'Agent Earns 0.6% Commission';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final activeTill = provider.selectedTill;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final target = _targetController.text.isEmpty ? '024XXXXXXX' : _targetController.text;

    final plan = UssdService.buildServicePlan(
      till: activeTill,
      type: _serviceType,
      targetAccountOrPhone: target,
      amount: amount,
      extraParameter: _extraController.text.isNotEmpty ? _extraController.text : _selectedDataTier,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Till Selector ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: activeTill.network == NetworkProvider.mtn
                          ? const Color(0xFFFFF4CC)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Float: GHS ${activeTill.currentFloat.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E8E3E), fontWeight: FontWeight.w600),
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
          const SizedBox(height: 12),

          // ─── Service Category Tabs ───
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill(0, 'Airtime & Data', Icons.phone_android_rounded),
                const SizedBox(width: 8),
                _buildCategoryPill(1, 'Utilities (ECG & Water)', Icons.power_rounded),
                const SizedBox(width: 8),
                _buildCategoryPill(2, 'Pay TV (DSTV/GOtv)', Icons.tv_rounded),
                const SizedBox(width: 8),
                _buildCategoryPill(3, 'Bank & GhIPSS', Icons.account_balance_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Service Form Based on Category ───
          if (_categoryIndex == 0) ...[
            _buildAirtimeAndDataForm(),
          ] else if (_categoryIndex == 1) ...[
            _buildUtilitiesForm(),
          ] else if (_categoryIndex == 2) ...[
            _buildPayTvForm(),
          ] else ...[
            _buildBankTransferForm(),
          ],
          const SizedBox(height: 14),

          // ─── Commission Badge ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0F3818)
                  : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF81C995)
                        : const Color(0xFF1E8E3E))
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF81C995)
                      : const Color(0xFF1E8E3E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _getCommissionLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF81C995)
                        : const Color(0xFF1E8E3E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── USSD Automation Breakdown Card (Collapsible) ───
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF1F3F4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _isUssdStepsExpanded = !_isUssdStepsExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          _buildChip('1. Dial ${plan.rootCode}'),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                          ...plan.steps.asMap().entries.map((entry) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildChip('${entry.key + 2}. Enter "${entry.value}"'),
                                if (entry.key < plan.steps.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                                  ),
                              ],
                            );
                          }),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                          _buildChip('🔒 Pause at PIN', isPin: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Action Button ───
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'Initiate ${_getServiceActionTitle()}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              if (amount <= 0 || _targetController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid target account/phone and amount')),
                );
                return;
              }

              if (!provider.isAccessibilityEnabled) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Accessibility Service Required'),
                    content: const Text(
                      'The USSD Auto-Navigation service must be enabled in your Android Accessibility Settings to auto-fill menu steps.\n\n'
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

              TopToast.show(
                context,
                title: 'USSD Automation Started',
                message: 'Auto-navigating ${plan.steps.length} steps on ${activeTill.network.name.toUpperCase()}... Pause at PIN.',
                icon: Icons.bolt_rounded,
                backgroundColor: const Color(0xFF1A73E8),
              );

              await UssdService.initiateCustomAutomatedSession(
                rootCode: plan.rootCode,
                steps: plan.steps,
                fallbackShortCode: plan.displayShortCode,
              );

              _amountController.clear();
              _targetController.clear();
              _extraController.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(int index, String title, IconData icon) {
    final isSelected = _categoryIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
      label: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1A73E8),
      onSelected: (_) => _onCategoryChanged(index),
    );
  }

  Widget _buildAirtimeAndDataForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TransactionType>(
          segments: const [
            ButtonSegment(
              value: TransactionType.airtime,
              label: Text('Airtime Top-Up (3%)'),
              icon: Icon(Icons.phone_forwarded_rounded, size: 16),
            ),
            ButtonSegment(
              value: TransactionType.dataBundle,
              label: Text('Data Bundles (4%)'),
              icon: Icon(Icons.wifi_rounded, size: 16),
            ),
          ],
          selected: {_serviceType},
          onSelectionChanged: (set) => setState(() => _serviceType = set.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Customer Phone Number',
            hintText: '0244123456',
            prefixIcon: const Icon(Icons.phone_android_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_serviceType == TransactionType.dataBundle) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedDataTier,
            decoration: InputDecoration(
              labelText: 'Data Package Tier',
              prefixIcon: const Icon(Icons.storage_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            items: const [
              DropdownMenuItem(value: '1', child: Text('Daily: 350MB • GHS 3.00')),
              DropdownMenuItem(value: '2', child: Text('Weekly: 1.5GB • GHS 12.00')),
              DropdownMenuItem(value: '3', child: Text('Weekly: 3.5GB • GHS 25.00')),
              DropdownMenuItem(value: '4', child: Text('Monthly: 10GB • GHS 60.00')),
              DropdownMenuItem(value: '5', child: Text('Monthly: 25GB • GHS 120.00')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedDataTier = val;
                  final amounts = {'1': '3', '2': '12', '3': '25', '4': '60', '5': '120'};
                  _amountController.text = amounts[val] ?? '';
                });
              }
            },
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Recharge Amount (GHS)',
            prefixText: 'GHS ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: _airtimeQuickAmounts.map((amt) {
            return ActionChip(
              label: Text('+${amt.toInt()}'),
              onPressed: () => setState(() => _amountController.text = amt.toStringAsFixed(0)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUtilitiesForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TransactionType>(
          segments: const [
            ButtonSegment(
              value: TransactionType.ecgElectricity,
              label: Text('ECG Electricity'),
              icon: Icon(Icons.flash_on_rounded, size: 16),
            ),
            ButtonSegment(
              value: TransactionType.ghanaWater,
              label: Text('Ghana Water (GWCL)'),
              icon: Icon(Icons.water_drop_rounded, size: 16),
            ),
          ],
          selected: {_serviceType},
          onSelectionChanged: (set) => setState(() => _serviceType = set.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _targetController,
          decoration: InputDecoration(
            labelText: _serviceType == TransactionType.ecgElectricity ? 'ECG Meter Number' : 'GWCL Customer Account No.',
            hintText: _serviceType == TransactionType.ecgElectricity ? 'P1002345678' : 'GW-994821',
            prefixIcon: const Icon(Icons.tag_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Bill Amount (GHS)',
            prefixText: 'GHS ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildPayTvForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedPayTvProvider,
          decoration: InputDecoration(
            labelText: 'TV Provider',
            prefixIcon: const Icon(Icons.tv_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          items: const [
            DropdownMenuItem(value: 'DSTV', child: Text('DSTV Ghana')),
            DropdownMenuItem(value: 'GOTV', child: Text('GOtv Ghana')),
            DropdownMenuItem(value: 'STARTIMES', child: Text('StarTimes Ghana')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedPayTvProvider = val);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Smartcard / IUC / Account Number',
            hintText: '1029384756',
            prefixIcon: const Icon(Icons.credit_card_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Bouquet / Subscription Amount (GHS)',
            prefixText: 'GHS ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildBankTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedBank,
          decoration: InputDecoration(
            labelText: 'Commercial Bank',
            prefixIcon: const Icon(Icons.account_balance_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          items: const [
            DropdownMenuItem(value: 'GCB Bank', child: Text('GCB Bank Ltd')),
            DropdownMenuItem(value: 'Ecobank', child: Text('Ecobank Ghana')),
            DropdownMenuItem(value: 'Fidelity Bank', child: Text('Fidelity Bank')),
            DropdownMenuItem(value: 'Stanbic Bank', child: Text('Stanbic Bank')),
            DropdownMenuItem(value: 'Absa Bank', child: Text('Absa Bank Ghana')),
            DropdownMenuItem(value: 'Zenith Bank', child: Text('Zenith Bank')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedBank = val);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Beneficiary Account Number',
            hintText: '1021009876543',
            prefixIcon: const Icon(Icons.tag_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Deposit / Transfer Amount (GHS)',
            prefixText: 'GHS ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  String _getServiceActionTitle() {
    switch (_serviceType) {
      case TransactionType.airtime:
        return 'Airtime Top-Up';
      case TransactionType.dataBundle:
        return 'Data Bundle Purchase';
      case TransactionType.ecgElectricity:
        return 'ECG Electricity Payment';
      case TransactionType.ghanaWater:
        return 'Water Bill Payment';
      case TransactionType.payTv:
        return 'Pay TV Subscription';
      case TransactionType.bankTransfer:
        return 'Bank Deposit';
      default:
        return 'Session';
    }
  }

  Widget _buildChip(String label, {bool isPin = false}) {
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
}
