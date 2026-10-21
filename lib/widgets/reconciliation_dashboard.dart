import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../screens/shift_handover_screen.dart';

class ReconciliationDashboardWidget extends StatelessWidget {
  final ReconciliationResult result;
  final MoMoProvider provider;
  final VoidCallback onCloseShift;

  const ReconciliationDashboardWidget({
    super.key,
    required this.result,
    required this.provider,
    required this.onCloseShift,
  });

  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBalanced = result.status == 'BALANCED';
    final isShortage = result.status == 'SHORTAGE';

    final Color statusColor = isBalanced
        ? const Color(0xFF1E8E3E)
        : isShortage
            ? const Color(0xFFD93025)
            : const Color(0xFF1A73E8);

    final Color statusBg = isDark
        ? (isBalanced
            ? const Color(0xFF0F3818)
            : isShortage
                ? const Color(0xFF3E1210)
                : const Color(0xFF10284A))
        : (isBalanced
            ? const Color(0xFFE6F4EA)
            : isShortage
                ? const Color(0xFFFCE8E6)
                : const Color(0xFFE8F0FE));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: statusBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Hero Status Banner ───
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.18),
                  child: Icon(
                    isBalanced
                        ? Icons.check_circle_rounded
                        : isShortage
                            ? Icons.warning_amber_rounded
                            : Icons.arrow_circle_up_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced
                            ? 'BALANCED DRAWER'
                            : '${result.status}: GHS ${_currencyFormatter.format(result.cashVariance.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBalanced
                            ? 'Drawer cash perfectly matches recorded inflows & outflows'
                            : isShortage
                                ? 'Counted cash is less than expected drawer total'
                                : 'Counted cash exceeds expected drawer total',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── 3-Column Core Metrics ───
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCol(
                      context,
                      'Expected',
                      'GHS ${_currencyFormatter.format(result.expectedPhysicalCash)}',
                      isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
                  ),
                  Expanded(
                    child: _buildMetricCol(
                      context,
                      'Counted',
                      'GHS ${_currencyFormatter.format(result.physicalCashCount)}',
                      const Color(0xFF1A73E8),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? const Color(0xFF3C4043) : const Color(0xFFE8EAED),
                  ),
                  Expanded(
                    child: _buildMetricCol(
                      context,
                      'Variance',
                      '${result.cashVariance >= 0 ? "+" : "-"} GHS ${_currencyFormatter.format(result.cashVariance.abs())}',
                      statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Before vs After Cash Flow Waterfall ───
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
                ),
              ),
              child: Column(
                children: [
                  _buildLedgerRow(
                    context,
                    label: 'Opening Drawer Float',
                    value: 'GHS ${_currencyFormatter.format(provider.initialDrawerOpeningBalance)}',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF1A73E8),
                  ),
                  const Divider(height: 12),
                  _buildLedgerRow(
                    context,
                    label: 'Cash Received (Deposits/Airtime) (+)',
                    value: 'GHS ${_currencyFormatter.format(result.totalCashIn)}',
                    icon: Icons.arrow_downward_rounded,
                    iconColor: const Color(0xFF1E8E3E),
                  ),
                  const Divider(height: 12),
                  _buildLedgerRow(
                    context,
                    label: 'Cash Paid Out (Withdrawals) (-)',
                    value: 'GHS ${_currencyFormatter.format(result.totalCashOut)}',
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFFD93025),
                  ),
                  if (result.totalPettyCash > 0) ...[
                    const Divider(height: 12),
                    _buildLedgerRow(
                      context,
                      label: 'Petty Cash Expenses (-)',
                      value: 'GHS ${_currencyFormatter.format(result.totalPettyCash)}',
                      icon: Icons.shopping_bag_outlined,
                      iconColor: const Color(0xFFE37400),
                    ),
                  ],
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '= Expected Drawer Cash:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF202124),
                        ),
                      ),
                      Text(
                        'GHS ${_currencyFormatter.format(result.expectedPhysicalCash)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  _buildLedgerRow(
                    context,
                    label: 'Commissions Earned (Profit)',
                    value: '+ GHS ${_currencyFormatter.format(result.totalCommissions)}',
                    icon: Icons.monetization_on_outlined,
                    iconColor: const Color(0xFF1E8E3E),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Leak & Fraud Radar (AI Guard) ───
            _buildLeakRadar(context, provider.shiftLeakRadarItems, isDark),
            const SizedBox(height: 12),

            // ─── Network Carrier Breakdown ───
            if (result.networkBreakdown != null && result.networkBreakdown!.isNotEmpty) ...[
              _buildNetworkBreakdown(context, result.networkBreakdown!, isDark),
              const SizedBox(height: 12),
            ],

            // ─── AI Audit Diagnosis ───
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25272A) : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1A73E8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audit Diagnosis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.aiDiagnosis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── WhatsApp Report to Boss Button ───
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E8E3E),
                side: const BorderSide(color: Color(0xFF1E8E3E)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF1E8E3E)),
              label: const Text(
                'Send Report to Boss (WhatsApp)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => provider.sendShiftSummaryToWhatsApp(context: context),
            ),
            const SizedBox(height: 10),

            // ─── Action Buttons ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.swap_horizontal_circle_rounded, size: 18),
                    label: const Text(
                      'Shift Handover',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShiftHandoverScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1A73E8) : const Color(0xFF202124),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.lock_clock_rounded, size: 18),
                    label: Text(
                      'Close Shift #${provider.currentShiftNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: onCloseShift,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkBreakdown(
    BuildContext context,
    Map<String, NetworkVolumeSummary> breakdown,
    bool isDark,
  ) {
    final activeEntries = breakdown.entries.where((e) => e.value.txCount > 0).toList();
    if (activeEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cell_tower_rounded, size: 14, color: Color(0xFF1A73E8)),
              const SizedBox(width: 6),
              Text(
                'Carrier Network Breakdown',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: activeEntries.map((e) {
              final summary = e.value;
              final Color badgeColor;
              final String label;
              switch (summary.network) {
                case NetworkProvider.mtn:
                  badgeColor = const Color(0xFFF9AB00);
                  label = 'MTN';
                  break;
                case NetworkProvider.telecel:
                  badgeColor = Colors.red;
                  label = 'Telecel';
                  break;
                case NetworkProvider.at:
                  badgeColor = Colors.blue;
                  label = 'AT';
                  break;
                case NetworkProvider.gmoney:
                  badgeColor = Colors.teal;
                  label = 'G-Money';
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$label: GHS ${_currencyFormatter.format(summary.netVolume)} (${summary.txCount} txns)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(BuildContext context, String title, String val, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF3C4043),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124),
          ),
        ),
      ],
    );
  }

  Widget _buildLeakRadar(
    BuildContext context,
    List<LeakRadarItem> items,
    bool isDark,
  ) {
    final hasWarning = items.any((i) => i.severity == LeakSeverity.warning || i.severity == LeakSeverity.danger);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWarning
              ? const Color(0xFFE37400).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasWarning ? Icons.shield_rounded : Icons.verified_user_rounded,
                    size: 16,
                    color: hasWarning ? const Color(0xFFE37400) : const Color(0xFF1E8E3E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Leak & Fraud Radar (AI Guard)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasWarning
                          ? const Color(0xFFE37400)
                          : (isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E)),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (hasWarning ? const Color(0xFFE37400) : const Color(0xFF1E8E3E)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasWarning ? '${items.where((i) => i.severity != LeakSeverity.safe).length} FLAG(S)' : 'ALL SECURE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: hasWarning ? const Color(0xFFE37400) : const Color(0xFF1E8E3E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final Color itemColor;
            final IconData itemIcon;
            switch (item.severity) {
              case LeakSeverity.danger:
                itemColor = const Color(0xFFD93025);
                itemIcon = Icons.warning_rounded;
                break;
              case LeakSeverity.warning:
                itemColor = const Color(0xFFE37400);
                itemIcon = item.category == 'reversal' ? Icons.replay_rounded : Icons.hourglass_top_rounded;
                break;
              case LeakSeverity.info:
                itemColor = const Color(0xFF1A73E8);
                itemIcon = Icons.info_outline_rounded;
                break;
              case LeakSeverity.safe:
                itemColor = const Color(0xFF1E8E3E);
                itemIcon = Icons.check_circle_outline_rounded;
                break;
            }

            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: itemColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(itemIcon, size: 14, color: itemColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF202124),
                              ),
                            ),
                            if (item.amountFormatted != null)
                              Text(
                                item.amountFormatted!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: itemColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
