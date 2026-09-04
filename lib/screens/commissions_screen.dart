import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/momo_models.dart';
import '../providers/momo_provider.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';

class CommissionsScreen extends StatefulWidget {
  const CommissionsScreen({super.key});

  @override
  State<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends State<CommissionsScreen> {
  int _viewMode = 0; // 0: Commissions & Transfers, 1: Performance Analytics

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final todayComm = provider.todayCommission;
    final weeklyComm = provider.weeklyCommission;
    final monthlyComm = provider.monthlyCommission;
    final totalComm = provider.totalCommission;
    final dailyTarget = provider.dailyCommissionTarget;
    final dailyProgress = dailyTarget > 0 ? (todayComm / dailyTarget).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Mode Switcher (Commissions Hub vs Visual Analytics) ───
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Earnings & Transfer'),
                icon: Icon(Icons.monetization_on_rounded, size: 16),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Performance Analytics'),
                icon: Icon(Icons.bar_chart_rounded, size: 16),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) => setState(() => _viewMode = set.first),
          ),
          const SizedBox(height: 14),

          if (_viewMode == 0) ...[
            // ─── 1. Main Commission Hero Card ───
            Card(
              color: const Color(0xFF1E8E3E), // Agent Green
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Commission",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${(dailyProgress * 100).toInt()}% of goal',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'GHS ${todayComm.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: dailyProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Target: GHS ${dailyTarget.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        InkWell(
                          onTap: () => _showTargetEditDialog(context, provider),
                          child: const Text(
                            'Edit Target',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── 2. Metric Grid (Week, Month, All-Time) ───
            Row(
              children: [
                Expanded(child: _buildMetricTile('This Week', 'GHS ${weeklyComm.toStringAsFixed(2)}', Icons.calendar_view_week_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricTile('This Month', 'GHS ${monthlyComm.toStringAsFixed(2)}', Icons.calendar_month_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _buildMetricTile('All-Time', 'GHS ${totalComm.toStringAsFixed(2)}', Icons.account_balance_rounded)),
              ],
            ),
            const SizedBox(height: 14),

            // ─── 3. Automated Commission Transfer to Float / Wallet ───
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2D2F31)
                      : const Color(0xFFE8EAED),
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
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1A3B66)
                                : const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF1A73E8), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transfer SIM Commission',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Sweep accumulated agent commission directly into Float or MoMo Wallet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF9AA0A6)
                                      : const Color(0xFF5F6368),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                            label: const Text('To Float', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _showTransferModal(context, provider, toMainFloat: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.phone_android_rounded, size: 16),
                            label: const Text('To Personal MoMo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _showTransferModal(context, provider, toMainFloat: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ─── 4. Commission Breakdown by Telecom Network ───
            const Text(
              'Earnings by Telecom Network',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildNetworkBreakdownCard(provider),
          ] else ...[
            // ─── 5. Visual Performance Analytics (fl_chart) ───
            _buildPerformanceAnalytics(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkBreakdownCard(MoMoProvider provider) {
    final map = provider.commissionsByNetwork;
    final total = map.values.fold(0.0, (s, v) => s + v);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: map.entries.map((entry) {
            final netName = entry.key.name.toUpperCase();
            final amt = entry.value;
            final pct = total > 0 ? (amt / total) : 0.0;

            Color barColor;
            switch (entry.key) {
              case NetworkProvider.mtn:
                barColor = const Color(0xFFF9AB00);
                break;
              case NetworkProvider.telecel:
                barColor = const Color(0xFFD93025);
                break;
              case NetworkProvider.at:
                barColor = const Color(0xFF1A73E8);
                break;
              case NetworkProvider.gmoney:
                barColor = const Color(0xFF9334E6);
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(netName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        'GHS ${amt.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceAnalytics(MoMoProvider provider) {
    final last7 = provider.last7DaysPerformance;
    final networkComms = provider.commissionsByNetwork;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 7-Day Trading Volume Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7-Day Transaction Volume (GHS)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily total mobile money transaction values',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (last7.map((d) => d.volume).fold(100.0, (max, v) => v > max ? v : max) * 1.25),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final d = last7[groupIndex];
                            return BarTooltipItem(
                              '${d.dayLabel}\nVol: GHS ${d.volume.toStringAsFixed(0)}\nComm: GHS ${d.commission.toStringAsFixed(1)}',
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
                              final index = val.toInt();
                              if (index >= 0 && index < last7.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    last7[index].dayLabel,
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
                      barGroups: last7.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.volume,
                              color: const Color(0xFF1A73E8),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Network Market Share Donut Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Network Revenue Share',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: networkComms[NetworkProvider.mtn] ?? 1.0,
                          title: 'MTN',
                          color: const Color(0xFFF9AB00),
                          radius: 36,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        PieChartSectionData(
                          value: networkComms[NetworkProvider.telecel] ?? 1.0,
                          title: 'Telecel',
                          color: const Color(0xFFD93025),
                          radius: 36,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: networkComms[NetworkProvider.at] ?? 1.0,
                          title: 'AT',
                          color: const Color(0xFF1A73E8),
                          radius: 36,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTransferModal(BuildContext context, MoMoProvider provider, {required bool toMainFloat}) {
    final till = provider.selectedTill;
    final controller = TextEditingController(text: '50');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    toMainFloat ? 'Transfer Commission to Float' : 'Transfer Commission to MoMo Wallet',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sweeps earned SIM commission from ${till.tillName} (${till.network.name.toUpperCase()}) '
                '${toMainFloat ? "into your Main Float account." : "into your personal MoMo account."}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount to Transfer (GHS)',
                  prefixText: 'GHS ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [20, 50, 100, 200].map((amt) {
                  return ActionChip(
                    label: Text('GHS $amt'),
                    onPressed: () => controller.text = amt.toString(),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Initiate Automated Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final amt = double.tryParse(controller.text) ?? 0.0;
                  if (amt <= 0) return;

                  Navigator.pop(ctx);

                  final plan = UssdService.buildCommissionTransferPlan(
                    till: till,
                    amount: amt,
                    toMainFloat: toMainFloat,
                  );

                  TopToast.show(
                    context,
                    title: 'Commission Transfer Initiated',
                    message: 'Auto-navigating ${plan.steps.length} steps on ${till.network.name.toUpperCase()}... Enter PIN when prompted.',
                    icon: Icons.bolt_rounded,
                    backgroundColor: const Color(0xFF1E8E3E),
                  );

                  await UssdService.initiateCustomAutomatedSession(
                    rootCode: plan.rootCode,
                    steps: plan.steps,
                    fallbackShortCode: plan.displayShortCode,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTargetEditDialog(BuildContext context, MoMoProvider provider) {
    final controller = TextEditingController(text: provider.dailyCommissionTarget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Daily Commission Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Amount (GHS)',
            prefixText: 'GHS ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 150.0;
              provider.updateDailyTarget(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save Target'),
          ),
        ],
      ),
    );
  }
}
