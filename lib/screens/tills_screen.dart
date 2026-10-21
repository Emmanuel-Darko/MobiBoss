import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mobiboss_provider.dart';
import '../models/mobiboss_models.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';

class TillsScreen extends StatelessWidget {
  const TillsScreen({super.key});

  Color _getNetworkColor(NetworkProvider net) {
    switch (net) {
      case NetworkProvider.mtn:
        return const Color(0xFFF9AB00);
      case NetworkProvider.telecel:
        return const Color(0xFFD93025);
      case NetworkProvider.at:
        return const Color(0xFF1A73E8);
      case NetworkProvider.gmoney:
        return const Color(0xFF1E8E3E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final tills = provider.tills;

    double totalFloat = 0;
    for (var t in tills) {
      totalFloat += t.currentFloat;
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Summary Hero Card with Add Till Action
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF161B26), Color(0xFF1E2433)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D3748)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'TOTAL WORKING FLOAT',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8AB4F8),
                              side: const BorderSide(color: Color(0xFF3C4043)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                            label: const Text('Rebalance', style: TextStyle(fontSize: 11)),
                            onPressed: () => _showTopUpTillModal(context, provider, provider.selectedTill),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Till', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showAddTillModal(context, provider),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.formatAmount(totalFloat),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF8FAFC),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Managed across ${tills.length} physical SIM Tills & Accounts',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section Header
            const Text(
              'Active SIM Tills & Wallets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // List of Tills
            if (tills.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No SIM tills configured. Tap "+ Add Till" above to get started.'),
                  ),
                ),
              )
            else
              ...tills.map((till) {
                final isSelected = till.id == provider.selectedTill.id;
                final netColor = _getNetworkColor(till.network);
                final isLowFloat = till.currentFloat <= till.minFloatAlert;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF1A73E8) : (isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: netColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.sim_card_rounded, color: netColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          till.tillName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF182B42) : const Color(0xFFE8F0FE),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('ACTIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${till.network.name.toUpperCase()} • ${till.tillNumber} • ${till.simSlot}',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.tune_rounded, size: 20, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
                              tooltip: 'Edit Till & Alert Threshold',
                              onPressed: () => _showEditTillModal(context, provider, till),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Current Float', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                                Text(
                                  provider.formatAmount(till.currentFloat),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isLowFloat
                                        ? (isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025))
                                        : (isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E)),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Alert Threshold', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                                Text(
                                  '< GHS ${MoMoProvider.formatNumber(till.minFloatAlert)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLowFloat
                                        ? (isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025))
                                        : (isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isLowFloat) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF331716) : const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Low float alert! Rebalance ${till.network.name.toUpperCase()} reserves soon.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (!isSelected)
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                  child: const Text('Set Active', style: TextStyle(fontSize: 11)),
                                  onPressed: () => provider.selectTill(till.id),
                                ),
                              ),
                            if (!isSelected) const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                                label: const Text('Top-Up', style: TextStyle(fontSize: 11)),
                                onPressed: () => _showTopUpTillModal(context, provider, till),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Balance', style: TextStyle(fontSize: 11)),
                                onPressed: () async {
                                  final plan = UssdService.buildCheckBalancePlan(till);
                                  TopToast.show(
                                    context,
                                    title: 'Checking Float Balance',
                                    message: 'Auto-navigating ${plan.rootCode} on ${till.simSlot}... Enter PIN to refresh float.',
                                    icon: Icons.bolt_rounded,
                                    backgroundColor: const Color(0xFF1A73E8),
                                  );
                                  await UssdService.initiateCustomAutomatedSession(
                                    rootCode: plan.rootCode,
                                    steps: plan.steps,
                                    fallbackShortCode: plan.displayShortCode,
                                    simSlot: till.simSlot.contains('2') ? 1 : 0,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddTillModal(BuildContext context, MoMoProvider provider) {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final floatCtrl = TextEditingController(text: '5000');
    final alertCtrl = TextEditingController(text: '1000');
    final codeCtrl = TextEditingController(text: 'AGT-001');
    NetworkProvider network = NetworkProvider.mtn;
    String simSlot = 'SIM 1';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add New SIM Till', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Till Name', hintText: 'MTN Agent Till 2')),
                const SizedBox(height: 8),
                DropdownButtonFormField<NetworkProvider>(
                  initialValue: network,
                  decoration: const InputDecoration(labelText: 'Telecom Network'),
                  items: NetworkProvider.values.map((n) => DropdownMenuItem(value: n, child: Text(n.name.toUpperCase()))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => network = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: numberCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Till Phone Number', hintText: '0244123456')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: simSlot,
                  decoration: const InputDecoration(labelText: 'Physical SIM Slot'),
                  items: const [
                    DropdownMenuItem(value: 'SIM 1', child: Text('SIM Slot 1')),
                    DropdownMenuItem(value: 'SIM 2', child: Text('SIM Slot 2')),
                    DropdownMenuItem(value: 'eSIM', child: Text('eSIM')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => simSlot = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: floatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Float (GHS)', prefixText: 'GHS ')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(controller: alertCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low Float Alert (GHS)', prefixText: 'GHS ')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Agent Code')),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (nameCtrl.text.isEmpty || numberCtrl.text.isEmpty) return;
                    final till = Till(
                      id: 'till-${DateTime.now().millisecondsSinceEpoch}',
                      network: network,
                      tillName: nameCtrl.text,
                      tillNumber: numberCtrl.text,
                      simSlot: simSlot,
                      currentFloat: double.tryParse(floatCtrl.text) ?? 5000.0,
                      minFloatAlert: double.tryParse(alertCtrl.text) ?? 1000.0,
                      ussdPrefix: network == NetworkProvider.mtn ? '*171#' : '*110#',
                      agentCode: codeCtrl.text,
                    );
                    provider.addCustomTill(till);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add SIM Till', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTillModal(BuildContext context, MoMoProvider provider, Till till) {
    final nameCtrl = TextEditingController(text: till.tillName);
    final numberCtrl = TextEditingController(text: till.tillNumber);
    final alertCtrl = TextEditingController(text: till.minFloatAlert.toStringAsFixed(0));
    final floatCtrl = TextEditingController(text: till.currentFloat.toStringAsFixed(2));
    final codeCtrl = TextEditingController(text: till.agentCode);
    String simSlot = till.simSlot;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit ${till.tillName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Till Name')),
                const SizedBox(height: 8),
                TextField(controller: numberCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Till Phone Number')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: ['SIM 1', 'SIM 2', 'eSIM'].contains(simSlot) ? simSlot : 'SIM 1',
                  decoration: const InputDecoration(labelText: 'Physical SIM Slot'),
                  items: const [
                    DropdownMenuItem(value: 'SIM 1', child: Text('SIM Slot 1')),
                    DropdownMenuItem(value: 'SIM 2', child: Text('SIM Slot 2')),
                    DropdownMenuItem(value: 'eSIM', child: Text('eSIM')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => simSlot = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: floatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Float Balance (GHS)', prefixText: 'GHS ')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(controller: alertCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Float Alert (GHS)', prefixText: 'GHS ')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Agent Code')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD93025)),
                      tooltip: 'Delete Till',
                      onPressed: () => _confirmDeleteTill(context, provider, till),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final updated = till.copyWith(
                            tillName: nameCtrl.text,
                            tillNumber: numberCtrl.text,
                            simSlot: simSlot,
                            currentFloat: double.tryParse(floatCtrl.text) ?? till.currentFloat,
                            minFloatAlert: double.tryParse(alertCtrl.text) ?? till.minFloatAlert,
                            agentCode: codeCtrl.text,
                          );
                          provider.updateTill(updated);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTill(BuildContext context, MoMoProvider provider, Till till) {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD93025), size: 22),
            SizedBox(width: 8),
            Text('Delete SIM Till', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${till.tillName}"? '
              'Any remaining float of GHS ${provider.formatAmount(till.currentFloat)} will be removed.',
              style: const TextStyle(fontSize: 12),
            ),
            if (provider.tellers.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter Attendant / Owner PIN',
                  hintText: '4-digit PIN',
                  prefixIcon: Icon(Icons.lock_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD93025)),
            onPressed: () async {
              if (provider.tellers.isNotEmpty && !provider.verifyTellerPin(pinCtrl.text.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN. Action denied.')),
                );
                return;
              }
              await provider.deleteTill(till.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
                TopToast.show(
                  context,
                  title: 'Till Deleted',
                  message: '${till.tillName} was removed.',
                  icon: Icons.delete_outline_rounded,
                  backgroundColor: const Color(0xFF5F6368),
                );
              }
            },
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  void _showTopUpTillModal(BuildContext context, MoMoProvider provider, Till targetTill) {
    final amountCtrl = TextEditingController();
    int mode = 0; // 0: From Drawer Cash, 1: From Bank/Super-Agent, 2: Transfer from other SIM
    String? sourceTillId = provider.tills.where((t) => t.id != targetTill.id).isNotEmpty
        ? provider.tills.firstWhere((t) => t.id != targetTill.id).id
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top-Up ${targetTill.tillName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Source of Float', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.point_of_sale_rounded, size: 16),
                    label: const Text('Cash Drawer'),
                    selected: mode == 0,
                    onSelected: (sel) {
                      if (sel) setModalState(() => mode = 0);
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.account_balance_rounded, size: 16),
                    label: const Text('Bank / Super-Agent'),
                    selected: mode == 1,
                    onSelected: (sel) {
                      if (sel) setModalState(() => mode = 1);
                    },
                  ),
                  if (provider.tills.length > 1)
                    ChoiceChip(
                      avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Transfer SIM'),
                      selected: mode == 2,
                      onSelected: (sel) {
                        if (sel) setModalState(() => mode = 2);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                mode == 0
                    ? 'Deducts physical cash from drawer (Available: GHS ${provider.formatAmount(provider.currentCashInDrawer)})'
                    : mode == 1
                        ? 'Direct float deposit without touching physical cash drawer.'
                        : 'Transfers float from another active till into ${targetTill.tillName}.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
              ),
              if (mode == 2 && provider.tills.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: sourceTillId,
                  decoration: const InputDecoration(labelText: 'Source SIM Till'),
                  items: provider.tills.where((t) => t.id != targetTill.id).map((t) {
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.tillName} (GHS ${provider.formatAmount(t.currentFloat)})'),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => sourceTillId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Float Amount to Add (GHS)',
                  prefixText: 'GHS ',
                  prefixIcon: Icon(Icons.add_card_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  if (amount <= 0) return;

                  await provider.topUpTillFloat(
                    tillId: targetTill.id,
                    amount: amount,
                    paidFromDrawer: mode == 0,
                    sourceTillId: mode == 2 ? sourceTillId : null,
                  );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    TopToast.show(
                      context,
                      title: 'Float Added',
                      message: 'GHS ${provider.formatAmount(amount)} added to ${targetTill.tillName}.',
                      icon: Icons.check_circle_rounded,
                      backgroundColor: const Color(0xFF1E8E3E),
                    );
                  }
                },
                child: const Text('Confirm & Update Float', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
