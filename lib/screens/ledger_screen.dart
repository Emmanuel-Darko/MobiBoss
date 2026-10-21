import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/mobiboss_provider.dart';
import '../models/mobiboss_models.dart';
import '../services/receipt_service.dart';
import '../widgets/top_toast.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _filterNetwork = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getNetworkColor(NetworkProvider net) {
    switch (net) {
      case NetworkProvider.mtn:
        return const Color(0xFFF9AB00);
      case NetworkProvider.telecel:
        return const Color(0xFFE60000);
      case NetworkProvider.at:
        return const Color(0xFF005696);
      case NetworkProvider.gmoney:
        return const Color(0xFF1E8E3E);
    }
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
      case TransactionType.reversal:
        return const Color(0xFFD93025);
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.cashIn:
        return Icons.arrow_downward_rounded;
      case TransactionType.cashOut:
        return Icons.arrow_upward_rounded;
      case TransactionType.airtime:
        return Icons.phone_android_rounded;
      case TransactionType.dataBundle:
        return Icons.wifi_rounded;
      case TransactionType.floatTransfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.ecgElectricity:
        return Icons.flash_on_rounded;
      case TransactionType.ghanaWater:
        return Icons.water_drop_rounded;
      case TransactionType.payTv:
        return Icons.tv_rounded;
      case TransactionType.bankTransfer:
        return Icons.account_balance_rounded;
      case TransactionType.reversal:
        return Icons.replay_rounded;
    }
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.cashIn:
        return 'Cash In';
      case TransactionType.cashOut:
        return 'Cash Out';
      case TransactionType.airtime:
        return 'Airtime';
      case TransactionType.dataBundle:
        return 'Data Bundle';
      case TransactionType.floatTransfer:
        return 'Float Transfer';
      case TransactionType.ecgElectricity:
        return 'ECG Power';
      case TransactionType.ghanaWater:
        return 'GWCL Water';
      case TransactionType.payTv:
        return 'Pay TV';
      case TransactionType.bankTransfer:
        return 'Bank Transfer';
      case TransactionType.reversal:
        return 'Reversal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final transactions = provider.transactions;

    final filtered = transactions.where((tx) {
      if (_filterNetwork != 'ALL' && tx.network.name.toUpperCase() != _filterNetwork) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchPhone = tx.customerPhone.toLowerCase().contains(query);
        final matchRef = tx.reference.toLowerCase().contains(query);
        final matchAmt = tx.amount.toString().contains(query);
        return matchPhone || matchRef || matchAmt;
      }
      return true;
    }).toList();

    double totalIn = 0;
    double totalOut = 0;
    double totalCommission = 0;

    for (var tx in filtered) {
      if (tx.type == TransactionType.cashIn ||
          tx.type == TransactionType.airtime ||
          tx.type == TransactionType.dataBundle ||
          tx.type == TransactionType.ecgElectricity ||
          tx.type == TransactionType.ghanaWater ||
          tx.type == TransactionType.payTv) {
        totalIn += tx.amount;
      } else if (tx.type == TransactionType.cashOut ||
          tx.type == TransactionType.bankTransfer) {
        totalOut += tx.amount;
      }
      totalCommission += tx.commission;
    }

    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Top Metrics Bar
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Inflow',
                    amount: provider.formatAmount(totalIn),
                    color: isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E),
                    bgColor: isDark ? const Color(0xFF132B1B) : const Color(0xFFE6F4EA),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Outflow',
                    amount: provider.formatAmount(totalOut),
                    color: isDark ? const Color(0xFFF28B82) : const Color(0xFFD93025),
                    bgColor: isDark ? const Color(0xFF331716) : const Color(0xFFFCE8E6),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Commission',
                    amount: provider.formatAmount(totalCommission),
                    color: isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1A73E8),
                    bgColor: isDark ? const Color(0xFF182B42) : const Color(0xFFE8F0FE),
                    icon: Icons.stars_rounded,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),

          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search phone, ref, amount...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Networks'),
                      const SizedBox(width: 8),
                      _buildFilterChip('MTN', 'MTN MoMo'),
                      const SizedBox(width: 8),
                      _buildFilterChip('TELECEL', 'Telecel Cash'),
                      const SizedBox(width: 8),
                      _buildFilterChip('AT', 'AT Money'),
                      const SizedBox(width: 8),
                      _buildFilterChip('GMONEY', 'G-Money'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transactions List with Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final count = await provider.syncRecentSms();
                if (context.mounted) {
                  TopToast.show(
                    context,
                    title: count > 0 ? 'SMS Sync Complete' : 'Ledger Refreshed',
                    message: count > 0
                        ? 'Reconciled $count incoming telecom messages.'
                        : 'Transactions are up to date.',
                    icon: count > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    backgroundColor: count > 0 ? const Color(0xFF1E8E3E) : const Color(0xFF5F6368),
                  );
                }
              },
              child: filtered.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBDC1C6)),
                              SizedBox(height: 12),
                              Text(
                                'No transactions found.\nPull down to sync incoming telco SMS.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF80868B), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                      final tx = filtered[index];
                      final isCashOut = tx.type == TransactionType.cashOut;
                      final typeColor = _getTypeColor(tx.type);
                      final typeIcon = _getTypeIcon(tx.type);
                      final typeLabel = _getTypeLabel(tx.type);
                      final netColor = _getNetworkColor(tx.network);

                      final matchingTill = provider.tills.firstWhere(
                        (t) => t.id == tx.tillId || t.network == tx.network,
                        orElse: () => provider.selectedTill,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showReceiptModal(context, tx, matchingTill),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: typeColor.withValues(alpha: 0.12),
                                  child: Icon(
                                    typeIcon,
                                    size: 18,
                                    color: typeColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              typeLabel,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: netColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tx.network.name.toUpperCase(),
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: netColor),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Builder(builder: (_) {
                                            final bool isManual = tx.ussdString == 'DIRECT_RECORD';
                                            final bool isPending = tx.status == TransactionStatus.pending;
                                            final bool isFailed = tx.status == TransactionStatus.failed;
                                            final Color badgeColor = isManual
                                                ? const Color(0xFFE37400)
                                                : isPending
                                                    ? const Color(0xFF1A73E8)
                                                    : isFailed
                                                        ? const Color(0xFFD93025)
                                                        : const Color(0xFF1E8E3E);
                                            final IconData badgeIcon = isManual
                                                ? Icons.edit_note_rounded
                                                : isPending
                                                    ? Icons.hourglass_top_rounded
                                                    : isFailed
                                                        ? Icons.error_outline_rounded
                                                        : Icons.shield_rounded;
                                            final String badgeText = isManual
                                                ? 'Manual'
                                                : isPending
                                                    ? 'Pending'
                                                    : isFailed
                                                        ? 'Failed'
                                                        : 'Verified';
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(badgeIcon, size: 9, color: badgeColor),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    badgeText,
                                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: badgeColor),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${tx.customerPhone} • ${tx.reference}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        dateFormat.format(tx.timestamp),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF80868B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${isCashOut ? '-' : '+'} ${provider.formatAmount(tx.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isCashOut ? const Color(0xFFD93025) : const Color(0xFF1E8E3E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '+${provider.formatAmount(tx.commission)}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF1A73E8), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF1A73E8)),
                                  tooltip: '1-Tap Thermal Print',
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => ReceiptService.printReceipt(context: context, tx: tx, till: matchingTill),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptModal(BuildContext context, TransactionRecord tx, Till till) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaction Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),

              // Receipt Paper Mock
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED)),
                ),
                child: Column(
                  children: [
                    const Text('MOBIBOSS POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Agent: ${till.agentCode} • ${till.tillName}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                    const Divider(height: 16),
                    _buildReceiptRow('Type', _getTypeLabel(tx.type)),
                    _buildReceiptRow('Customer', tx.customerPhone),
                    _buildReceiptRow('Amount', 'GHS ${MoMoProvider.formatNumber(tx.amount)}', isBold: true),
                    if (tx.fee > 0) _buildReceiptRow('Fee', 'GHS ${MoMoProvider.formatNumber(tx.fee)}'),
                    _buildReceiptRow('Reference ID', tx.reference),
                    _buildReceiptRow('Date & Time', dateFormat.format(tx.timestamp)),
                    _buildReceiptRow(
                      'Status',
                      tx.ussdString == 'DIRECT_RECORD'
                          ? 'MANUAL ENTRY'
                          : tx.status == TransactionStatus.pending
                              ? 'PENDING'
                              : tx.status == TransactionStatus.failed
                                  ? 'FAILED'
                                  : 'CONFIRMED (CARRIER SMS)',
                      valueColor: tx.ussdString == 'DIRECT_RECORD'
                          ? const Color(0xFFE37400)
                          : tx.status == TransactionStatus.pending
                              ? const Color(0xFF1A73E8)
                              : tx.status == TransactionStatus.failed
                                  ? const Color(0xFFD93025)
                                  : (isDark ? const Color(0xFF81C995) : const Color(0xFF1E8E3E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF1E8E3E)),
                      label: const Text('WhatsApp Text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final provider = context.read<MoMoProvider>();
                        final text = provider.buildDigitalReceipt(tx);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          TopToast.show(
                            context,
                            title: 'Receipt Copied',
                            message: 'Receipt text copied to clipboard! Paste into WhatsApp or SMS.',
                            icon: Icons.check_circle_rounded,
                            backgroundColor: const Color(0xFF1E8E3E),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Share PDF', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ReceiptService.shareReceiptPdf(tx: tx, till: till);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ReceiptService.printReceipt(context: context, tx: tx, till: till);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterNetwork == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043)),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1A73E8),
      onSelected: (val) {
        if (val) setState(() => _filterNetwork = key);
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
