import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/mobiboss_models.dart';
import '../providers/mobiboss_provider.dart';
import '../services/security_service.dart';
import '../services/receipt_service.dart';
import '../widgets/top_toast.dart';
import 'ussd_config_screen.dart';
import 'shift_handover_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedNetworkScope = 'GLOBAL'; // GLOBAL, mtn, telecel, at, gmoney

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final settings = provider.commissionSettings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 1. Hardware & Printing (Top Priority) ───
          Text('1. Hardware & Thermal Printing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: provider.selectedPrinter != null ? const Color(0xFFE6F4EA) : const Color(0xFFE8F0FE),
                    child: Icon(
                      Icons.print_rounded,
                      color: provider.selectedPrinter != null ? const Color(0xFF1E8E3E) : const Color(0xFF1A73E8),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    provider.selectedPrinter?.name ?? 'Bluetooth Thermal Printer',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    provider.selectedPrinter != null
                        ? '${provider.selectedPrinter!.address} (${provider.selectedPrinter!.paperWidthMm}mm ESC/POS)'
                        : 'No printer paired. Tap to scan & pair POS printer.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showBluetoothPrinterModal(context, provider),
                    child: Text(provider.selectedPrinter != null ? 'Change' : 'Scan'),
                  ),
                ),
                if (provider.selectedPrinter != null) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1A73E8)),
                    title: const Text('Auto-Print on Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Automatically trigger 58mm receipt upon SMS confirmation', style: TextStyle(fontSize: 11)),
                    value: provider.autoPrintReceipts,
                    onChanged: (val) => provider.setAutoPrint(val),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: const Text('Test Print Slip'),
                            onPressed: () async {
                              final mockTill = provider.tills.first;
                              final mockTx = TransactionRecord(
                                id: 'test_print',
                                tillId: mockTill.id,
                                network: mockTill.network,
                                type: TransactionType.cashIn,
                                amount: 100.0,
                                fee: 0.0,
                                commission: 0.5,
                                customerPhone: '0244000111',
                                reference: 'TEST-ESC-POS',
                                ussdString: 'TEST',
                                timestamp: DateTime.now(),
                                status: TransactionStatus.completed,
                              );
                              final bytes = ReceiptService.buildEscPosTransactionReceipt(tx: mockTx, till: mockTill);
                              final success = await ReceiptService.printRawBytes(
                                printerAddress: provider.selectedPrinter!.address,
                                bytes: bytes,
                              );
                              if (context.mounted) {
                                if (success) {
                                  TopToast.show(context, title: 'Printer Test OK', message: 'Test slip sent to ${provider.selectedPrinter!.name}', icon: Icons.check_circle_rounded, backgroundColor: const Color(0xFF1E8E3E));
                                } else {
                                  TopToast.show(context, title: 'Print Failed', message: 'Could not connect to printer. Ensure it is powered on.', icon: Icons.error_outline_rounded, backgroundColor: Colors.red);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── 2. Staff & Shift Management (High Priority) ───
          Text('2. Staff & Shift Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FE),
                    child: Icon(Icons.badge_rounded, color: Color(0xFF1A73E8), size: 20),
                  ),
                  title: Text('Active Teller: ${provider.activeTeller?.name ?? "Primary"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Role: ${provider.activeTeller?.role.name.toUpperCase()} • ${provider.tellers.length} registered attendants', style: const TextStyle(fontSize: 11)),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftHandoverScreen()));
                    },
                    child: const Text('Handover'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add_rounded, color: Color(0xFF1A73E8), size: 20),
                  title: const Text('Add New Shop Attendant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.add_rounded, color: Color(0xFF1A73E8)),
                  onTap: () => _showAddTellerDialog(context, provider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── 3. Multi-SIM Tills & Float Balances (High Priority) ───
          Text('3. Multi-SIM Tills & Floats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ...provider.tills.map((till) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: till.network == NetworkProvider.mtn
                          ? const Color(0xFFFFF4CC)
                          : const Color(0xFFFFEBEE),
                      child: Icon(
                        Icons.sim_card_rounded,
                        color: till.network == NetworkProvider.mtn
                            ? const Color(0xFFF9AB00)
                            : Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(till.tillName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Float: GHS ${provider.formatAmount(till.currentFloat)} • ${till.simSlot} • Prefix ${till.ussdPrefix}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact),
                      onPressed: () => _showEditTillDialog(context, provider, till),
                      child: const Text('Edit Float', style: TextStyle(fontSize: 11)),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── 4. USSD Automation & Carrier Sequences (Automation) ───
          Text('4. USSD Automation & Flows', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF4CC),
                    child: Icon(Icons.dialpad_rounded, color: Color(0xFFF9AB00), size: 20),
                  ),
                  title: const Text('USSD Flow Configurator', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Customize prompt steps per carrier (${provider.customUssdRules.length} custom rules active)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UssdConfigScreen()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── 5. Security & Privacy Shield ───
          Text('5. Security & Privacy Guard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF1A73E8)),
                  title: const Text('Biometric App Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Require fingerprint or device PIN on open & resume', style: TextStyle(fontSize: 11)),
                  value: provider.isAppLockEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final authenticated = await SecurityService.authenticate(reason: 'Enable Biometric Lock');
                      if (authenticated) {
                        provider.toggleAppLock(true);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Biometric authentication failed or was cancelled.')),
                          );
                        }
                      }
                    } else {
                      provider.toggleAppLock(false);
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_rounded, color: Color(0xFF1A73E8)),
                  title: const Text('Balance Privacy Shield', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Mask float and cash drawer amounts over the counter', style: TextStyle(fontSize: 11)),
                  value: provider.isBalancePrivacyEnabled,
                  onChanged: (_) => provider.toggleBalancePrivacy(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── 6. Commission Rules & Targets ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('6. Commission Rules & Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
              InkWell(
                onTap: () => _showCommissionEditDialog(context, provider, _selectedNetworkScope),
                child: const Text('Edit Rates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scope Switcher Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildScopeChip('GLOBAL', 'All (Default)'),
                const SizedBox(width: 6),
                _buildScopeChip('mtn', 'MTN MoMo'),
                const SizedBox(width: 6),
                _buildScopeChip('telecel', 'Telecel Cash'),
                const SizedBox(width: 6),
                _buildScopeChip('at', 'AT Money'),
                const SizedBox(width: 6),
                _buildScopeChip('gmoney', 'G-Money'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Builder(
                builder: (context) {
                  final netOverride = _selectedNetworkScope != 'GLOBAL'
                      ? settings.networkOverrides[_selectedNetworkScope]
                      : null;

                  final cashIn = netOverride?.cashInRate ?? settings.cashInRate;
                  final cashOut = netOverride?.cashOutRate ?? settings.cashOutRate;
                  final airtime = netOverride?.airtimeRate ?? settings.airtimeRate;
                  final data = netOverride?.dataBundleRate ?? settings.dataBundleRate;

                  return Column(
                    children: [
                      if (netOverride != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1A73E8)),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedNetworkScope.toUpperCase()} Custom Tier Active',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildSettingRow('Cash In (Deposit)', '${(cashIn * 100).toStringAsFixed(2)}%'),
                      _buildSettingRow('Cash Out (Withdrawal)', '${(cashOut * 100).toStringAsFixed(2)}%'),
                      _buildSettingRow('Airtime Top-Up', '${(airtime * 100).toStringAsFixed(2)}%'),
                      _buildSettingRow('Data Bundles', '${(data * 100).toStringAsFixed(2)}%'),
                      _buildSettingRow('ECG & Water Bills', 'GHS ${settings.utilityFlatFee.toStringAsFixed(2)} flat'),
                      _buildSettingRow('Pay TV (DSTV/GOtv)', 'GHS ${settings.payTvFlatFee.toStringAsFixed(2)} flat'),
                      _buildSettingRow('Bank Transfers', '${(settings.bankTransferRate * 100).toStringAsFixed(2)}%'),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ─── 7. Appearance & Theme ───
          Text('7. Appearance & Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Theme Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Choose between light, dark, or system default', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                          label: Text('Light', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                          label: Text('Dark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 16),
                          label: Text('System', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      selected: {provider.themeMode},
                      onSelectionChanged: (set) => provider.setThemeMode(set.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ─── 8. Data & Accounting ───
          Text('8. Data & Accounting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4EA),
                child: Icon(Icons.table_chart_rounded, color: Color(0xFF1E8E3E), size: 20),
              ),
              title: const Text('Export Ledger to CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Export ${provider.transactions.length} transactions for Excel & tax audit', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.file_download_rounded, color: Color(0xFF1E8E3E)),
              onTap: () async {
                final csvData = provider.exportLedgerToCsv();
                final bytes = Uint8List.fromList(csvData.codeUnits);
                await Printing.sharePdf(bytes: bytes, filename: 'MobiBoss_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv');
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String key, String label) {
    final isSelected = _selectedNetworkScope == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF3C4043),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1A73E8),
      onSelected: (_) => setState(() => _selectedNetworkScope = key),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showBluetoothPrinterModal(BuildContext context, MoMoProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<List<BluetoothPrinterInfo>>(
          future: ReceiptService.getPairedPrinters(),
          builder: (context, snapshot) {
            final printers = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paired Bluetooth Printers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                  ] else if (printers.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No paired Bluetooth printers found.\n\nPlease turn on your POS thermal printer, pair it in Android Bluetooth Settings, and return here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                      ),
                    ),
                  ] else ...[
                    ...printers.map((p) {
                      final isSelected = provider.selectedPrinter?.address == p.address;
                      return ListTile(
                        leading: const Icon(Icons.print_rounded, color: Color(0xFF1A73E8)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(p.address, style: const TextStyle(fontSize: 11)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E8E3E))
                            : const Text('Select', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                        onTap: () {
                          provider.setPrinter(p);
                          Navigator.pop(ctx);
                          TopToast.show(
                            context,
                            title: 'Printer Connected',
                            message: 'Default printer set to ${p.name}',
                            icon: Icons.check_circle_rounded,
                            backgroundColor: const Color(0xFF1E8E3E),
                          );
                        },
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTellerDialog(BuildContext context, MoMoProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    TellerRole role = TellerRole.attendant;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Shop Attendant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Attendant Name', hintText: 'e.g. Ama Serwaa'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: '0244123456'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Login / Shift PIN (4 digits)', hintText: '0000'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TellerRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: TellerRole.attendant, child: Text('Attendant')),
                  DropdownMenuItem(value: TellerRole.shiftSupervisor, child: Text('Shift Supervisor')),
                  DropdownMenuItem(value: TellerRole.owner, child: Text('Shop Owner')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => role = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final teller = Teller(
                  id: 'teller_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  pinHash: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : '0000',
                  role: role,
                  isActive: false,
                  createdAt: DateTime.now(),
                );
                await provider.addTeller(teller);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Attendant'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTillDialog(BuildContext context, MoMoProvider provider, Till till) {
    final floatCtrl = TextEditingController(text: till.currentFloat.toStringAsFixed(2));
    final minAlertCtrl = TextEditingController(text: till.minFloatAlert.toStringAsFixed(2));
    final nameCtrl = TextEditingController(text: till.tillName);
    final agentCodeCtrl = TextEditingController(text: till.agentCode);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.sim_card_rounded,
              color: till.network == NetworkProvider.mtn
                  ? const Color(0xFFF9AB00)
                  : till.network == NetworkProvider.telecel
                      ? Colors.red
                      : const Color(0xFF1A73E8),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Edit ${till.tillName}', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Till Name',
                  hintText: 'e.g. MTN Main Till',
                  prefixIcon: Icon(Icons.label_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: floatCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current Float (GHS)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                  prefixText: 'GHS ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minAlertCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Low Float Alert Threshold (GHS)',
                  hintText: '500.00',
                  prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                  prefixText: 'GHS ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: agentCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agent Code',
                  hintText: 'e.g. 12345',
                  prefixIcon: Icon(Icons.badge_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newFloat = double.tryParse(floatCtrl.text) ?? till.currentFloat;
              final newMinAlert = double.tryParse(minAlertCtrl.text) ?? till.minFloatAlert;
              final updated = till.copyWith(
                tillName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                currentFloat: newFloat,
                minFloatAlert: newMinAlert,
                agentCode: agentCodeCtrl.text.trim().isNotEmpty ? agentCodeCtrl.text.trim() : null,
              );
              await provider.updateTill(updated);
              if (context.mounted) {
                Navigator.pop(ctx);
                TopToast.show(
                  context,
                  title: 'Till Updated',
                  message: '${updated.tillName} float set to GHS ${provider.formatAmount(newFloat)}',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFF1E8E3E),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showCommissionEditDialog(BuildContext context, MoMoProvider provider, String scope) {
    final settings = provider.commissionSettings;
    final netOverride = scope != 'GLOBAL' ? settings.networkOverrides[scope] : null;

    final cashInCtrl = TextEditingController(
      text: ((netOverride?.cashInRate ?? settings.cashInRate) * 100).toStringAsFixed(2),
    );
    final cashOutCtrl = TextEditingController(
      text: ((netOverride?.cashOutRate ?? settings.cashOutRate) * 100).toStringAsFixed(2),
    );
    final airtimeCtrl = TextEditingController(
      text: ((netOverride?.airtimeRate ?? settings.airtimeRate) * 100).toStringAsFixed(2),
    );
    final dataCtrl = TextEditingController(
      text: ((netOverride?.dataBundleRate ?? settings.dataBundleRate) * 100).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(scope == 'GLOBAL' ? 'Edit Global Rates' : 'Edit ${scope.toUpperCase()} Rates'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cashInCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cash In Commission (%)', suffixText: '%'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cashOutCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cash Out Commission (%)', suffixText: '%'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: airtimeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Airtime Commission (%)', suffixText: '%'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dataCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Data Bundle Commission (%)', suffixText: '%'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final inRate = (double.tryParse(cashInCtrl.text) ?? 0.5) / 100;
              final outRate = (double.tryParse(cashOutCtrl.text) ?? 1.0) / 100;
              final airRate = (double.tryParse(airtimeCtrl.text) ?? 3.0) / 100;
              final dataRate = (double.tryParse(dataCtrl.text) ?? 4.0) / 100;

              if (scope == 'GLOBAL') {
                final newSettings = CommissionSettings(
                  cashInRate: inRate,
                  cashOutRate: outRate,
                  airtimeRate: airRate,
                  dataBundleRate: dataRate,
                  utilityFlatFee: settings.utilityFlatFee,
                  payTvFlatFee: settings.payTvFlatFee,
                  bankTransferRate: settings.bankTransferRate,
                  networkOverrides: settings.networkOverrides,
                );
                provider.updateCommissionSettings(newSettings);
              } else {
                final updatedOverrides = Map<String, NetworkCommissionOverride>.from(settings.networkOverrides);
                updatedOverrides[scope] = NetworkCommissionOverride(
                  cashInRate: inRate,
                  cashOutRate: outRate,
                  airtimeRate: airRate,
                  dataBundleRate: dataRate,
                );
                final newSettings = CommissionSettings(
                  cashInRate: settings.cashInRate,
                  cashOutRate: settings.cashOutRate,
                  airtimeRate: settings.airtimeRate,
                  dataBundleRate: settings.dataBundleRate,
                  utilityFlatFee: settings.utilityFlatFee,
                  payTvFlatFee: settings.payTvFlatFee,
                  bankTransferRate: settings.bankTransferRate,
                  networkOverrides: updatedOverrides,
                );
                provider.updateCommissionSettings(newSettings);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
