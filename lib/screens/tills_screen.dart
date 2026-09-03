import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/momo_provider.dart';
import '../models/momo_models.dart';
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Summary Card with Add Till Action
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Working Float',
                          style: TextStyle(fontSize: 13, color: Color(0xFF5F6368), fontWeight: FontWeight.w500),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Till', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddTillModal(context, provider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.formatAmount(totalFloat),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Managed across ${tills.length} physical SIM Tills & Accounts',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF80868B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Section Header
            const Text(
              'Active SIM Tills & Wallets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF202124)),
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE8EAED),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  color: Colors.white,
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
                                color: netColor.withValues(alpha: 0.12),
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
                                            color: const Color(0xFFE8F0FE),
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
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF5F6368)),
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
                                const Text('Current Float', style: TextStyle(fontSize: 10, color: Color(0xFF5F6368))),
                                Text(
                                  provider.formatAmount(till.currentFloat),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isLowFloat ? const Color(0xFFD93025) : const Color(0xFF1E8E3E),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Alert Threshold', style: TextStyle(fontSize: 10, color: Color(0xFF5F6368))),
                                Text(
                                  '< GHS ${till.minFloatAlert.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLowFloat ? const Color(0xFFD93025) : const Color(0xFF5F6368),
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
                              color: const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD93025)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Low float alert! Rebalance ${till.network.name.toUpperCase()} reserves soon.',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFD93025), fontWeight: FontWeight.bold),
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
                                  child: const Text('Set as Active', style: TextStyle(fontSize: 11)),
                                  onPressed: () => provider.selectTill(till.id),
                                ),
                              ),
                            if (!isSelected) const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Check Balance', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  TopToast.show(
                                    context,
                                    title: 'Checking Float Balance',
                                    message: 'Dialing ${till.ussdPrefix} on ${till.simSlot}... Enter PIN to refresh float.',
                                    icon: Icons.bolt_rounded,
                                  );
                                  UssdService.dialUssd(till.ussdPrefix, simSlot: till.simSlot.contains('2') ? 1 : 0);
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
                      onPressed: () {
                        provider.deleteTill(till.id);
                        Navigator.pop(ctx);
                      },
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
}
