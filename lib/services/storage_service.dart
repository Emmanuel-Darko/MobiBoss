import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mobiboss_models.dart';

class StorageService {
  static const String _keyTransactions = 'momo_transactions';
  static const String _keyTills = 'momo_tills';
  static const String _keyDrawerCash = 'momo_drawer_cash';
  static const String _keyLastReconciliation = 'momo_last_reconciliation';
  static const String _keyDailyCommissionTarget = 'momo_daily_commission_target';
  static const String _keyMonthlyCommissionTarget = 'momo_monthly_commission_target';
  static const String _keyShiftHistory = 'momo_shift_history';
  static const String _keyCustomerContacts = 'momo_customer_contacts';
  static const String _keyCommissionSettings = 'momo_commission_settings';
  static const String _keyBalancePrivacy = 'momo_balance_privacy';
  static const String _keyAppLock = 'momo_app_lock';
  static const String _keyThemeMode = 'momo_theme_mode';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── Theme Mode (light, dark, system) ───
  static Future<void> saveThemeMode(String mode) async {
    await init();
    await _prefs?.setString(_keyThemeMode, mode);
  }

  static Future<String> loadThemeMode() async {
    await init();
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  // ─── Transactions ───
  static Future<void> saveTransactions(List<TransactionRecord> list) async {
    await init();
    final jsonStringList = list.map((tx) => jsonEncode(tx.toJson())).toList();
    await _prefs?.setStringList(_keyTransactions, jsonStringList);
  }

  static Future<List<TransactionRecord>> loadTransactions() async {
    await init();
    final stringList = _prefs?.getStringList(_keyTransactions) ?? [];
    return stringList.map((str) {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return TransactionRecord.fromJson(map);
    }).toList();
  }

  // ─── Tills ───
  static Future<void> saveTills(List<Till> tills) async {
    await init();
    final jsonStringList = tills.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs?.setStringList(_keyTills, jsonStringList);
  }

  static Future<List<Till>?> loadTills() async {
    await init();
    final stringList = _prefs?.getStringList(_keyTills);
    if (stringList == null || stringList.isEmpty) return null;
    return stringList.map((str) {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return Till.fromJson(map);
    }).toList();
  }

  // ─── Drawer Cash ───
  static Future<void> saveDrawerCash(double cash) async {
    await init();
    await _prefs?.setDouble(_keyDrawerCash, cash);
  }

  static Future<double?> loadDrawerCash() async {
    await init();
    return _prefs?.getDouble(_keyDrawerCash);
  }

  // ─── Last Reconciliation ───
  static Future<void> saveLastReconciliation(ReconciliationResult? result) async {
    await init();
    if (result == null) {
      await _prefs?.remove(_keyLastReconciliation);
    } else {
      await _prefs?.setString(_keyLastReconciliation, jsonEncode(result.toJson()));
    }
  }

  static Future<ReconciliationResult?> loadLastReconciliation() async {
    await init();
    final str = _prefs?.getString(_keyLastReconciliation);
    if (str == null) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return ReconciliationResult.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ─── Shift History Archive ───
  static Future<void> saveShiftHistory(List<ShiftRecord> shifts) async {
    await init();
    final jsonList = shifts.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs?.setStringList(_keyShiftHistory, jsonList);
  }

  static Future<List<ShiftRecord>> loadShiftHistory() async {
    await init();
    final stringList = _prefs?.getStringList(_keyShiftHistory) ?? [];
    return stringList.map((str) {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return ShiftRecord.fromJson(map);
    }).toList();
  }

  // ─── Customer Contacts ───
  static Future<void> saveCustomerContacts(List<CustomerContact> contacts) async {
    await init();
    final jsonList = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs?.setStringList(_keyCustomerContacts, jsonList);
  }

  static Future<List<CustomerContact>> loadCustomerContacts() async {
    await init();
    final stringList = _prefs?.getStringList(_keyCustomerContacts) ?? [];
    return stringList.map((str) {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return CustomerContact.fromJson(map);
    }).toList();
  }

  // ─── Commission Settings ───
  static Future<void> saveCommissionSettings(CommissionSettings settings) async {
    await init();
    await _prefs?.setString(_keyCommissionSettings, jsonEncode(settings.toJson()));
  }

  static Future<CommissionSettings> loadCommissionSettings() async {
    await init();
    final str = _prefs?.getString(_keyCommissionSettings);
    if (str == null) return CommissionSettings();
    try {
      return CommissionSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return CommissionSettings();
    }
  }

  // ─── Commission Targets ───
  static Future<void> saveDailyTarget(double target) async {
    await init();
    await _prefs?.setDouble(_keyDailyCommissionTarget, target);
  }

  static Future<double> loadDailyTarget() async {
    await init();
    return _prefs?.getDouble(_keyDailyCommissionTarget) ?? 150.0;
  }

  static Future<void> saveMonthlyTarget(double target) async {
    await init();
    await _prefs?.setDouble(_keyMonthlyCommissionTarget, target);
  }

  static Future<double> loadMonthlyTarget() async {
    await init();
    return _prefs?.getDouble(_keyMonthlyCommissionTarget) ?? 4500.0;
  }

  // ─── Privacy & Security Settings ───
  static Future<void> saveBalancePrivacy(bool enabled) async {
    await init();
    await _prefs?.setBool(_keyBalancePrivacy, enabled);
  }

  static Future<bool> loadBalancePrivacy() async {
    await init();
    return _prefs?.getBool(_keyBalancePrivacy) ?? false;
  }

  static Future<void> saveAppLock(bool enabled) async {
    await init();
    await _prefs?.setBool(_keyAppLock, enabled);
  }

  static Future<bool> loadAppLock() async {
    await init();
    return _prefs?.getBool(_keyAppLock) ?? false;
  }

  // ─── Clear All Storage (For Reset) ───
  static Future<void> clearAll() async {
    await init();
    await _prefs?.clear();
  }
}
