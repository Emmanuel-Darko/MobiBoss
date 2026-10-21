import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobiboss_models.dart';

class DenominationCounterWidget extends StatefulWidget {
  final CashDenomination initialDenomination;
  final double currentTotal;
  final ValueChanged<CashDenomination> onDenominationChanged;
  final ValueChanged<double> onDirectTotalChanged;

  const DenominationCounterWidget({
    super.key,
    required this.initialDenomination,
    required this.currentTotal,
    required this.onDenominationChanged,
    required this.onDirectTotalChanged,
  });

  @override
  State<DenominationCounterWidget> createState() => _DenominationCounterWidgetState();
}

class _DenominationCounterWidgetState extends State<DenominationCounterWidget> {
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  // Manual entry is the default mode
  bool _isDenominationMode = false;
  late CashDenomination _denomination;
  late TextEditingController _quickCashController;
  final TextEditingController _coinsController = TextEditingController();
  final FocusNode _quickCashFocus = FocusNode();
  Timer? _debounceTimer;

  final List<int> _coreNotes = [100, 50, 20, 10];
  final List<int> _secondaryNotes = [200, 5, 2, 1];
  bool _showAllDenominations = false;

  @override
  void initState() {
    super.initState();
    _denomination = widget.initialDenomination.copyWith();
    _quickCashController = TextEditingController(
      text: widget.currentTotal > 0 ? widget.currentTotal.toStringAsFixed(2) : '',
    );
    if (_denomination.coinTotal > 0) {
      _coinsController.text = _denomination.coinTotal.toStringAsFixed(2);
    }
    final hasSecondary = _secondaryNotes.any((n) => (_denomination.noteCounts[n] ?? 0) > 0);
    if (hasSecondary) {
      _showAllDenominations = true;
    }

    _quickCashFocus.addListener(() {
      if (!_quickCashFocus.hasFocus) {
        _commitQuickCash();
      }
    });
  }

  void _commitQuickCash() {
    _debounceTimer?.cancel();
    final clean = _quickCashController.text.trim();
    if (clean.isEmpty) {
      widget.onDirectTotalChanged(0.0);
      return;
    }
    final parsed = double.tryParse(clean);
    if (parsed != null && parsed >= 0) {
      widget.onDirectTotalChanged(parsed);
    }
  }

  @override
  void didUpdateWidget(covariant DenominationCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never override while user is actively focused on typing!
    if (!_quickCashFocus.hasFocus && widget.currentTotal != oldWidget.currentTotal && !_isDenominationMode) {
      _quickCashController.text = widget.currentTotal > 0 ? widget.currentTotal.toStringAsFixed(2) : '';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _quickCashFocus.dispose();
    _quickCashController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  void _incrementNote(int note, int delta) {
    final current = _denomination.noteCounts[note] ?? 0;
    final next = (current + delta).clamp(0, 99999);
    final newNotes = Map<int, int>.from(_denomination.noteCounts);
    newNotes[note] = next;

    final updated = _denomination.copyWith(noteCounts: newNotes);
    setState(() {
      _denomination = updated;
      _quickCashController.text = updated.total.toStringAsFixed(2);
    });
    widget.onDenominationChanged(updated);
  }

  void _setNoteCount(int note, int count) {
    final newNotes = Map<int, int>.from(_denomination.noteCounts);
    newNotes[note] = count.clamp(0, 99999);

    final updated = _denomination.copyWith(noteCounts: newNotes);
    setState(() {
      _denomination = updated;
      _quickCashController.text = updated.total.toStringAsFixed(2);
    });
    widget.onDenominationChanged(updated);
  }

  void _onCoinsChanged(String val) {
    final coins = double.tryParse(val) ?? 0.0;
    final updated = _denomination.copyWith(coinTotal: coins);
    setState(() {
      _denomination = updated;
      _quickCashController.text = updated.total.toStringAsFixed(2);
    });
    widget.onDenominationChanged(updated);
  }

  void _clearAll() {
    final cleared = CashDenomination();
    setState(() {
      _denomination = cleared;
      _coinsController.clear();
      _quickCashController.text = '0.00';
    });
    widget.onDenominationChanged(cleared);
    widget.onDirectTotalChanged(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAmount = _isDenominationMode
        ? _denomination.total
        : (double.tryParse(_quickCashController.text) ?? 0.0);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title + Mode Toggle + Reset
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF1A73E8), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Count Drawer Cash',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _isDenominationMode ? 'Tallying notes & coins' : 'Manual cash count entry',
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
                // Mode Toggle & Clear Actions
                IconButton(
                  tooltip: 'Clear counts',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _clearAll,
                ),
                const SizedBox(width: 4),
                // Prominent Mode Toggle Button
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: _isDenominationMode
                        ? const Color(0xFF1A73E8).withValues(alpha: 0.18)
                        : (isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4)),
                  ),
                  icon: Icon(
                    _isDenominationMode ? Icons.edit_note_rounded : Icons.calculate_rounded,
                    size: 15,
                    color: const Color(0xFF1A73E8),
                  ),
                  label: Text(
                    _isDenominationMode ? 'Manual' : 'Tally Notes',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _isDenominationMode = !_isDenominationMode;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Total Banner (FittedBox to prevent overflow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161E2E) : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1A73E8).withValues(alpha: 0.4) : const Color(0xFF1A73E8).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Counted Cash',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1967D2),
                          ),
                        ),
                        Text(
                          _isDenominationMode
                              ? '${_denomination.totalNoteCount} notes + coins'
                              : 'Manual drawer count',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'GHS ${_currencyFormatter.format(totalAmount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1A73E8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (!_isDenominationMode) ...[
              // DEFAULT: Single Manual Total Input
              TextField(
                controller: _quickCashController,
                focusNode: _quickCashFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Counted Physical Cash (GHS)',
                  prefixText: 'GHS ',
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2022) : const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => _commitQuickCash(),
                onChanged: (val) {
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 700), _commitQuickCash);
                },
              ),
              const SizedBox(height: 8),

              // Helper Action to switch to Banknote Tally
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF1A73E8)),
                label: const Text(
                  'Or use Banknote Denomination Tally (GHS 200, 100, 50...)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A73E8)),
                ),
                onPressed: () => setState(() => _isDenominationMode = true),
              ),
            ] else ...[
              // TOGGLED: Primary Working Banknotes (100, 50, 20, 10)
              ..._coreNotes.map((note) => _buildNoteRow(note, isDark)),

              // Secondary Banknotes (200, 5, 2, 1) - Expandable
              if (_showAllDenominations)
                ..._secondaryNotes.map((note) => _buildNoteRow(note, isDark)),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    _showAllDenominations ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: const Color(0xFF1A73E8),
                  ),
                  label: Text(
                    _showAllDenominations
                        ? 'Hide rare notes (GHS 200, 5, 2, 1)'
                        : 'Show other notes (GHS 200, 5, 2, 1)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                  ),
                  onPressed: () => setState(() => _showAllDenominations = !_showAllDenominations),
                ),
              ),
              const SizedBox(height: 4),

              // Loose Coins Row
              _buildCoinsRow(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteRow(int note, bool isDark) {
    final count = _denomination.noteCounts[note] ?? 0;
    final subtotal = count * note;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2022) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: count > 0
                ? const Color(0xFF1A73E8).withValues(alpha: 0.4)
                : (isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
          ),
        ),
        child: Row(
          children: [
            // Note badge
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: _getNoteColor(note).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'GHS $note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: _getNoteColor(note),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Stepper controls (- and +)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: count > 0 ? () => _incrementNote(note, -1) : null,
            ),
            InkWell(
              onTap: () => _showCountInputDialog(note, count),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF1A73E8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => _incrementNote(note, 1),
            ),

            const SizedBox(width: 4),

            // Subtotal (FittedBox & Align Right to prevent right-edge overflow)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'GHS ${_currencyFormatter.format(subtotal)}',
                    style: TextStyle(
                      fontWeight: count > 0 ? FontWeight.bold : FontWeight.w500,
                      fontSize: 11,
                      color: count > 0
                          ? (isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124))
                          : (isDark ? const Color(0xFF80868B) : const Color(0xFF9AA0A6)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinsRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF5F6368).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Coins',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _coinsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'GHS 0.00 (pesewas/coins)',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              onChanged: _onCoinsChanged,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoteColor(int note) {
    switch (note) {
      case 200:
        return const Color(0xFF8E24AA);
      case 100:
        return const Color(0xFF1A73E8);
      case 50:
        return const Color(0xFFE37400);
      case 20:
        return const Color(0xFF1E8E3E);
      case 10:
        return const Color(0xFF00897B);
      case 5:
        return const Color(0xFFD93025);
      case 2:
        return const Color(0xFF6D4C41);
      case 1:
        return const Color(0xFF5F6368);
      default:
        return const Color(0xFF1A73E8);
    }
  }

  void _showCountInputDialog(int note, int currentCount) {
    final controller = TextEditingController(text: currentCount > 0 ? '$currentCount' : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter GHS $note Note Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Number of GHS $note notes',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              _setNoteCount(note, val);
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
