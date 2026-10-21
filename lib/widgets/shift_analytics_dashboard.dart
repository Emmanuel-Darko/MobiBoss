import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/mobiboss_provider.dart';
import '../models/mobiboss_models.dart';

class ShiftAnalyticsDashboard extends StatelessWidget {
  final MoMoProvider provider;

  const ShiftAnalyticsDashboard({
    super.key,
    required this.provider,
  });

  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shifts = provider.shiftHistory;

    if (shifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Shift Intelligence Yet',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Close your first shift from the Reconciliation screen to start tracking shift-level variance trends and earnings intelligence.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalShifts = shifts.length;
    final balancedRate = provider.balancedShiftRate;
    final streak = provider.balancedShiftStreak;
    final totalComms = provider.totalShiftCommissionsAllTime;
    final avgVariance = provider.averageShiftVariance;
    final statusCounts = provider.shiftStatusCounts;
    final balancedCount = statusCounts['BALANCED'] ?? 0;
    final shortageCount = statusCounts['SHORTAGE'] ?? 0;
    final overageCount = statusCounts['OVERAGE'] ?? 0;

    // Up to last 10 shifts in chronological order for charts
    final chartShifts = shifts.take(10).toList().reversed.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 1. Scorecards Grid ───
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _buildScorecard(
                context,
                title: 'Total Shifts',
                value: '$totalShifts',
                subtitle: '${provider.totalShiftTxCountAllTime} total txs',
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF1A73E8),
              ),
              _buildScorecard(
                context,
                title: 'Balanced Rate',
                value: '${balancedRate.toStringAsFixed(1)}%',
                subtitle: '$balancedCount of $totalShifts balanced',
                icon: Icons.verified_rounded,
                iconColor: const Color(0xFF1E8E3E),
              ),
              _buildScorecard(
                context,
                title: 'Current Streak',
                value: streak > 0 ? '$streak Shifts' : '0 Shifts',
                subtitle: streak > 0 ? '🔥 Balanced in a row' : 'Target: 0 variance',
                icon: Icons.local_fire_department_rounded,
                iconColor: streak > 0 ? const Color(0xFFEA8600) : Colors.grey,
              ),
              _buildScorecard(
                context,
                title: 'Shift Commissions',
                value: 'GHS ${_currencyFormatter.format(totalComms)}',
                subtitle: 'Avg GHS ${_currencyFormatter.format(totalShifts > 0 ? totalComms / totalShifts : 0.0)}/shift',
                icon: Icons.monetization_on_rounded,
                iconColor: const Color(0xFF1E8E3E),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── 2. Shift Status Distribution Bar ───
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reconciliation Accuracy',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Breakdown of closed shifts by settlement status',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Multi-segment progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (balancedCount > 0)
                            Expanded(
                              flex: balancedCount,
                              child: Container(color: const Color(0xFF1E8E3E)),
                            ),
                          if (shortageCount > 0)
                            Expanded(
                              flex: shortageCount,
                              child: Container(color: const Color(0xFFD93025)),
                            ),
                          if (overageCount > 0)
                            Expanded(
                              flex: overageCount,
                              child: Container(color: const Color(0xFF1A73E8)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusLegend(
                        label: 'Balanced ($balancedCount)',
                        color: const Color(0xFF1E8E3E),
                        theme: theme,
                      ),
                      _buildStatusLegend(
                        label: 'Shortage ($shortageCount)',
                        color: const Color(0xFFD93025),
                        theme: theme,
                      ),
                      _buildStatusLegend(
                        label: 'Overage ($overageCount)',
                        color: const Color(0xFF1A73E8),
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── 3. Variance History Chart ───
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variance Trend (Last 10 Shifts)',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target: GHS 0.00 cash variance',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Avg |GHS ${_currencyFormatter.format(avgVariance)}|',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A73E8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 170,
                    child: _buildVarianceChart(chartShifts, isDark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── 4. Shift Commission Earnings Bar Chart ───
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commissions per Shift (GHS)',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Best Single Shift: GHS ${_currencyFormatter.format(provider.bestSingleShiftCommission)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1E8E3E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 170,
                    child: _buildCommissionChart(chartShifts, isDark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── 5. Week-over-Week Comparison ───
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Shift Performance',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildWeekTile(
                          context,
                          title: 'This Week',
                          shiftsCount: provider.thisWeekShifts.length,
                          commissions: provider.thisWeekShiftCommissions,
                          color: const Color(0xFF1E8E3E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildWeekTile(
                          context,
                          title: 'Last Week',
                          shiftsCount: provider.lastWeekShifts.length,
                          commissions: provider.lastWeekShiftCommissions,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScorecard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend({
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVarianceChart(List<ShiftRecord> chartShifts, bool isDark) {
    if (chartShifts.isEmpty) return const SizedBox();

    final spots = <FlSpot>[];
    double maxAbsVal = 10.0;

    for (int i = 0; i < chartShifts.length; i++) {
      final v = chartShifts[i].cashVariance;
      if (v.abs() > maxAbsVal) maxAbsVal = v.abs();
      spots.add(FlSpot(i.toDouble(), v));
    }

    final maxY = maxAbsVal * 1.3;
    final minY = -maxAbsVal * 1.3;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (chartShifts.length - 1).toDouble().clamp(0.0, 9.0),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx >= 0 && idx < chartShifts.length) {
                  final s = chartShifts[idx];
                  return LineTooltipItem(
                    'Shift #${s.shiftNumber}\nVar: ${s.cashVariance >= 0 ? "+" : ""}GHS ${s.cashVariance.toStringAsFixed(2)}\n${s.status}',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxAbsVal > 0 ? maxAbsVal : 5.0,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(
                color: const Color(0xFF1E8E3E).withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [4, 4],
              );
            }
            return FlLine(
              color: isDark ? const Color(0xFF333538) : const Color(0xFFE8EAED),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < chartShifts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '#${chartShifts[idx].shiftNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: const Color(0xFF1A73E8),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final v = spot.y;
                final dotColor = v == 0
                    ? const Color(0xFF1E8E3E)
                    : v < 0
                        ? const Color(0xFFD93025)
                        : const Color(0xFF1A73E8);
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: dotColor,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionChart(List<ShiftRecord> chartShifts, bool isDark) {
    if (chartShifts.isEmpty) return const SizedBox();

    final maxComm = chartShifts.map((s) => s.totalCommissions).fold(50.0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxComm * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = chartShifts[groupIndex];
              return BarTooltipItem(
                'Shift #${s.shiftNumber}\nComm: GHS ${s.totalCommissions.toStringAsFixed(2)}\nTx: ${s.transactionCount}',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < chartShifts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '#${chartShifts[idx].shiftNumber}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: chartShifts.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: s.totalCommissions,
                color: const Color(0xFF1E8E3E),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekTile(
    BuildContext context, {
    required String title,
    required int shiftsCount,
    required double commissions,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GHS ${_currencyFormatter.format(commissions)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$shiftsCount shifts completed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
