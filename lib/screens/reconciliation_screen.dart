import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../services/receipt_service.dart';
import 'shift_history_screen.dart';
import '../widgets/denomination_counter.dart';
import '../widgets/reconciliation_dashboard.dart';
import '../widgets/reconciliation_stepper.dart';
import '../widgets/sms_records_list.dart';
import '../widgets/top_toast.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> with AutomaticKeepAliveClientMixin {
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _step1Key = GlobalKey();
  final GlobalKey _step2Key = GlobalKey();
  final GlobalKey _step3Key = GlobalKey();

  bool _step1Expanded = true;
  bool _step2Expanded = true;
  bool _step3Expanded = true;

  /// Tracks the shift number seen last time — detects when a new shift begins.
  int _trackedShiftNumber = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MoMoProvider>();
      _trackedShiftNumber = provider.currentShiftNumber;
      if (provider.smsRecords.isEmpty && !provider.isScanningInbox) {
        provider.scanDeviceInboxAndDiscoverSenders(context);
      }
    });
  }

  /// Called by Consumer/builder on each rebuild — checks if a new shift started.
  void _checkShiftReset(MoMoProvider provider) {
    if (_trackedShiftNumber != -1 && provider.currentShiftNumber != _trackedShiftNumber) {
      _trackedShiftNumber = provider.currentShiftNumber;
      // Reset UI state for the fresh shift
      setState(() {
        _step1Expanded = true;
        _step2Expanded = true;
        _step3Expanded = true;
      });
      // Kick off an inbox scan for the next teller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (provider.smsRecords.isEmpty && !provider.isScanningInbox) {
          provider.scanDeviceInboxAndDiscoverSenders(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToStep(int stepIndex) {
    setState(() {
      if (stepIndex == 0) _step1Expanded = true;
      if (stepIndex == 1) _step2Expanded = true;
      if (stepIndex == 2 || stepIndex == 3) _step3Expanded = true;
    });

    GlobalKey? targetKey;
    switch (stepIndex) {
      case 0:
        targetKey = _step1Key;
        break;
      case 1:
        targetKey = _step2Key;
        break;
      case 2:
      case 3:
        targetKey = _step3Key;
        break;
    }

    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
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

  Future<void> _handleScanInbox(BuildContext context, MoMoProvider provider) async {
    await provider.scanDeviceInboxAndDiscoverSenders(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<MoMoProvider>();
    _checkShiftReset(provider); // Reset UI state if a new shift has started
    final result = provider.lastReconciliation;
    final discoveredSenders = provider.discoveredSenders;
    final isScanning = provider.isScanningInbox;
    final period = provider.reconciliationPeriod;
    final filteredRecords = provider.filteredSmsRecords;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentStep = provider.currentStepperIndex;
    final isScanDone = provider.isScanComplete;
    final isCountDone = provider.isCashCounted;
    final isReviewedDone = result != null;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top Shift Header & History Action ───
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Shift #${provider.currentShiftNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Audit & Settlement',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Started ${DateFormat('hh:mm a').format(provider.currentShiftStartTime)} • ${provider.shiftElapsedTimeDisplay}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Adjust Opening Float (GHS ${_currencyFormatter.format(provider.initialDrawerOpeningBalance)})',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF1A73E8)),
                    onPressed: () => _showEditOpeningFloatDialog(context, provider),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 14),
                    label: Text(
                      'History (${provider.shiftHistory.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShiftHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Top Hero Live Variance Banner (The "Answer First" Experience) ───
          _buildTopHeroVarianceBanner(context, provider, result, isDark),
          const SizedBox(height: 12),

          // ─── Guided Step Progress Stepper Bar ───
          ReconciliationStepper(
            currentStep: currentStep,
            isScanDone: isScanDone,
            isCountDone: isCountDone,
            isReviewedDone: isReviewedDone,
            onStepTapped: _scrollToStep,
          ),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════════════════════
          // STEP 1: SCAN CARRIER PAYMENT MESSAGES (Accordion Card)
          // ═══════════════════════════════════════════════════════════════════
          _buildAccordionHeader(
            stepBadge: 'STEP 1',
            title: 'Scan Carrier Payment Messages',
            icon: Icons.mark_email_read_rounded,
            color: const Color(0xFF1A73E8),
            isCompleted: isScanDone,
            completionBadge: isScanDone ? '${provider.smsRecords.length} SMS Synced' : '',
            isExpanded: _step1Expanded,
            onToggle: () => setState(() => _step1Expanded = !_step1Expanded),
            key: _step1Key,
          ),
          if (_step1Expanded) ...[
            const SizedBox(height: 8),
            _buildStep1ScanCard(context, provider, isDark, isScanning, discoveredSenders.isNotEmpty, period),
            const SizedBox(height: 12),

            // Period Selector (Segmented Button)
            _buildPeriodSelector(context, provider, isDark, period),
            const SizedBox(height: 12),

            // Inline Network Provider Selection (Smart Chips)
            if (discoveredSenders.isNotEmpty) ...[
              _buildInlineProviderSummary(context, provider, isDark),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),

          // ═══════════════════════════════════════════════════════════════════
          // STEP 2: PHYSICAL CASH COUNT & PETTY CASH (Accordion Card)
          // ═══════════════════════════════════════════════════════════════════
          _buildAccordionHeader(
            stepBadge: 'STEP 2',
            title: 'Count Cash in Drawer',
            icon: Icons.payments_rounded,
            color: const Color(0xFFE37400),
            isCompleted: isCountDone,
            completionBadge: isCountDone ? 'GHS ${_currencyFormatter.format(provider.currentCashInDrawer)}' : '',
            isExpanded: _step2Expanded,
            onToggle: () => setState(() => _step2Expanded = !_step2Expanded),
            key: _step2Key,
          ),
          if (_step2Expanded) ...[
            const SizedBox(height: 8),
            DenominationCounterWidget(
              initialDenomination: provider.cashDenomination,
              currentTotal: provider.currentCashInDrawer,
              expectedTotal: provider.expectedDrawerCash,
              onDenominationChanged: (denom) {
                HapticFeedback.selectionClick();
                provider.updateCashDenomination(denom);
              },
              onDirectTotalChanged: (total) {
                HapticFeedback.selectionClick();
                provider.reconcileShift(physicalCash: total);
                if (total > 0) {
                  setState(() => _step3Expanded = true);
                  _scrollToStep(2);
                }
              },
            ),
            const SizedBox(height: 12),

            // Petty Cash Logger Section
            _buildPettyCashCard(context, provider),
          ],
          const SizedBox(height: 12),

          // ═══════════════════════════════════════════════════════════════════
          // STEP 3: RECONCILIATION DASHBOARD & SETTLEMENT (Accordion Card)
          // ═══════════════════════════════════════════════════════════════════
          _buildAccordionHeader(
            stepBadge: 'STEP 3',
            title: 'Shift Balance & Settlement',
            icon: Icons.verified_rounded,
            color: const Color(0xFF1E8E3E),
            isCompleted: isReviewedDone,
            completionBadge: result != null ? result.status : '',
            isExpanded: _step3Expanded,
            onToggle: () => setState(() => _step3Expanded = !_step3Expanded),
            key: _step3Key,
          ),
          if (_step3Expanded) ...[
            const SizedBox(height: 8),
            if (result != null) ...[
              ReconciliationDashboardWidget(
                result: result,
                provider: provider,
                onCloseShift: () => _showShiftCloseDialog(context, provider),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Complete Step 1 (Scan Messages) and Step 2 (Count Cash) above to view your settlement dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Active Reconciled SMS Feed
            SmsRecordsListWidget(
              records: filteredRecords,
              provider: provider,
              activePeriod: period,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTopHeroVarianceBanner(BuildContext context, MoMoProvider provider, ReconciliationResult? result, bool isDark) {
    final isCalculated = result != null;
    final isBalanced = result?.status == 'BALANCED';
    final isShortage = result?.status == 'SHORTAGE';

    final Color statusColor = !isCalculated
        ? const Color(0xFF1A73E8)
        : isBalanced
            ? const Color(0xFF1E8E3E)
            : isShortage
                ? const Color(0xFFD93025)
                : const Color(0xFF1A73E8);

    final Color statusBg = isDark
        ? (!isCalculated
            ? const Color(0xFF161E2E)
            : isBalanced
                ? const Color(0xFF0F3818)
                : isShortage
                    ? const Color(0xFF3E1210)
                    : const Color(0xFF10284A))
        : (!isCalculated
            ? const Color(0xFFEEF4FD)
            : isBalanced
                ? const Color(0xFFE6F4EA)
                : isShortage
                    ? const Color(0xFFFCE8E6)
                    : const Color(0xFFE8F0FE));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.35), width: 1.5),
      ),
      color: statusBg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.18),
                  child: Icon(
                    !isCalculated
                        ? Icons.hourglass_top_rounded
                        : isBalanced
                            ? Icons.check_circle_rounded
                            : isShortage
                                ? Icons.warning_amber_rounded
                                : Icons.arrow_circle_up_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !isCalculated
                            ? 'AWAITING CASH COUNT'
                            : isBalanced
                                ? 'BALANCED DRAWER'
                                : '${result.status}: GHS ${_currencyFormatter.format(result.cashVariance.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        !isCalculated
                            ? 'Expected in drawer: GHS ${_currencyFormatter.format(provider.expectedDrawerCash)} • Enter count below'
                            : isBalanced
                                ? 'Physical cash matches all POS inflows, outflows & float'
                                : isShortage
                                    ? 'Physical cash is less than expected drawer total'
                                    : 'Physical cash exceeds expected drawer total',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCalculated)
                  IconButton(
                    tooltip: 'Send WhatsApp Report to Boss',
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF1E8E3E), size: 18),
                    onPressed: () => provider.sendShiftSummaryToWhatsApp(context: context),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2022) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expected Cash', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'GHS ${_currencyFormatter.format(isCalculated ? result.expectedPhysicalCash : provider.expectedDrawerCash)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2022) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Counted Cash', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isCalculated ? 'GHS ${_currencyFormatter.format(result.physicalCashCount)}' : 'Not Counted',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isCalculated ? statusColor : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isCalculated) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2022) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Variance', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${result.cashVariance >= 0 ? "+" : "-"}GHS ${_currencyFormatter.format(result.cashVariance.abs())}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionHeader({
    required String stepBadge,
    required String title,
    required IconData icon,
    required Color color,
    required bool isCompleted,
    required String completionBadge,
    required bool isExpanded,
    required VoidCallback onToggle,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isCompleted ? const Color(0xFF1E8E3E) : color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stepBadge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? const Color(0xFF1E8E3E) : color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCompleted ? Icons.check_circle_rounded : icon,
              size: 16,
              color: isCompleted ? const Color(0xFF1E8E3E) : color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            if (isCompleted && completionBadge.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E8E3E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  completionBadge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E8E3E)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1ScanCard(
    BuildContext context,
    MoMoProvider provider,
    bool isDark,
    bool isScanning,
    bool hasScanned,
    String period,
  ) {
    String scanButtonText;
    if (isScanning) {
      scanButtonText = 'Scanning SMS Inbox...';
    } else if (hasScanned) {
      scanButtonText = 'RESCAN (${provider.smsRecords.length} Transactions Found)';
    } else if (period == 'shift') {
      scanButtonText = 'SCAN MY SHIFT MESSAGES';
    } else if (period == 'today') {
      scanButtonText = "SCAN TODAY'S MESSAGES";
    } else {
      scanButtonText = 'SCAN ALL MESSAGES';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasScanned
              ? const Color(0xFF1E8E3E).withValues(alpha: 0.4)
              : const Color(0xFF1A73E8),
          width: hasScanned ? 1 : 1.5,
        ),
      ),
      color: isDark
          ? (hasScanned ? const Color(0xFF132B1B) : const Color(0xFF10284A))
          : (hasScanned ? const Color(0xFFF1F8F4) : const Color(0xFFEEF4FD)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (hasScanned ? const Color(0xFF1E8E3E) : const Color(0xFF1A73E8)).withValues(alpha: 0.15),
                  child: Icon(
                    hasScanned ? Icons.check_circle_rounded : Icons.mark_email_read_rounded,
                    color: hasScanned ? const Color(0xFF1E8E3E) : const Color(0xFF1A73E8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasScanned ? 'SMS Inbox Synced ✓' : 'Auto-Scan Payment Messages',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasScanned
                            ? '${provider.smsRecords.length} transactions imported from active providers.'
                            : 'Scan MTN, Telecel, AT Money, and Bank confirmation SMS.',
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
            const SizedBox(height: 12),

            // High-Visibility Action Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: hasScanned
                    ? (isDark ? const Color(0xFF1E8E3E) : const Color(0xFF137333))
                    : const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      hasScanned ? Icons.refresh_rounded : Icons.sync_rounded,
                      size: 18,
                    ),
              label: Text(
                scanButtonText,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              onPressed: isScanning ? null : () => _handleScanInbox(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    MoMoProvider provider,
    bool isDark,
    String currentPeriod,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 6),
                  Text(
                    'Reconciliation Time Period:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF3C4043),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentPeriod == 'shift'
                      ? provider.shiftTimeRangeDisplay
                      : currentPeriod == 'today'
                          ? 'Today (00:00 → Now)'
                          : 'Last 7 Days',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A73E8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'shift',
                label: Text('This Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.access_time_rounded, size: 14),
              ),
              ButtonSegment<String>(
                value: 'today',
                label: Text('Full Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.today_rounded, size: 14),
              ),
              ButtonSegment<String>(
                value: 'all',
                label: Text('All Messages', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                icon: Icon(Icons.history_rounded, size: 14),
              ),
            ],
            selected: {currentPeriod},
            onSelectionChanged: (newSelection) {
              if (newSelection.isNotEmpty) {
                provider.setReconciliationPeriod(newSelection.first);
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkToggleChip({
    required BuildContext context,
    required MoMoProvider provider,
    required NetworkProvider network,
    required String name,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = provider.isNetworkSelected(network);
    final count = provider.networkParsedTxCount(network);

    return FilterChip(
      selected: isSelected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      avatar: CircleAvatar(
        radius: 8,
        backgroundColor: color,
      ),
      label: Text(
        '$name ($count)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124)),
        ),
      ),
      selectedColor: color,
      backgroundColor: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
      side: BorderSide(
        color: isSelected ? color : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        provider.toggleNetworkSelection(network);
      },
    );
  }

  Widget _buildInlineProviderSummary(
    BuildContext context,
    MoMoProvider provider,
    bool isDark,
  ) {
    final discovered = provider.discoveredSenders;
    final selected = provider.selectedSenders;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E8E3E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cell_tower_rounded, color: Color(0xFF1E8E3E), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Telecom Networks',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Tap to filter carriers in audit',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      provider.selectAllSenders();
                    },
                    child: const Text('All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      provider.clearSenderSelection();
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Telecom Network Toggle Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildNetworkToggleChip(
                context: context,
                provider: provider,
                network: NetworkProvider.mtn,
                name: 'MTN MoMo',
                color: const Color(0xFFF9AB00),
                isDark: isDark,
              ),
              _buildNetworkToggleChip(
                context: context,
                provider: provider,
                network: NetworkProvider.telecel,
                name: 'Telecel Cash',
                color: const Color(0xFFD93025),
                isDark: isDark,
              ),
              _buildNetworkToggleChip(
                context: context,
                provider: provider,
                network: NetworkProvider.at,
                name: 'AT Money',
                color: const Color(0xFF1A73E8),
                isDark: isDark,
              ),
              _buildNetworkToggleChip(
                context: context,
                provider: provider,
                network: NetworkProvider.gmoney,
                name: 'G-Money',
                color: const Color(0xFF00897B),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Advanced Sender Inspector for power users
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Advanced: ${discovered.length} individual sender address(es)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
                ),
              ),
              leading: const Icon(Icons.tune_rounded, size: 14),
              children: discovered.values.map((info) {
                final isSelected = selected.contains(info.address.toUpperCase().trim());
                final catColor = _getCategoryColor(info.category);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFF1A73E8),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  secondary: CircleAvatar(
                    radius: 12,
                    backgroundColor: catColor.withValues(alpha: 0.15),
                    child: Icon(_getCategoryIcon(info.category), color: catColor, size: 12),
                  ),
                  title: Text(info.address, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  subtitle: Text('${info.parsedTransactions} confirmed txns', style: const TextStyle(fontSize: 9)),
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    provider.toggleSenderSelection(info.address);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashCard(BuildContext context, MoMoProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenses = provider.todayPettyCashExpenses;
    final totalSpent = provider.totalTodayPettyCash;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Color(0xFFE37400), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Petty Cash Expenses (${expenses.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Log Expense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddPettyCashDialog(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Drawer cash taken out for shop expenses, meals, repairs, etc.',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
              ),
            ),
            if (expenses.isNotEmpty) ...[
              const Divider(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Petty Cash Spent:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFBDC1C6) : const Color(0xFF3C4043),
                    ),
                  ),
                  Text(
                    'GHS ${_currencyFormatter.format(totalSpent)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE37400)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...expenses.take(3).map((exp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE37400).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exp.category.name.toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFE37400)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exp.note.isNotEmpty ? exp.note : 'Shop expense',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '- GHS ${_currencyFormatter.format(exp.amount)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD93025)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeletePettyCash(context, provider, exp),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeletePettyCash(BuildContext context, MoMoProvider provider, PettyCashExpense exp) {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD93025), size: 22),
            SizedBox(width: 8),
            Text('Delete Petty Cash Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete GHS ${_currencyFormatter.format(exp.amount)} (${exp.category.name}) from logged shop expenses?',
              style: const TextStyle(fontSize: 12),
            ),
            if (provider.tellers.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Supervisor / Attendant PIN',
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
            onPressed: () {
              if (provider.tellers.isNotEmpty && !provider.verifyTellerPin(pinCtrl.text.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN. Action denied.')),
                );
                return;
              }
              provider.deletePettyCashExpense(exp.id);
              Navigator.pop(ctx);
              TopToast.show(
                context,
                title: 'Petty Cash Removed',
                message: 'Expense of GHS ${_currencyFormatter.format(exp.amount)} was removed.',
                icon: Icons.delete_outline_rounded,
                backgroundColor: const Color(0xFF5F6368),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddPettyCashDialog(BuildContext context, MoMoProvider provider) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    PettyCashCategory selectedCategory = PettyCashCategory.attendantMeal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Log Petty Cash Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record cash taken from drawer for expenses:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PettyCashCategory>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    items: PettyCashCategory.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (GHS)',
                      prefixText: 'GHS ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Note / Reason (e.g. Lunch, Receipt roll)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE37400)),
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text);
                  if (amt == null || amt <= 0) return;
                  Navigator.pop(ctx);
                  final expense = PettyCashExpense(
                    id: 'pc_${DateTime.now().millisecondsSinceEpoch}',
                    amount: amt,
                    category: selectedCategory,
                    note: noteCtrl.text.trim(),
                    tellerName: provider.activeTeller?.name ?? 'Primary Attendant',
                    timestamp: DateTime.now(),
                  );
                  await provider.addPettyCashExpense(expense);
                },
                child: const Text('Save Expense'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditOpeningFloatDialog(BuildContext context, MoMoProvider provider) {
    final ctrl = TextEditingController(text: provider.initialDrawerOpeningBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Shift Opening Float', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change the cash you started this shift with. This will instantly recalculate your expected drawer cash and live variance.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Opening Drawer Float (GHS)',
                prefixText: 'GHS ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val >= 0) {
                await provider.updateOpeningDrawerBalance(val);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  TopToast.show(
                    context,
                    title: 'Opening Float Updated',
                    message: 'Shift opening balance set to GHS ${_currencyFormatter.format(val)}',
                    icon: Icons.check_circle_rounded,
                    backgroundColor: const Color(0xFF1E8E3E),
                  );
                }
              }
            },
            child: const Text('Update Float'),
          ),
        ],
      ),
    );
  }

  void _showShiftCloseDialog(BuildContext context, MoMoProvider provider) {
    final counted = provider.currentCashInDrawer;
    final nextOpeningCtrl = TextEditingController(text: counted.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF1E8E3E), size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Complete Shift #${provider.currentShiftNumber}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your shift audit will be saved to your permanent shift ledger.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Closing Drawer Cash:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(
                          'GHS ${_currencyFormatter.format(counted)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A73E8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Opening Cash Float for Next Shift:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nextOpeningCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: 'GHS ',
                      helperText: 'Defaults to closing cash. Change if depositing part of float to bank.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E8E3E)),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Confirm & Settle Shift'),
                onPressed: () async {
                  final nextOpening = double.tryParse(nextOpeningCtrl.text.trim()) ?? counted;
                  Navigator.pop(ctx);
                  final shift = await provider.closeCurrentShift(
                    countedCash: counted,
                    context: context,
                    nextShiftOpeningCash: nextOpening,
                  );
                  if (!mounted) return;
                  _showPostCloseSettlementSheet(this.context, shift);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPostCloseSettlementSheet(BuildContext context, ShiftRecord shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isBalanced = shift.status.toUpperCase() == 'BALANCED';
        final isShortage = shift.status.toUpperCase() == 'SHORTAGE';
        final statusColor = isBalanced
            ? const Color(0xFF1E8E3E)
            : isShortage
                ? const Color(0xFFD93025)
                : const Color(0xFF1A73E8);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift #${shift.shiftNumber} Closed & Settled',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Opening cash carried forward to next shift',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Closing Drawer Cash:', style: TextStyle(fontSize: 12)),
                        Text('GHS ${_currencyFormatter.format(shift.closingCash)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cash Variance:', style: TextStyle(fontSize: 12)),
                        Text(
                          '${shift.cashVariance >= 0 ? "+" : ""}GHS ${_currencyFormatter.format(shift.cashVariance)} (${shift.status})',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Commissions Earned:', style: TextStyle(fontSize: 12)),
                        Text('GHS ${_currencyFormatter.format(shift.totalCommissions)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E8E3E))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  final provider = context.read<MoMoProvider>();
                  provider.sendShiftSummaryToWhatsApp(context: context, shift: shift);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Report to Boss (WhatsApp)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E8E3E),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShiftHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: const Text('View Shift History & Analytics →'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptService.printShiftSettlementReport(context: context, shift: shift),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Slip'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptService.shareShiftSettlementPdf(shift: shift),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share PDF'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done & Start Next Shift'),
              ),
            ],
          ),
        );
      },
    );
  }
}
