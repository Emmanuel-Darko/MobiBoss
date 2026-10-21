import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../widgets/shift_history_card.dart';
import '../widgets/shift_analytics_dashboard.dart';

class ShiftHistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const ShiftHistoryScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ShiftRecord> _filterShifts(List<ShiftRecord> shifts) {
    var list = shifts;

    if (_statusFilter != 'ALL') {
      list = list.where((s) => s.status.toUpperCase() == _statusFilter).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) {
        final matchNum = 'shift #${s.shiftNumber}'.toLowerCase().contains(query) || s.shiftNumber.toString() == query;
        final matchDiag = s.aiDiagnosis.toLowerCase().contains(query);
        final matchStatus = s.status.toLowerCase().contains(query);
        return matchNum || matchDiag || matchStatus;
      }).toList();
    }

    return list;
  }

  Future<void> _exportShiftsCsv(BuildContext context, MoMoProvider provider) async {
    final csv = provider.exportShiftHistoryToCsv();
    final bytes = Uint8List.fromList(csv.codeUnits);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'MobiBoss_Shift_Settlements_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<MoMoProvider>();
    final allShifts = provider.shiftHistory;
    final filteredShifts = _filterShifts(allShifts);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift History & Intelligence',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${allShifts.length} closed shifts recorded',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export Shifts to CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: allShifts.isEmpty ? null : () => _exportShiftsCsv(context, provider),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await provider.reloadShiftHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Shift history reloaded'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(
              icon: Icon(Icons.timeline_rounded, size: 20),
              text: 'Shift Timeline',
            ),
            Tab(
              icon: Icon(Icons.insights_rounded, size: 20),
              text: 'Performance Analytics',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── Tab 1: Shift Timeline ───
          _buildTimelineTab(context, provider, allShifts, filteredShifts),

          // ─── Tab 2: Performance Analytics ───
          ShiftAnalyticsDashboard(provider: provider),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(
    BuildContext context,
    MoMoProvider provider,
    List<ShiftRecord> allShifts,
    List<ShiftRecord> filteredShifts,
  ) {
    final theme = Theme.of(context);

    if (allShifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 16),
              Text(
                'No Closed Shifts Yet',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'When you reconcile your drawer and tap "Close Shift & Carry Forward", shift settlement records will appear here with full audits and analytics.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Reconciliation'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ─── Search & Status Filter Row ───
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by shift #, diagnosis, status...',
                  hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 8),
              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All (${allShifts.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('BALANCED', 'Balanced (${provider.shiftStatusCounts['BALANCED'] ?? 0})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('SHORTAGE', 'Shortage (${provider.shiftStatusCounts['SHORTAGE'] ?? 0})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('OVERAGE', 'Overage (${provider.shiftStatusCounts['OVERAGE'] ?? 0})'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ─── Shift Cards List ───
        Expanded(
          child: filteredShifts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt_off_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No shifts match your filter',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _statusFilter = 'ALL';
                              _searchController.clear();
                            });
                          },
                          child: const Text('Reset Filters'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: filteredShifts.length,
                  itemBuilder: (context, index) {
                    final shift = filteredShifts[index];
                    return ShiftHistoryCard(
                      key: ValueKey(shift.id),
                      shift: shift,
                      initialExpanded: index == 0 && filteredShifts.length == 1,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      onSelected: (val) {
        if (val) {
          setState(() {
            _statusFilter = key;
          });
        }
      },
    );
  }
}
