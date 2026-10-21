import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final List<Map<String, dynamic>> _quickPills = const [
    {'label': '{phone}', 'desc': 'Customer Phone', 'color': Color(0xFF1A73E8), 'isPrimary': true},
    {'label': '{amount}', 'desc': 'Amount', 'color': Color(0xFF1E8E3E), 'isPrimary': true},
    {'label': '{ref}', 'desc': 'POS Reference', 'color': Color(0xFFE37400), 'isPrimary': true},
    {'label': '1', 'desc': 'Menu 1', 'color': Color(0xFF5F6368), 'isPrimary': false},
    {'label': '2', 'desc': 'Menu 2', 'color': Color(0xFF5F6368), 'isPrimary': false},
    {'label': '3', 'desc': 'Menu 3', 'color': Color(0xFF5F6368), 'isPrimary': false},
    {'label': '4', 'desc': 'Menu 4', 'color': Color(0xFF5F6368), 'isPrimary': false},
    {'label': '5', 'desc': 'Menu 5', 'color': Color(0xFF5F6368), 'isPrimary': false},
    {'label': 'POS', 'desc': 'Reference tag', 'color': Color(0xFF8E24AA), 'isPrimary': false},
    {'label': '0', 'desc': 'Back / More', 'color': Color(0xFF5F6368), 'isPrimary': false},
  ];

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

  void _insertPlaceholder(String token) {
    final text = _stepsController.text;
    final selection = _stepsController.selection;
    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      final before = text.substring(0, selection.start);
      final after = text.substring(selection.end);
      final separatorBefore = (before.trim().isNotEmpty && !before.trim().endsWith(',')) ? ', ' : '';
      final separatorAfter = (after.trim().isNotEmpty && !after.trim().startsWith(',')) ? ', ' : '';
      final newText = '$before$separatorBefore$token$separatorAfter$after';
      _stepsController.text = newText;
      final newCursorPos = (before + separatorBefore + token).length;
      _stepsController.selection = TextSelection.collapsed(offset: newCursorPos);
    } else {
      final trimmed = text.trim();
      final newText = trimmed.isEmpty
          ? token
          : (trimmed.endsWith(',') ? '$trimmed $token' : '$trimmed, $token');
      _stepsController.text = newText;
      _stepsController.selection = TextSelection.collapsed(offset: newText.length);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _rootCodeController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  // ─── Smart Export Configuration ───
  void _exportConfigurations(MobiBossProvider provider) {
    final rules = provider.customUssdRules;
    final List<Map<String, dynamic>> exportData = rules.map((r) => r.toJson()).toList();

    // If empty, export current rule as a starter
    if (exportData.isEmpty) {
      exportData.add({
        'id': '${_selectedNetwork.name}_${_selectedType.name}',
        'network': _selectedNetwork.name,
        'transactionType': _selectedType.name,
        'customRootCode': _rootCodeController.text.trim(),
        'customSteps': _stepsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'isEnabled': true,
      });
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    Clipboard.setData(ClipboardData(text: jsonString));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.file_upload_rounded, color: Color(0xFF1E8E3E)),
                const SizedBox(width: 8),
                const Text('Export USSD Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your USSD sequences have been copied to the clipboard! You can share this JSON with another agent or keep it as backup.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy to Clipboard Again'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                Navigator.pop(ctx);
                TopToast.show(context, title: 'Copied!', message: 'USSD JSON copied to clipboard.', icon: Icons.check_circle_rounded);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Smart Import Configuration ───
  void _showImportModal(MobiBossProvider provider) {
    final importCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_download_rounded, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 8),
                  const Text('Import USSD Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste a valid USSD JSON array exported from another MobiBoss app or supervisor.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: importCtrl,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: InputDecoration(
                  hintText: '[\n  {\n    "network": "mtn",\n    "transactionType": "cashIn",\n    "customRootCode": "*171#",\n    "customSteps": ["3", "1", "{phone}", "{phone}", "{amount}", "POS"]\n  }\n]',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    tooltip: 'Paste from Clipboard',
                    icon: const Icon(Icons.paste_rounded, color: Color(0xFF1A73E8)),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        setModalState(() => importCtrl.text = data.text!);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Validate & Apply Configuration'),
                onPressed: () async {
                  final raw = importCtrl.text.trim();
                  if (raw.isEmpty) return;

                  try {
                    final dynamic decoded = jsonDecode(raw);
                    final List items = decoded is List ? decoded : [decoded];
                    int importedCount = 0;

                    for (final item in items) {
                      if (item is Map<String, dynamic>) {
                        final netStr = item['network'] as String?;
                        final typeStr = item['transactionType'] as String?;
                        final rootCode = item['customRootCode'] as String? ?? '*171#';
                        final steps = (item['customSteps'] as List?)?.map((e) => e.toString()).toList() ?? [];

                        if (netStr != null && typeStr != null) {
                          final net = NetworkProvider.values.byName(netStr);
                          final type = TransactionType.values.byName(typeStr);
                          final rule = CustomUssdRule(
                            id: '${net.name}_${type.name}',
                            network: net,
                            transactionType: type,
                            customRootCode: rootCode,
                            customSteps: steps,
                            isEnabled: true,
                          );
                          await provider.saveCustomUssdRule(rule);
                          importedCount++;
                        }
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    _loadRuleForSelection();
                    TopToast.show(
                      context,
                      title: 'Import Successful',
                      message: 'Applied $importedCount USSD flow configuration(s).',
                      icon: Icons.check_circle_rounded,
                      backgroundColor: const Color(0xFF1E8E3E),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid JSON format: $e'),
                        backgroundColor: const Color(0xFFD93025),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 21),
            tooltip: 'Export Configuration',
            onPressed: () => _exportConfigurations(provider),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 21),
            tooltip: 'Import Configuration',
            onPressed: () => _showImportModal(provider),
          ),
          const SizedBox(width: 4),
        ],
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
                    'Customize dialing sequences for your carrier and region. Tap placeholder pills to insert {phone} or {amount} into steps.',
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
          const SizedBox(height: 16),

          // Step Sequence Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Step Sequence (Comma-separated)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_stepsController.text.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _stepsController.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12, color: Color(0xFFD93025), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _stepsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '3, 1, {phone}, {phone}, {amount}, POS',
              prefixIcon: const Icon(Icons.list_alt_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // ─── Quick Placeholder & Menu Pills (Tap to Insert) ───
          const Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF1A73E8)),
              SizedBox(width: 4),
              Text(
                'TAP TO INSERT INTO FLOW:',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF5F6368), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPills.map((pill) {
                final label = pill['label'] as String;
                final color = pill['color'] as Color;
                final isPrimary = pill['isPrimary'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    backgroundColor: isDark
                        ? color.withValues(alpha: isPrimary ? 0.25 : 0.12)
                        : color.withValues(alpha: isPrimary ? 0.12 : 0.06),
                    side: BorderSide(
                      color: color.withValues(alpha: isPrimary ? 0.6 : 0.3),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark && !isPrimary ? Colors.white70 : color,
                      ),
                    ),
                    onPressed: () => _insertPlaceholder(label),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),

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
