import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../models/momo_models.dart';
import '../providers/momo_provider.dart';
import '../services/security_service.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 1. Appearance & Theme ───
          Text('Appearance & Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Theme Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Choose between light, dark, or system default', style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
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

          // ─── 2. Security & Privacy Card ───
          Text('Security & Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368))),
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

          // ─── 2. Commission Rules (Network Specific & Global) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Commission Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5F6368))),
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

          // ─── 3. Data & Accounting ───
          const Text('Data & Accounting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5F6368))),
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
                await Printing.sharePdf(bytes: bytes, filename: 'MoMo_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv');
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
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF202124))),
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
