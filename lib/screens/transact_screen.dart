import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/mobiboss_provider.dart';
import '../models/mobiboss_models.dart';
import '../services/ussd_service.dart';
import '../widgets/top_toast.dart';
import '../services/phone_helper.dart';

class TransactScreen extends StatefulWidget {
  const TransactScreen({super.key});

  @override
  State<TransactScreen> createState() => _TransactScreenState();
}

class _TransactScreenState extends State<TransactScreen> with WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isPortedNumber = false;
  bool _recordOnlyMode = false; // false = ⚡ Auto-USSD, true = 📝 Record Only

  final List<double> _quickAmounts = [10, 20, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<MoMoProvider>();
      provider.checkAccessibilityState();
      provider.checkRecentCarrierSms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearFields() {
    setState(() {
      _phoneController.clear();
      _amountController.clear();
      _isPortedNumber = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final activeTill = provider.selectedTill;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rawPhone = _phoneController.text.trim();
    final normalizedPhone = PhoneHelper.normalize(rawPhone);
    final detectedNet = rawPhone.length >= 3 ? PhoneHelper.detectNetwork(normalizedPhone) : null;

    // Search contact name if available
    final matchedContact = provider.customerContacts.where((c) => PhoneHelper.normalize(c.phone) == normalizedPhone).firstOrNull;

    // Real-time recurring customer suggestions (matching phone or name)
    final suggestions = (rawPhone.length >= 2)
        ? provider.customerContacts.where((c) {
            final q = rawPhone.toLowerCase();
            final normC = PhoneHelper.normalize(c.phone);
            return (normC.contains(q) || c.name.toLowerCase().contains(q)) && normC != normalizedPhone;
          }).take(3).toList()
        : <CustomerContact>[];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── 1. Top Quick Bar: Active Till Pill + Mode Switch ───
              _buildTopQuickBar(provider, activeTill, isDark),
              const SizedBox(height: 10),

              // ─── Accessibility Warning Banner (if disabled) ───
              if (!provider.isAccessibilityEnabled && !_recordOnlyMode) ...[
                _buildAccessibilityBanner(isDark),
                const SizedBox(height: 10),
              ],

              // ─── 2. Unified Hero Input Card ───
              _buildUnifiedInputHero(provider, activeTill, detectedNet, matchedContact, suggestions, isDark),
              const SizedBox(height: 12),

              // ─── 3. Direct 1-Tap Action Grid ───
              _buildActionGrid(provider, activeTill, isDark),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopQuickBar(MoMoProvider provider, Till activeTill, bool isDark) {
    return Row(
      children: [
        // Active Till Selector Pill
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
              ),
            ),
            child: Row(
              children: [
                _getNetworkLogo(activeTill.network, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${activeTill.tillName} (${activeTill.simSlot})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Float: GHS ${provider.formatAmount(activeTill.currentFloat)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1E8E3E), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: activeTill.id,
                  isDense: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: provider.tills.map((t) {
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text(t.network.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) provider.selectTill(val);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Mode Toggle Chip: ⚡ Auto-USSD vs 📝 Record Only
        InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            setState(() => _recordOnlyMode = !_recordOnlyMode);
            TopToast.show(
              context,
              title: _recordOnlyMode ? 'Mode: Record Only' : 'Mode: ⚡ Auto-USSD',
              message: _recordOnlyMode
                  ? 'Transactions will be logged directly without USSD dialing.'
                  : 'Transactions will auto-navigate carrier USSD up to PIN prompt.',
              icon: _recordOnlyMode ? Icons.edit_note_rounded : Icons.bolt_rounded,
              backgroundColor: _recordOnlyMode ? const Color(0xFF1A73E8) : const Color(0xFF1E8E3E),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8.5),
            decoration: BoxDecoration(
              color: _recordOnlyMode
                  ? (isDark ? const Color(0xFF1A2B4C) : const Color(0xFFE8F0FE))
                  : (isDark ? const Color(0xFF0F3818) : const Color(0xFFE6F4EA)),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: _recordOnlyMode ? const Color(0xFF1A73E8) : const Color(0xFF1E8E3E),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _recordOnlyMode ? Icons.edit_note_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: _recordOnlyMode ? const Color(0xFF1A73E8) : const Color(0xFF1E8E3E),
                ),
                const SizedBox(width: 4),
                Text(
                  _recordOnlyMode ? 'Record' : '⚡ Auto',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _recordOnlyMode ? const Color(0xFF1A73E8) : const Color(0xFF1E8E3E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilityBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF332600) : const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF7A5900) : const Color(0xFFF9AB00)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFE37400), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Enable Auto-USSD in Accessibility Settings for 1-tap dialing.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => UssdService.openAccessibilitySettings(),
            child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedInputHero(
    MoMoProvider provider,
    Till activeTill,
    NetworkProvider? detectedNet,
    CustomerContact? matchedContact,
    List<CustomerContact> suggestions,
    bool isDark,
  ) {
    final hasPhone = _phoneController.text.isNotEmpty;
    final hasAmount = _amountController.text.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Phone Number Header Row ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHONE NUMBER / ACCOUNT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5F6368), letterSpacing: 0.5),
                ),
                if (hasPhone || hasAmount)
                  InkWell(
                    onTap: _clearFields,
                    child: const Text(
                      'Clear Fields ✕',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD93025), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // ─── Phone Number Input Field with Styled Paste & Directory Icons ───
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                hintText: '024 412 3456',
                hintStyle: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.normal,
                  color: isDark ? const Color(0xFF5F6368) : const Color(0xFFBDC1C6),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: _getNetworkLogo(detectedNet ?? activeTill.network, size: 23),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40, maxHeight: 23),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Styled compact paste icon
                    Container(
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 16.5, color: Color(0xFF1A73E8)),
                        tooltip: 'Paste Phone Number',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && data!.text!.isNotEmpty) {
                            final clean = data.text!.replaceAll(RegExp(r'[^0-9+]'), '').trim();
                            setState(() {
                              _phoneController.text = clean;
                            });
                            if (!_isPortedNumber && clean.length >= 3) {
                              final norm = PhoneHelper.normalize(clean);
                              final net = PhoneHelper.detectNetwork(norm);
                              if (net != null) {
                                final matching = provider.tills.where((t) => t.network == net);
                                if (matching.isNotEmpty) provider.selectTill(matching.first.id);
                              }
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 3),
                    // Customer directory icon
                    IconButton(
                      icon: const Icon(Icons.contacts_rounded, size: 19.5, color: Color(0xFF5F6368)),
                      tooltip: 'Customer Contacts Directory',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showCustomerDirectoryModal(context, provider),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2022) : const Color(0xFFFAFAFA),
              ),
              onChanged: (val) {
                setState(() {});
                if (!_isPortedNumber && val.length >= 3) {
                  final norm = PhoneHelper.normalize(val);
                  final net = PhoneHelper.detectNetwork(norm);
                  if (net != null) {
                    final matching = provider.tills.where((t) => t.network == net);
                    if (matching.isNotEmpty && matching.first.id != activeTill.id) {
                      provider.selectTill(matching.first.id);
                    }
                  }
                }
              },
            ),

            // ─── Real-time Autocomplete Suggestions (Matching Past Customers) ───
            if (suggestions.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: suggestions.map((c) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        setState(() {
                          _phoneController.text = c.phone;
                        });
                        final norm = PhoneHelper.normalize(c.phone);
                        final net = PhoneHelper.detectNetwork(norm);
                        if (net != null) {
                          final matching = provider.tills.where((t) => t.network == net);
                          if (matching.isNotEmpty) provider.selectTill(matching.first.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        child: Row(
                          children: [
                            _getNetworkLogo(c.network, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${c.name} • ${c.phone}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${c.totalTransactions} txs',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF1A73E8), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ─── Phone Sub-bar: Contact Name & Ported Checkbox ───
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 3, left: 2, right: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: matchedContact != null
                        ? Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 14.5, color: Color(0xFF1E8E3E)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${matchedContact.name} (${matchedContact.totalTransactions} past txs)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E8E3E)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            detectedNet != null
                                ? 'Carrier: ${detectedNet.name.toUpperCase()}'
                                : 'Enter customer mobile number',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isPortedNumber = !_isPortedNumber),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: _isPortedNumber
                            ? (isDark ? const Color(0xFF332600) : const Color(0xFFFEF7E0))
                            : (isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4)),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: _isPortedNumber
                              ? const Color(0xFFF9AB00)
                              : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: Checkbox(
                              value: _isPortedNumber,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) => setState(() => _isPortedNumber = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('Ported SIM?', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 18, thickness: 1),

            // ─── Amount Field ───
            const Text(
              'AMOUNT (GHS)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5F6368), letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF1A73E8)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10.5),
                prefixText: 'GHS ',
                prefixStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF5F6368)),
                hintText: '0.00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2022) : const Color(0xFFFAFAFA),
                suffixIcon: hasAmount
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _amountController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // Quick Amount Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickAmounts.map((amt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ActionChip(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      label: Text('+${amt.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final current = double.tryParse(_amountController.text) ?? 0;
                        setState(() {
                          _amountController.text = (current + amt).toStringAsFixed(0);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(MoMoProvider provider, Till activeTill, bool isDark) {
    final livePhone = _phoneController.text.trim();
    final liveAmount = double.tryParse(_amountController.text.replaceAll(',', '').replaceAll(' ', '')) ?? 0.0;

    return Column(
      children: [
        // ─── Hero Row 1: Cash In & Cash Out (Primary 1-Tap) ───
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'CASH IN',
                subtitle: 'MoMo Deposit (3,1)',
                icon: Icons.arrow_downward_rounded,
                primaryColor: const Color(0xFF1E8E3E),
                onTap: () => _executeCoreTransaction(
                  provider: provider,
                  till: activeTill,
                  type: TransactionType.cashIn,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _buildActionButton(
                label: 'CASH OUT',
                subtitle: 'Withdrawal (2,1)',
                icon: Icons.arrow_upward_rounded,
                primaryColor: const Color(0xFFD93025),
                onTap: () => _executeCoreTransaction(
                  provider: provider,
                  till: activeTill,
                  type: TransactionType.cashOut,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        // ─── Row 2: Airtime & Data Bundles ───
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                label: 'AIRTIME',
                subtitle: 'Top-Up (3%)',
                icon: Icons.phone_forwarded_rounded,
                color: const Color(0xFF1A73E8),
                isDark: isDark,
                onTap: () => _executeCoreTransaction(
                  provider: provider,
                  till: activeTill,
                  type: TransactionType.airtime,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _buildSecondaryButton(
                label: 'DATA BUNDLE',
                subtitle: 'Packages (4%)',
                icon: Icons.wifi_rounded,
                color: const Color(0xFF8E24AA),
                isDark: isDark,
                onTap: () => _showDataBundleSheet(provider, activeTill, livePhone),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        // ─── Row 3: Utilities & Bank Transfer ───
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                label: 'ECG / WATER',
                subtitle: 'Utility Bills',
                icon: Icons.flash_on_rounded,
                color: const Color(0xFFE37400),
                isDark: isDark,
                onTap: () => _showUtilityBillSheet(provider, activeTill, livePhone, liveAmount),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _buildSecondaryButton(
                label: 'BANK TRANSFER',
                subtitle: 'GhIPSS Direct',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF0D652D),
                isDark: isDark,
                onTap: () => _showBankTransferSheet(provider, activeTill, livePhone, liveAmount),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        // ─── Row 4: Quick Carrier Inquiries (Commissions & Balance) ───
        Row(
          children: [
            Expanded(
              child: _buildInquiryButton(
                label: 'COMMISSIONS (7,2)',
                icon: Icons.monetization_on_rounded,
                isDark: isDark,
                onTap: () => _executeUssdInquiry(
                  till: activeTill,
                  plan: UssdService.buildCheckCommissionsPlan(activeTill),
                  title: 'Checking Carrier Commissions',
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _buildInquiryButton(
                label: 'CHECK BALANCE (7,1)',
                icon: Icons.account_balance_wallet_rounded,
                isDark: isDark,
                onTap: () => _executeUssdInquiry(
                  till: activeTill,
                  plan: UssdService.buildCheckBalancePlan(activeTill),
                  title: 'Checking Till Float Balance',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        elevation: 2,
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 23),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
        side: BorderSide(color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: Icon(icon, size: 15.5, color: const Color(0xFF5F6368)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE8EAED) : const Color(0xFF3C4043),
        ),
      ),
      onPressed: onTap,
    );
  }

  // ─── Transaction Execution Handler ───
  Future<void> _executeCoreTransaction({
    required MoMoProvider provider,
    required Till till,
    required TransactionType type,
    double? amount,
    String? phone,
  }) async {
    // Read live values directly from controllers, cleaning spaces, hyphens, and commas
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    final cleanAmountStr = _amountController.text.replaceAll(',', '').replaceAll(' ', '').trim();
    final parsedAmount = (amount != null && amount > 0) ? amount : (double.tryParse(cleanAmountStr) ?? 0.0);
    final targetPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim().replaceAll(RegExp(r'[^0-9+]'), '')
        : rawPhone;

    if (targetPhone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid customer phone number (at least 9 digits)'),
          backgroundColor: Color(0xFFD93025),
        ),
      );
      return;
    }

    if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than GHS 0.00'),
          backgroundColor: Color(0xFFD93025),
        ),
      );
      return;
    }

    if (_recordOnlyMode) {
      _showDirectRecordModal(context, provider, till, parsedAmount, targetPhone, type);
      return;
    }

    // Live USSD Execution: If accessibility is not enabled, offer immediate actionable options instead of blocking
    if (!provider.isAccessibilityEnabled) {
      _showAccessibilityOptionsSheet(
        context: context,
        provider: provider,
        till: till,
        type: type,
        amount: parsedAmount,
        phone: targetPhone,
      );
      return;
    }

    final plan = UssdService.buildMultiStepPlan(
      till: till,
      type: type,
      customerPhone: targetPhone,
      amount: parsedAmount,
    );

    await provider.recordPendingUssdTransaction(
      till: till,
      type: type,
      amount: parsedAmount,
      customerPhone: targetPhone,
      ussdCode: plan.rootCode,
    );

    if (mounted) {
      TopToast.show(
        context,
        title: 'USSD Session Started',
        message: 'Auto-navigating ${plan.steps.length} steps on ${till.network.name.toUpperCase()}... Pause at PIN.',
        icon: Icons.bolt_rounded,
        backgroundColor: const Color(0xFF1A73E8),
      );
    }

    final success = await UssdService.initiateAutomatedSession(
      till: till,
      type: type,
      customerPhone: targetPhone,
      amount: parsedAmount,
    );

    if (success) {
      _clearFields();
    } else {
      if (mounted) {
        TopToast.show(
          context,
          title: 'Dialing Unsuccessful',
          message: 'Unable to start USSD dialer. Please check phone permissions or switch to Record Only mode.',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFD93025),
        );
      }
    }
  }

  Future<void> _executeUssdInquiry({
    required Till till,
    required MultiStepUssdPlan plan,
    required String title,
  }) async {
    TopToast.show(
      context,
      title: title,
      message: 'Dialing ${plan.rootCode} on ${till.network.name.toUpperCase()}...',
      icon: Icons.phone_in_talk_rounded,
      backgroundColor: const Color(0xFF1A73E8),
    );

    await UssdService.initiateCustomAutomatedSession(
      rootCode: plan.rootCode,
      steps: plan.steps,
      fallbackShortCode: plan.displayShortCode,
      simSlot: till.simSlot.contains('2') ? 1 : 0,
    );
  }

  // ─── Fast Contextual Bottom Sheets for Complex Services ───

  void _showDataBundleSheet(MoMoProvider provider, Till till, String phone) {
    final phoneCtrl = TextEditingController(text: phone);
    String selectedTier = '1';
    final tiers = [
      {'val': '1', 'name': 'Daily 350MB', 'price': '3.00'},
      {'val': '2', 'name': 'Weekly 1.5GB', 'price': '12.00'},
      {'val': '3', 'name': 'Weekly 3.5GB', 'price': '25.00'},
      {'val': '4', 'name': 'Monthly 10GB', 'price': '60.00'},
      {'val': '5', 'name': 'Monthly 25GB', 'price': '120.00'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Color(0xFF8E24AA)),
                  SizedBox(width: 8),
                  Text('Buy Data Bundle (4% Commission)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Phone Number',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Select Data Package:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...tiers.map((t) {
                final isSelected = selectedTier == t['val'];
                return Card(
                  color: isSelected ? const Color(0xFF8E24AA).withValues(alpha: 0.1) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF8E24AA) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    trailing: Text('GHS ${t['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF8E24AA))),
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? const Color(0xFF8E24AA) : Colors.grey,
                    ),
                    onTap: () => setModalState(() => selectedTier = t['val']!),
                  ),
                );
              }),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final targetPhone = phoneCtrl.text.trim();
                  if (targetPhone.length < 9) return;
                  Navigator.pop(ctx);

                  final plan = UssdService.buildServicePlan(
                    till: till,
                    type: TransactionType.dataBundle,
                    targetAccountOrPhone: targetPhone,
                    amount: double.tryParse(tiers.firstWhere((t) => t['val'] == selectedTier)['price']!) ?? 10,
                    extraParameter: selectedTier,
                  );

                  await UssdService.initiateCustomAutomatedSession(
                    rootCode: plan.rootCode,
                    steps: plan.steps,
                    fallbackShortCode: plan.displayShortCode,
                    simSlot: till.simSlot.contains('2') ? 1 : 0,
                  );
                },
                child: const Text('Execute Bundle Purchase (⚡ USSD)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUtilityBillSheet(MoMoProvider provider, Till till, String phone, double amount) {
    final meterCtrl = TextEditingController(text: phone);
    final amtCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : '');
    TransactionType selectedType = TransactionType.ecgElectricity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: Color(0xFFE37400)),
                  SizedBox(width: 8),
                  Text('Utility Bill Payment (ECG & Water)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.ecgElectricity, label: Text('ECG Electricity')),
                  ButtonSegment(value: TransactionType.ghanaWater, label: Text('Ghana Water')),
                ],
                selected: {selectedType},
                onSelectionChanged: (s) => setModalState(() => selectedType = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: meterCtrl,
                decoration: InputDecoration(
                  labelText: selectedType == TransactionType.ecgElectricity ? 'ECG Meter / Account Number' : 'Water Account Number',
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (GHS)',
                  prefixText: 'GHS ',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE37400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final target = meterCtrl.text.trim();
                  final amt = double.tryParse(amtCtrl.text) ?? 0;
                  if (target.isEmpty || amt <= 0) return;
                  Navigator.pop(ctx);

                  final plan = UssdService.buildServicePlan(
                    till: till,
                    type: selectedType,
                    targetAccountOrPhone: target,
                    amount: amt,
                  );

                  await UssdService.initiateCustomAutomatedSession(
                    rootCode: plan.rootCode,
                    steps: plan.steps,
                    fallbackShortCode: plan.displayShortCode,
                    simSlot: till.simSlot.contains('2') ? 1 : 0,
                  );
                },
                child: const Text('Pay Bill via USSD ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBankTransferSheet(MoMoProvider provider, Till till, String phone, double amount) {
    final accCtrl = TextEditingController(text: phone);
    final amtCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : '');
    String selectedBank = '1'; // GCB
    final banks = [
      {'val': '1', 'name': 'GCB Bank Ltd'},
      {'val': '2', 'name': 'Ecobank Ghana'},
      {'val': '3', 'name': 'Fidelity Bank'},
      {'val': '4', 'name': 'Stanbic Bank'},
      {'val': '5', 'name': 'Absa Bank'},
      {'val': '6', 'name': 'Zenith Bank'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: Color(0xFF0D652D)),
                  SizedBox(width: 8),
                  Text('Direct Bank Transfer (GhIPSS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedBank,
                decoration: const InputDecoration(labelText: 'Beneficiary Bank', prefixIcon: Icon(Icons.account_balance_rounded)),
                items: banks.map((b) => DropdownMenuItem(value: b['val'], child: Text(b['name']!))).toList(),
                onChanged: (v) => setModalState(() => selectedBank = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Beneficiary Account Number', prefixIcon: Icon(Icons.tag_rounded)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Deposit Amount (GHS)', prefixText: 'GHS ', prefixIcon: Icon(Icons.payments_rounded)),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D652D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final target = accCtrl.text.trim();
                  final amt = double.tryParse(amtCtrl.text) ?? 0;
                  if (target.isEmpty || amt <= 0) return;
                  Navigator.pop(ctx);

                  final plan = UssdService.buildServicePlan(
                    till: till,
                    type: TransactionType.bankTransfer,
                    targetAccountOrPhone: target,
                    amount: amt,
                    extraParameter: selectedBank,
                  );

                  await UssdService.initiateCustomAutomatedSession(
                    rootCode: plan.rootCode,
                    steps: plan.steps,
                    fallbackShortCode: plan.displayShortCode,
                    simSlot: till.simSlot.contains('2') ? 1 : 0,
                  );
                },
                child: const Text('Execute Bank Deposit ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDirectRecordModal(
    BuildContext context,
    MoMoProvider provider,
    Till till,
    double amount,
    String phone,
    TransactionType type,
  ) {
    final refCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF1A73E8), size: 22),
            SizedBox(width: 8),
            Text('Confirm Direct Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record transaction directly into ledger without dialing USSD. '
              'Used when transacting on a secondary button phone or manual POS.',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Type:', style: TextStyle(fontSize: 12)),
                      Text(
                        type == TransactionType.cashIn ? 'Cash In (Deposit)' : type == TransactionType.cashOut ? 'Cash Out (Withdraw)' : 'Airtime',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Customer:', style: TextStyle(fontSize: 12)),
                      Text(phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount:', style: TextStyle(fontSize: 12)),
                      Text(
                        'GHS ${provider.formatAmount(amount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A73E8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Till / SIM:', style: TextStyle(fontSize: 12)),
                      Text('${till.tillName} (${till.network.name.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'Telco Reference (Optional)',
                hintText: 'e.g. 24891823901',
                prefixIcon: Icon(Icons.tag_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final tx = await provider.recordDirectTransaction(
                till: till,
                type: type,
                amount: amount,
                customerPhone: phone,
                reference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
              );

              _clearFields();

              if (context.mounted) {
                TopToast.show(
                  context,
                  title: 'Transaction Recorded (Manual)',
                  message: '${tx.type.name.toUpperCase()} GHS ${provider.formatAmount(tx.amount)} logged as Direct Entry.',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFF1E8E3E),
                );
              }
            },
            child: const Text('Save to Ledger'),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityOptionsSheet({
    required BuildContext context,
    required MoMoProvider provider,
    required Till till,
    required TransactionType type,
    required double amount,
    required String phone,
  }) {
    final typeName = type == TransactionType.cashIn
        ? 'Cash In (Deposit)'
        : type == TransactionType.cashOut
            ? 'Cash Out (Withdraw)'
            : 'Airtime';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                    color: Theme.of(ctx).dividerColor.withValues(alpha: 0.4),
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
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1A73E8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$typeName — GHS ${provider.formatAmount(amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Customer: $phone • ${till.network.name.toUpperCase()}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Option 1: Record Directly to Ledger
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF1E8E3E), width: 1.5),
                ),
                tileColor: const Color(0xFF1E8E3E).withValues(alpha: 0.08),
                leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E8E3E), size: 28),
                title: const Text('Record to Ledger Directly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Save transaction now, adjust drawer float, and skip USSD dialing', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1E8E3E)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDirectRecordModal(context, provider, till, amount, phone, type);
                },
              ),
              const SizedBox(height: 10),
              // Option 2: Direct USSD Dial
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                ),
                leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1A73E8), size: 26),
                title: const Text('Dial USSD on Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Open phone dialer with ${till.network == NetworkProvider.mtn ? "*171#" : "*110#"}', style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  final plan = UssdService.buildMultiStepPlan(till: till, type: type, customerPhone: phone, amount: amount);
                  await UssdService.dialUssd(plan.displayShortCode);
                },
              ),
              const SizedBox(height: 10),
              // Option 3: Enable Auto-USSD in Accessibility Settings
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
                ),
                leading: const Icon(Icons.accessibility_new_rounded, color: Color(0xFFE37400), size: 26),
                title: const Text('Enable Auto-USSD (1-Tap)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Open Android Settings to enable automated menu navigation', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  UssdService.openAccessibilitySettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerDirectoryModal(BuildContext context, MoMoProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: provider.customerContacts.isEmpty
                      ? const Center(
                          child: Text(
                            'No contacts saved yet.\nContacts auto-save from confirmed transactions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5F6368)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.customerContacts.length,
                          itemBuilder: (context, index) {
                            final contact = provider.customerContacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F0FE),
                                child: Text(
                                  contact.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                                ),
                              ),
                              title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${contact.phone} • ${contact.totalTransactions} transactions', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              onTap: () {
                                setState(() {
                                  _phoneController.text = contact.phone;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getNetworkLogo(NetworkProvider net, {double size = 20}) {
    switch (net) {
      case NetworkProvider.mtn:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0xFFFFCC00), shape: BoxShape.circle),
          child: Center(
            child: Text('M', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        );
      case NetworkProvider.telecel:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0xFFE60000), shape: BoxShape.circle),
          child: Center(
            child: Text('T', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        );
      case NetworkProvider.at:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0xFF003399), shape: BoxShape.circle),
          child: Center(
            child: Text('AT', style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        );
      case NetworkProvider.gmoney:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0xFF008080), shape: BoxShape.circle),
          child: Center(
            child: Text('G', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        );
    }
  }
}
