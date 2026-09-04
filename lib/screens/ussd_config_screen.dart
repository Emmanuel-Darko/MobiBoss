import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';

class UssdConfigScreen extends StatefulWidget {
  const UssdConfigScreen({super.key});

  @override
  State<UssdConfigScreen> createState() => _UssdConfigScreenState();
}

class _UssdConfigScreenState extends State<UssdConfigScreen> {
  NetworkProvider _selectedNetwork = NetworkProvider.mtn;
  TransactionType _selectedType = TransactionType.cashIn;

  final TextEditingController _rootCodeController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRuleForSelection();
  }

  void _loadRuleForSelection() {
    final provider = context.read<MobiBossProvider>();
    final rule = provider.customUssdRules.firstWhere(
      (r) => r.network == _selectedNetwork && r.transactionType == _selectedType,
      orElse: () {
        final mockTill = provider.tills.firstWhere(
          (t) => t.network == _selectedNetwork,
          orElse: () => provider.tills.first,
        );
        final defaultPlan = UssdService.buildMultiStepPlan(
          till: mockTill,
          type: _selectedType,
          customerPhone: '{phone}',
          amount: 100,
        );
        return CustomUssdRule(
          id: '${_selectedNetwork.name}_${_selectedType.name}',
          network: _selectedNetwork,
          transactionType: _selectedType,
          customRootCode: defaultPlan.rootCode,
          customSteps: defaultPlan.steps,
          isEnabled: false,
        );
      },
    );

    _rootCodeController.text = rule.customRootCode;
    _stepsController.text = rule.customSteps.join(', ');
  }

  @override
  void dispose() {
    _rootCodeController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MobiBossProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final existingRule = provider.customUssdRules.firstWhere(
      (r) => r.network == _selectedNetwork && r.transactionType == _selectedType,
      orElse: () => CustomUssdRule(
        id: '',
        network: _selectedNetwork,
        transactionType: _selectedType,
        customRootCode: '',
        customSteps: [],
        isEnabled: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('USSD Flow Configurator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182B42) : const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1A73E8) : const Color(0xFF8AB4F8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF1A73E8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customize dialing sequences for your carrier and region. Use {phone} and {amount} placeholders.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Network Selector
          const Text('Telecom Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<NetworkProvider>(
            segments: const [
              ButtonSegment(value: NetworkProvider.mtn, label: Text('MTN')),
              ButtonSegment(value: NetworkProvider.telecel, label: Text('Telecel')),
              ButtonSegment(value: NetworkProvider.at, label: Text('AT')),
            ],
            selected: {_selectedNetwork},
            onSelectionChanged: (set) {
              setState(() {
                _selectedNetwork = set.first;
                _loadRuleForSelection();
              });
            },
          ),
          const SizedBox(height: 14),

          // Transaction Type Selector
          const Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.cashIn, label: Text('Cash In')),
              ButtonSegment(value: TransactionType.cashOut, label: Text('Cash Out')),
              ButtonSegment(value: TransactionType.airtime, label: Text('Airtime')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (set) {
              setState(() {
                _selectedType = set.first;
                _loadRuleForSelection();
              });
            },
          ),
          const SizedBox(height: 20),

          // Root Code
          TextField(
            controller: _rootCodeController,
            decoration: InputDecoration(
              labelText: 'Root USSD Code',
              hintText: '*171# or *110#',
              prefixIcon: const Icon(Icons.dialpad_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 14),

          // Steps (Comma Separated)
          TextField(
            controller: _stepsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Step Sequence (Comma-separated)',
              hintText: '1, 1, {phone}, {phone}, {amount}, POS',
              prefixIcon: const Icon(Icons.list_alt_rounded),
              helperText: 'Available placeholders: {phone}, {amount}, {ref}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 20),

          // Save / Reset Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (existingRule.id.isNotEmpty) {
                      await provider.deleteCustomUssdRule(existingRule.id);
                      if (!context.mounted) return;
                      TopToast.show(context, title: 'Reset to Default', message: 'Restored carrier standard sequence.', icon: Icons.refresh_rounded);
                    }
                    _loadRuleForSelection();
                  },
                  child: const Text('Reset Default'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Custom Rule'),
                  onPressed: () async {
                    final steps = _stepsController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();

                    final newRule = CustomUssdRule(
                      id: '${_selectedNetwork.name}_${_selectedType.name}',
                      network: _selectedNetwork,
                      transactionType: _selectedType,
                      customRootCode: _rootCodeController.text.trim(),
                      customSteps: steps,
                      isEnabled: true,
                    );

                    await provider.saveCustomUssdRule(newRule);
                    if (!context.mounted) return;
                    TopToast.show(
                      context,
                      title: 'USSD Sequence Saved',
                      message: 'Updated ${_selectedNetwork.name.toUpperCase()} ${_selectedType.name} flow (${steps.length} steps).',
                      icon: Icons.check_circle_rounded,
                      backgroundColor: const Color(0xFF1E8E3E),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
