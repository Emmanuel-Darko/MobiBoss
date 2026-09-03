import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/momo_provider.dart';
import '../models/momo_models.dart';
import '../services/receipt_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Top Metrics Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Inflow',
                    amount: provider.formatAmount(totalIn),
                    color: const Color(0xFF1E8E3E),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Outflow',
                    amount: provider.formatAmount(totalOut),
                    color: const Color(0xFFD93025),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Commission',
                    amount: provider.formatAmount(totalCommission),
                    color: const Color(0xFF1A73E8),
                    icon: Icons.stars_rounded,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAED)),

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
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EAED)),
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

          // Transactions List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions found.',
                      style: TextStyle(color: Color(0xFF80868B)),
                    ),
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
                          side: const BorderSide(color: Color(0xFFE8EAED)),
                        ),
                        color: Colors.white,
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
                                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFBDC1C6)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showReceiptModal(BuildContext context, TransactionRecord tx, Till till) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

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
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EAED)),
                ),
                child: Column(
                  children: [
                    const Text('MOMO BOSS POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Agent: ${till.agentCode} • ${till.tillName}', style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                    const Divider(height: 16),
                    _buildReceiptRow('Type', _getTypeLabel(tx.type)),
                    _buildReceiptRow('Customer', tx.customerPhone),
                    _buildReceiptRow('Amount', 'GHS ${tx.amount.toStringAsFixed(2)}', isBold: true),
                    if (tx.fee > 0) _buildReceiptRow('Fee', 'GHS ${tx.fee.toStringAsFixed(2)}'),
                    _buildReceiptRow('Reference ID', tx.reference),
                    _buildReceiptRow('Date & Time', dateFormat.format(tx.timestamp)),
                    _buildReceiptRow('Status', 'CONFIRMED', valueColor: const Color(0xFF1E8E3E)),
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
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Receipt'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ReceiptService.shareReceiptPdf(tx: tx, till: till);
                      },
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
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Thermal'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF202124),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterNetwork == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF3C4043),
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
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
