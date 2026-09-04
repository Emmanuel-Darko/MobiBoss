import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/momo_models.dart';
import '../providers/momo_provider.dart';
import '../services/receipt_service.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  final TextEditingController _cashController = TextEditingController();
  bool _isProvidersCollapsed = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<MoMoProvider>();
    _cashController.text = provider.currentCashInDrawer.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.cashIn:
        return const Color(0xFF1E8E3E);
      case TransactionType.cashOut:
        return const Color(0xFFD93025);
      case TransactionType.airtime:
        return const Color(0xFFE37400);
      case TransactionType.dataBundle:
        return const Color(0xFF1A73E8);
      case TransactionType.floatTransfer:
        return const Color(0xFF9334E6);
      case TransactionType.ecgElectricity:
        return const Color(0xFFF9AB00);
      case TransactionType.ghanaWater:
        return const Color(0xFF005696);
      case TransactionType.payTv:
        return const Color(0xFF8E24AA);
      case TransactionType.bankTransfer:
        return const Color(0xFF2E7D32);
    }
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.cashIn:
        return 'CASH IN';
      case TransactionType.cashOut:
        return 'CASH OUT';
      case TransactionType.airtime:
        return 'AIRTIME';
      case TransactionType.dataBundle:
        return 'DATA';
      case TransactionType.floatTransfer:
        return 'FLOAT';
      case TransactionType.ecgElectricity:
        return 'ECG POWER';
      case TransactionType.ghanaWater:
        return 'WATER';
      case TransactionType.payTv:
        return 'PAY TV';
      case TransactionType.bankTransfer:
        return 'BANK';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'MoMo':
        return Icons.phone_android_rounded;
      case 'Bank':
        return Icons.account_balance_rounded;
      case 'FinTech':
        return Icons.credit_card_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'MoMo':
        return const Color(0xFF1E8E3E);
      case 'Bank':
        return const Color(0xFF1A73E8);
      case 'FinTech':
        return const Color(0xFFE37400);
      default:
        return const Color(0xFF5F6368);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final result = provider.lastReconciliation;
    final discoveredSenders = provider.discoveredSenders;
    final selectedSenders = provider.selectedSenders;
    final isScanning = provider.isScanningInbox;
    final period = provider.reconciliationPeriod;
    final filteredRecords = provider.filteredSmsRecords;
    final dateFormat = DateFormat('hh:mm a • d MMM');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Shift Header & History Action ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shift #${provider.currentShiftNumber} Audit',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF202124)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: Text('Shift History (${provider.shiftHistory.length})', style: const TextStyle(fontSize: 11)),
                onPressed: () => _showShiftHistoryModal(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ─── 1. Scan SMS Inbox Button ───
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 20),
            label: Text(
              isScanning
                  ? 'Scanning Inbox...'
                  : discoveredSenders.isEmpty
                      ? 'Scan SMS Inbox for Payment Providers'
                      : 'Rescan Device Inbox (${discoveredSenders.length} Providers Found)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: isScanning
                ? null
                : () => provider.scanDeviceInboxAndDiscoverSenders(context),
          ),
          const SizedBox(height: 14),

          // ─── 2. Payment Provider Selection (Collapsible Card) ───
          if (discoveredSenders.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isProvidersCollapsed = !_isProvidersCollapsed),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_tree_rounded, size: 18, color: Color(0xFF1A73E8)),
                                const SizedBox(width: 8),
                                Text(
                                  _isProvidersCollapsed
                                      ? 'Reconciling: ${selectedSenders.length} of ${discoveredSenders.length} Providers'
                                      : 'Payment Providers (${discoveredSenders.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  _isProvidersCollapsed ? 'Expand ▾' : 'Collapse ▴',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF1A73E8), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isProvidersCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                  size: 18,
                                  color: const Color(0xFF1A73E8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isProvidersCollapsed) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select which telecom & fintech SMS to reconcile:',
                            style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                          ),
                          Row(
                            children: [
                              _buildMiniAction(label: 'All', onTap: () => provider.selectAllSenders()),
                              const SizedBox(width: 6),
                              _buildMiniAction(label: 'None', onTap: () => provider.clearSenderSelection()),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: discoveredSenders.values.map((info) {
                          final isSelected = selectedSenders.contains(info.address);
                          final catColor = _getCategoryColor(info.category);
                          return FilterChip(
                            avatar: Icon(
                              _getCategoryIcon(info.category),
                              size: 14,
                              color: isSelected ? Colors.white : catColor,
                            ),
                            label: Text(
                              '${info.address} (${info.parsedTransactions})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF3C4043),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF1A73E8),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => provider.toggleSenderSelection(info.address),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── 3. Reconciliation Period Selector (Horizontally Scrollable to Prevent Overflow) ───
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Shift Period:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5F6368)),
                ),
                const SizedBox(width: 8),
                _buildPeriodChip('Today', 'today', period, provider),
                const SizedBox(width: 6),
                _buildPeriodChip('Current Shift (8h)', 'shift', period, provider),
                const SizedBox(width: 6),
                _buildPeriodChip('Last 24h', '24h', period, provider),
                const SizedBox(width: 6),
                _buildPeriodChip('All Time', 'all', period, provider),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── 4. Physical Cash Count Input ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Counted Cash in Physical Drawer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Icon(Icons.point_of_sale_rounded, color: Color(0xFF1A73E8), size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Count all physical bank notes and coins in your cash drawer:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Counted Physical Cash (GHS)',
                      prefixText: 'GHS ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed >= 0) {
                        provider.reconcileShift(physicalCash: parsed);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ─── 5. Live Reconciliation Variance & EOD Settlement Card ───
          if (result != null) ...[
            _buildResultCard(result, provider),
            const SizedBox(height: 16),
          ],

          // ─── 6. Active Reconciled SMS Records Feed ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active SMS Records (${filteredRecords.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF202124)),
              ),
              if (period != 'all')
                Text(
                  'Filtered by $period',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (filteredRecords.isEmpty)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFFBDC1C6)),
                      const SizedBox(height: 8),
                      Text(
                        discoveredSenders.isEmpty
                            ? 'No scanned messages yet. Tap "Scan SMS Inbox" above.'
                            : 'No messages match the active provider filters or time period.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                final isCashIn = record.type == TransactionType.cashIn ||
                    record.type == TransactionType.airtime ||
                    record.type == TransactionType.dataBundle ||
                    record.type == TransactionType.ecgElectricity ||
                    record.type == TransactionType.ghanaWater ||
                    record.type == TransactionType.payTv;

                final color = _getTypeColor(record.type);
                final label = _getTypeLabel(record.type);

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                            isCashIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F3F4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      record.sender,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF5F6368)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${record.customerPhone.isNotEmpty ? "${record.customerPhone} • " : ""}${record.reference}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF5F6368)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dateFormat.format(record.timestamp),
                                style: const TextStyle(fontSize: 9, color: Color(0xFF80868B)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isCashIn ? '+' : '-'} GHS ${record.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCashIn ? const Color(0xFF1E8E3E) : const Color(0xFFD93025),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMiniAction({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDADCE0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value, String currentPeriod, MoMoProvider provider) {
    final isSelected = currentPeriod == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF5F6368),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1A73E8),
      onSelected: (_) => provider.setReconciliationPeriod(value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildResultCard(ReconciliationResult result, MoMoProvider provider) {
    final isBalanced = result.status == 'BALANCED';
    final bgColor = isBalanced ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6);
    final fgColor = isBalanced ? const Color(0xFF1E8E3E) : const Color(0xFFD93025);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: fgColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'BALANCED — Drawer matches transactions'
                        : '${result.status}: GHS ${result.cashVariance.abs().toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: fgColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            _buildResultRow('Expected Cash in Drawer', 'GHS ${result.expectedPhysicalCash.toStringAsFixed(2)}'),
            _buildResultRow('Counted Physical Cash', 'GHS ${result.physicalCashCount.toStringAsFixed(2)}'),
            _buildResultRow(
              'Total Deposits / Inflows (+)',
              'GHS ${result.totalCashIn.toStringAsFixed(2)}',
              color: const Color(0xFF1E8E3E),
            ),
            _buildResultRow(
              'Total Withdrawals / Outflows (-)',
              'GHS ${result.totalCashOut.toStringAsFixed(2)}',
              color: const Color(0xFFD93025),
            ),
            _buildResultRow(
              'Total Commissions Earned',
              'GHS ${result.totalCommissions.toStringAsFixed(2)}',
              color: const Color(0xFF1A73E8),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.aiDiagnosis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF3C4043)),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Close Shift & Print Settlement Action ───
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF202124),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: Text(
                  'Close Shift #${provider.currentShiftNumber} & Print Settlement Slip',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _showShiftCloseDialog(context, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftCloseDialog(BuildContext context, MoMoProvider provider) {
    final counted = double.tryParse(_cashController.text) ?? provider.currentCashInDrawer;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close Shift #${provider.currentShiftNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Closing the shift locks current transactions, computes the final audit variance, and generates the settlement report.',
            ),
            const SizedBox(height: 12),
            Text('Final Counted Cash: GHS ${counted.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Close & Share'),
            onPressed: () async {
              Navigator.pop(ctx);
              final shift = provider.closeCurrentShift(countedCash: counted, context: context);
              await ReceiptService.shareShiftSettlementPdf(shift: shift);
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E8E3E)),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Close & Print'),
            onPressed: () async {
              Navigator.pop(ctx);
              final shift = provider.closeCurrentShift(countedCash: counted, context: context);
              await ReceiptService.printShiftSettlementReport(context: context, shift: shift);
            },
          ),
        ],
      ),
    );
  }

  void _showShiftHistoryModal(BuildContext context, MoMoProvider provider) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Archived Shift Settlements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: provider.shiftHistory.isEmpty
                      ? const Center(child: Text('No closed shifts archived yet.'))
                      : ListView.builder(
                          itemCount: provider.shiftHistory.length,
                          itemBuilder: (context, index) {
                            final shift = provider.shiftHistory[index];
                            final isBalanced = shift.status == 'BALANCED';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Shift #${shift.shiftNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isBalanced ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            shift.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isBalanced ? const Color(0xFF1E8E3E) : const Color(0xFFD93025),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${dateFormat.format(shift.startTime)} → ${dateFormat.format(shift.endTime)}', style: const TextStyle(fontSize: 10, color: Color(0xFF5F6368))),
                                    const Divider(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('In: GHS ${shift.totalCashIn.toStringAsFixed(2)} • Out: GHS ${shift.totalCashOut.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                                        Text('Comm: GHS ${shift.totalCommissions.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.share_rounded, size: 14),
                                          label: const Text('Share PDF', style: TextStyle(fontSize: 11)),
                                          onPressed: () => ReceiptService.shareShiftSettlementPdf(shift: shift),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A73E8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.print_rounded, size: 14),
                                          label: const Text('Print Slip', style: TextStyle(fontSize: 11)),
                                          onPressed: () => ReceiptService.printShiftSettlementReport(context: context, shift: shift),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF3C4043))),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF202124)),
          ),
        ],
      ),
    );
  }
}
