import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../services/receipt_service.dart';
import '../widgets/top_toast.dart';
import 'shift_history_screen.dart';

class ShiftHandoverScreen extends StatefulWidget {
  const ShiftHandoverScreen({super.key});

  @override
  State<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends State<ShiftHandoverScreen> {
  final TextEditingController _countedCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String? _selectedIncomingTellerId;

  @override
  void dispose() {
    _countedCashController.dispose();
    _notesController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MobiBossProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final countedCash = double.tryParse(_countedCashController.text) ?? 0.0;
    final expectedCash = provider.expectedDrawerCash;
    final variance = countedCash - expectedCash;

    final otherTellers = provider.tellers.where((t) => t.id != provider.activeTeller?.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Handover & Attendant Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active Attendant Hero (Overflow-Protected)
          Card(
            color: isDark ? const Color(0xFF1E2433) : const Color(0xFF161B26),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF1A73E8),
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outgoing: ${provider.activeTeller?.name ?? "Primary Attendant"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Role: ${provider.activeTeller?.role.name.toUpperCase() ?? "ATTENDANT"}',
                              style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132B1B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1E8E3E)),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF81C995), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF3C4043), height: 20),
                  Row(
                    children: [
                      Expanded(child: _metricCol('Shift Volume', 'GHS ${MobiBossProvider.formatNumber(provider.todayVolume)}')),
                      const SizedBox(width: 6),
                      Expanded(child: _metricCol('Commissions', 'GHS ${MobiBossProvider.formatNumber(provider.todayCommission)}')),
                      const SizedBox(width: 6),
                      Expanded(child: _metricCol('Petty Cash', 'GHS ${MobiBossProvider.formatNumber(provider.todayPettyCashTotal)}')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Drawer Count & Variance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Physical Drawer Cash Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(
                    'Expected Cash in Drawer: GHS ${MobiBossProvider.formatNumber(expectedCash)}',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countedCashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Counted Physical Cash (GHS)',
                      prefixText: 'GHS ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  if (_countedCashController.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: variance.abs() < 0.01
                            ? (isDark ? const Color(0xFF132B1B) : const Color(0xFFE6F4EA))
                            : (isDark ? const Color(0xFF331716) : const Color(0xFFFCE8E6)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              variance.abs() < 0.01
                                  ? 'PERFECTLY BALANCED'
                                  : (variance > 0 ? 'OVERAGE DETECTED' : 'SHORTAGE DETECTED'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: variance.abs() < 0.01
                                    ? (isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E))
                                    : (isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025)),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${variance >= 0 ? "+" : ""}GHS ${MobiBossProvider.formatNumber(variance)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: variance.abs() < 0.01
                                    ? (isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E))
                                    : (isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025)),
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
          ),
          const SizedBox(height: 14),

          // Incoming Teller Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Incoming Attendant / Next Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedIncomingTellerId,
                    decoration: InputDecoration(
                      labelText: 'Select Incoming Teller',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: otherTellers.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.name} (${t.role.name})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedIncomingTellerId = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Handover Notes / Shop Comments',
                      hintText: 'e.g. Paid GHS 30 for electricity token at 2pm',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Complete Handover Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Complete Handover & Print Slip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_countedCashController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter physical drawer cash count')),
                );
                return;
              }

              final incomingTeller = provider.tellers.firstWhere(
                (t) => t.id == _selectedIncomingTellerId,
                orElse: () => Teller(
                  id: 'incoming',
                  name: 'Evening Attendant',
                  phone: '',
                  pinHash: '',
                  createdAt: DateTime.now(),
                ),
              );

              final handover = ShiftHandover(
                id: 'ho_${DateTime.now().millisecondsSinceEpoch}',
                outgoingTellerName: provider.activeTeller?.name ?? 'Primary Attendant',
                incomingTellerName: incomingTeller.name,
                handoverTime: DateTime.now(),
                countedDrawerCash: countedCash,
                expectedDrawerCash: expectedCash,
                cashVariance: variance,
                shiftTransactionCount: provider.currentShiftTransactions.length,
                shiftVolume: provider.currentShiftVolume,
                shiftCommissions: provider.currentShiftCommission,
                shiftPettyCashSpent: provider.currentShiftPettyCashTotal,
                notes: _notesController.text.trim(),
              );

              await provider.recordShiftHandover(handover, nextTeller: incomingTeller);

              // Auto-print if Bluetooth printer connected
              if (provider.selectedPrinter != null) {
                final escBytes = ReceiptService.buildEscPosHandoverReport(handover: handover);
                await ReceiptService.printRawBytes(
                  printerAddress: provider.selectedPrinter!.address,
                  bytes: escBytes,
                );
              }

              if (!context.mounted) return;
              TopToast.show(
                context,
                title: 'Shift Handover Completed',
                message: 'Switched to ${incomingTeller.name}. Handover slip recorded.',
                icon: Icons.check_circle_rounded,
                backgroundColor: const Color(0xFF1E8E3E),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShiftHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('View All Past Shift Settlements & Audits'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
