import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobiboss_models.dart';
import '../services/receipt_service.dart';
import '../services/whatsapp_service.dart';
import '../services/storage_service.dart';

class ShiftHistoryCard extends StatefulWidget {
  final ShiftRecord shift;
  final bool initialExpanded;

  const ShiftHistoryCard({
    super.key,
    required this.shift,
    this.initialExpanded = false,
  });

  @override
  State<ShiftHistoryCard> createState() => _ShiftHistoryCardState();
}

class _ShiftHistoryCardState extends State<ShiftHistoryCard> {
  late bool _isExpanded;
  bool _showDenominations = false;
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  static final _dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
  static final _timeOnlyFormatter = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BALANCED':
        return const Color(0xFF1E8E3E);
      case 'SHORTAGE':
        return const Color(0xFFD93025);
      case 'OVERAGE':
      default:
        return const Color(0xFF1A73E8);
    }
  }

  Color _getStatusBg(String status, bool isDark) {
    switch (status.toUpperCase()) {
      case 'BALANCED':
        return isDark ? const Color(0xFF0F3818) : const Color(0xFFE6F4EA);
      case 'SHORTAGE':
        return isDark ? const Color(0xFF3E1210) : const Color(0xFFFCE8E6);
      case 'OVERAGE':
      default:
        return isDark ? const Color(0xFF10284A) : const Color(0xFFE8F0FE);
    }
  }

  Future<void> _shareToWhatsApp() async {
    final shopProfile = await StorageService.loadShopProfile();
    final message = WhatsAppService.formatShiftReport(
      shift: widget.shift,
      shopProfile: shopProfile,
    );

    final success = await WhatsAppService.sendWhatsAppReport(
      message: message,
      recipientPhone: shopProfile.ownerPhone,
    );

    if (!success && mounted) {
      await ReceiptService.shareShiftSettlementPdf(shift: widget.shift);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shift = widget.shift;
    final statusColor = _getStatusColor(shift.status);
    final statusBg = _getStatusBg(shift.status, isDark);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isExpanded ? statusColor.withValues(alpha: 0.45) : theme.dividerColor.withValues(alpha: 0.2),
          width: _isExpanded ? 1.5 : 1.0,
        ),
      ),
      color: theme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header: Shift # + Status Pill + Date ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      shift.status.toUpperCase() == 'BALANCED'
                          ? Icons.check_circle_rounded
                          : shift.status.toUpperCase() == 'SHORTAGE'
                              ? Icons.warning_rounded
                              : Icons.info_rounded,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Shift #${shift.shiftNumber}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                shift.status.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_dateFormatter.format(shift.startTime)} → ${_timeOnlyFormatter.format(shift.endTime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ─── Quick Summary Row ───
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      context,
                      label: 'Closing Cash',
                      value: 'GHS ${_currencyFormatter.format(shift.closingCash)}',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetric(
                      context,
                      label: 'Variance',
                      value: '${shift.cashVariance >= 0 ? "+" : ""}GHS ${_currencyFormatter.format(shift.cashVariance)}',
                      valueColor: statusColor,
                      icon: Icons.compare_arrows_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetric(
                      context,
                      label: 'Commissions',
                      value: 'GHS ${_currencyFormatter.format(shift.totalCommissions)}',
                      valueColor: const Color(0xFF1E8E3E),
                      icon: Icons.star_rounded,
                    ),
                  ),
                ],
              ),

              // ─── Expanded Details Section ───
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ─── Expected vs Actual Breakdown ───
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Opening Cash',
                        value: 'GHS ${_currencyFormatter.format(shift.openingCash)}',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Expected Cash',
                        value: 'GHS ${_currencyFormatter.format(shift.expectedCash)}',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── Flow & Activity Breakdown ───
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Total Inflows (+)',
                        value: 'GHS ${_currencyFormatter.format(shift.totalCashIn)}',
                        color: const Color(0xFF1E8E3E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Total Outflows (-)',
                        value: 'GHS ${_currencyFormatter.format(shift.totalCashOut)}',
                        color: const Color(0xFFD93025),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Transactions',
                        value: '${shift.transactionCount} records',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailTile(
                        context,
                        title: 'Total Volume',
                        value: 'GHS ${_currencyFormatter.format(shift.totalCashIn + shift.totalCashOut)}',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── AI Diagnosis Callout Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 18, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shift.aiDiagnosis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Cash Denomination Breakdown (if available) ───
                if (shift.denomination != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _showDenominations = !_showDenominations;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.point_of_sale_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Cash Denomination Count',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showDenominations ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showDenominations) ...[
                    const SizedBox(height: 8),
                    _buildDenominationGrid(context, shift.denomination!),
                  ],
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ─── Action Buttons ───
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ReceiptService.printShiftSettlementReport(
                        context: context,
                        shift: shift,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Settlement'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ReceiptService.shareShiftSettlementPdf(shift: shift),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('Share PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _shareToWhatsApp,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('WhatsApp Owner'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],

              // ─── Collapse / Expand Indicator ───
              const SizedBox(height: 6),
              Center(
                child: Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationGrid(BuildContext context, CashDenomination denom) {
    final theme = Theme.of(context);
    final notes = [200, 100, 50, 20, 10, 5, 2, 1];
    final items = <Map<String, dynamic>>[];

    for (final n in notes) {
      final count = denom.noteCounts[n] ?? 0;
      if (count > 0) {
        items.add({'label': '₵$n', 'count': count, 'val': (count * n).toDouble()});
      }
    }

    if (denom.coinTotal > 0) {
      items.add({'label': 'Coins', 'count': 1, 'val': denom.coinTotal});
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No denomination breakdown specified.',
          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: items.map((item) {
          final isCoin = item['label'] == 'Coins';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCoin ? 'Coins Total' : '${item['label']}  ×  ${item['count']}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  'GHS ${_currencyFormatter.format(item['val'])}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
