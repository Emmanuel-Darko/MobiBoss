import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';

class SmsRecordsListWidget extends StatefulWidget {
  final List<SmsRecord> records;
  final MoMoProvider provider;
  final String activePeriod;

  const SmsRecordsListWidget({
    super.key,
    required this.records,
    required this.provider,
    required this.activePeriod,
  });

  @override
  State<SmsRecordsListWidget> createState() => _SmsRecordsListWidgetState();
}

class _SmsRecordsListWidgetState extends State<SmsRecordsListWidget> {
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  static final _dateFormat = DateFormat('hh:mm a • d MMM');
  bool _isExpanded = false;
  static const int _previewCount = 5;

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
      case TransactionType.reversal:
        return const Color(0xFFD93025);
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
        return 'ECG';
      case TransactionType.ghanaWater:
        return 'WATER';
      case TransactionType.payTv:
        return 'PAY TV';
      case TransactionType.bankTransfer:
        return 'BANK';
      case TransactionType.reversal:
        return 'REVERSAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = widget.records;
    final totalVolume = records.fold(0.0, (sum, r) => sum + r.amount);

    if (records.isEmpty) {
      final totalScanned = widget.provider.smsRecords.length;
      final discoveredCount = widget.provider.discoveredSenders.length;

      String periodDesc;
      if (widget.activePeriod == 'shift') {
        periodDesc = 'this shift (${widget.provider.shiftTimeRangeDisplay})';
      } else if (widget.activePeriod == 'today') {
        periodDesc = 'today';
      } else {
        periodDesc = 'the selected period';
      }

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  totalScanned > 0 ? Icons.filter_alt_off_rounded : Icons.inbox_outlined,
                  size: 36,
                  color: totalScanned > 0 ? const Color(0xFF1A73E8) : (isDark ? const Color(0xFF5F6368) : const Color(0xFFBDC1C6)),
                ),
                const SizedBox(height: 10),
                if (totalScanned > 0) ...[
                  Text(
                    'No payment messages found for $periodDesc from selected providers.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('View All Messages (Last 7 Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => widget.provider.setReconciliationPeriod('all'),
                  ),
                ] else if (discoveredCount > 0) ...[
                  Text(
                    'Discovered $discoveredCount providers, but no payment confirmation SMS found for $periodDesc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    'No scanned messages yet.\nTap "SCAN MY SHIFT MESSAGES" above to inspect payment confirmations.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final displayRecords = _isExpanded ? records : records.take(_previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Reconciled SMS Feed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${records.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                  ),
                ),
              ],
            ),
            Text(
              'Vol: GHS ${_currencyFormatter.format(totalVolume)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Record Cards
        ...displayRecords.map((record) => _buildRecordCard(record, isDark)),

        // Expand / Collapse Action
        if (records.length > _previewCount)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
            label: Text(
              _isExpanded ? 'Show Less' : 'Show All ${records.length} Transactions',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
      ],
    );
  }

  Widget _buildRecordCard(SmsRecord record, bool isDark) {
    final isCashIn = record.type == TransactionType.cashIn ||
        record.type == TransactionType.airtime ||
        record.type == TransactionType.dataBundle ||
        record.type == TransactionType.ecgElectricity ||
        record.type == TransactionType.ghanaWater ||
        record.type == TransactionType.payTv;

    final color = _getTypeColor(record.type);
    final label = _getTypeLabel(record.type);
    final fraud = widget.provider.checkSmsFraud(record);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.sender,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                          ),
                        ),
                      ),
                      if (record.isVoided || record.isReversed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3E2723) : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.undo_rounded, size: 10, color: Color(0xFFD93025)),
                              SizedBox(width: 2),
                              Text(
                                'Reversed',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD93025),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (fraud.isFraudSuspicious)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF4A1818) : const Color(0xFFFCE8E6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFD93025)),
                              const SizedBox(width: 2),
                              Text(
                                'Suspicious',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13321C) : const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF1E8E3E)),
                              const SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.customerPhone.isNotEmpty ? "${record.customerPhone} • " : ""}${record.reference}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _dateFormat.format(record.timestamp),
                    style: const TextStyle(fontSize: 9, color: Color(0xFF80868B)),
                  ),
                ],
              ),
            ),
            Text(
              '${isCashIn ? '+' : '-'} GHS ${_currencyFormatter.format(record.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                decoration: (record.isVoided || record.isReversed) ? TextDecoration.lineThrough : null,
                color: (record.isVoided || record.isReversed)
                    ? Colors.grey
                    : (isCashIn ? const Color(0xFF1E8E3E) : const Color(0xFFD93025)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
