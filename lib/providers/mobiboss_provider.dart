import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/mobiboss_models.dart';
import '../services/db_service.dart';
import '../services/sms_parser_service.dart';
import '../services/storage_service.dart';
import '../services/ussd_service.dart';
import '../services/receipt_service.dart';
import '../services/whatsapp_service.dart';

class MoMoProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final SmsQuery _smsQuery = SmsQuery();
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  double _currentCashInDrawer = 2500.00;
  double _initialDrawerOpeningBalance = 2500.00;
  String _selectedTillId = 'till-mtn-01';
  ReconciliationResult? _lastReconciliation;
  bool _isAccessibilityEnabled = false;

  double _dailyCommissionTarget = 150.0;
  double _monthlyCommissionTarget = 4500.0;

  bool _isBalancePrivacyEnabled = false;
  bool _isAppLockEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;

  CommissionSettings _commissionSettings = CommissionSettings();
  ShopProfile _shopProfile = ShopProfile();
  String? _ownerPin;

  List<Till> _tills = [];
  List<TransactionRecord> _transactions = [];
  final List<SmsRecord> _smsRecords = [];
  List<ShiftRecord> _shiftHistory = [];
  List<CustomerContact> _customerContacts = [];

  // Phase 2 & 3 State
  List<PettyCashExpense> _pettyCashExpenses = [];
  List<Teller> _tellers = [];
  Teller? _activeTeller;
  List<ShiftHandover> _shiftHandovers = [];
  List<CustomUssdRule> _customUssdRules = [];
  BluetoothPrinterInfo? _selectedPrinter;
  bool _autoPrintReceipts = false;

  // Smart sender discovery & Dual-layer SMS storage
  final List<SmsRecord> _allScannedRecords = [];
  final Map<String, SenderInfo> _allDiscoveredSenders = {};
  final Map<String, SenderInfo> _discoveredSenders = {};
  final Set<String> _selectedSenders = {};
  bool _isScanningInbox = false;
  String _reconciliationPeriod = 'shift'; // 'shift', 'today', 'all'
  CashDenomination _cashDenomination = CashDenomination();

  bool _hasCompletedOnboarding = false;

  // Getters
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  double get currentCashInDrawer => _currentCashInDrawer;
  double get initialDrawerOpeningBalance => _initialDrawerOpeningBalance;
  List<Till> get tills => List.unmodifiable(_tills);
  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  List<SmsRecord> get smsRecords => List.unmodifiable(_smsRecords);
  List<ShiftRecord> get shiftHistory => List.unmodifiable(_shiftHistory);
  List<CustomerContact> get customerContacts => List.unmodifiable(_customerContacts);
  CommissionSettings get commissionSettings => _commissionSettings;
  ShopProfile get shopProfile => _shopProfile;
  String? get ownerPin => _ownerPin;
  bool get hasOwnerPin => _ownerPin != null && _ownerPin!.isNotEmpty;
  Map<String, SenderInfo> get discoveredSenders => Map.unmodifiable(_discoveredSenders);
  Set<String> get selectedSenders => Set.unmodifiable(_selectedSenders);
  bool get isScanningInbox => _isScanningInbox;
  ReconciliationResult? get lastReconciliation => _lastReconciliation;
  CashDenomination get cashDenomination => _cashDenomination;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  bool get isBalancePrivacyEnabled => _isBalancePrivacyEnabled;
  bool get isAppLockEnabled => _isAppLockEnabled;
  ThemeMode get themeMode => _themeMode;
  String get reconciliationPeriod => _reconciliationPeriod;
  double get dailyCommissionTarget => _dailyCommissionTarget;
  double get monthlyCommissionTarget => _monthlyCommissionTarget;

  String get shiftTimeRangeDisplay {
    final start = currentShiftStartTime;
    final formatter = DateFormat('h:mm a');
    return '${formatter.format(start)} → Now';
  }

  String get reconciliationPeriodLabel {
    switch (_reconciliationPeriod) {
      case 'shift':
        return 'This Shift ($shiftTimeRangeDisplay)';
      case 'today':
        return 'Full Day (since midnight)';
      case 'all':
        return 'All Messages (Last 7 days)';
      default:
        return 'This Shift';
    }
  }

  // Step Tracking Getters for Reconciliation Guided Workflow
  bool get isScanComplete => _discoveredSenders.isNotEmpty || _smsRecords.isNotEmpty;
  bool get isProvidersSelected => _selectedSenders.isNotEmpty;
  bool get isCashCounted => _lastReconciliation != null;
  int get completedStepsCount {
    int count = 0;
    if (isScanComplete) count++;
    if (isCashCounted) count++;
    if (_lastReconciliation != null && _lastReconciliation!.status == 'BALANCED') count++;
    return count;
  }
  int get currentStepperIndex {
    if (!isScanComplete) return 0;
    if (!isCashCounted) return 1;
    return 2;
  }

  void updateCashDenomination(CashDenomination denomination) {
    _cashDenomination = denomination;
    reconcileShift(physicalCash: denomination.total, denomination: denomination);
  }

  List<PettyCashExpense> get pettyCashExpenses => List.unmodifiable(_pettyCashExpenses);
  List<Teller> get tellers => List.unmodifiable(_tellers);
  Teller? get activeTeller => _activeTeller;
  List<ShiftHandover> get shiftHandovers => List.unmodifiable(_shiftHandovers);
  List<CustomUssdRule> get customUssdRules => List.unmodifiable(_customUssdRules);
  BluetoothPrinterInfo? get selectedPrinter => _selectedPrinter;
  bool get autoPrintReceipts => _autoPrintReceipts;

  int get currentShiftNumber => _shiftHistory.length + 1;

  List<PettyCashExpense> get todayPettyCashExpenses {
    final now = DateTime.now();
    return _pettyCashExpenses
        .where((e) => e.timestamp.year == now.year && e.timestamp.month == now.month && e.timestamp.day == now.day)
        .toList();
  }

  DateTime get currentShiftStartTime {
    DateTime? lastShiftEnd = _shiftHistory.isNotEmpty ? _shiftHistory.first.endTime : null;
    DateTime? lastHandoverTime = _shiftHandovers.isNotEmpty ? _shiftHandovers.first.handoverTime : null;

    if (lastShiftEnd == null && lastHandoverTime == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    if (lastShiftEnd != null && lastHandoverTime != null) {
      return lastShiftEnd.isAfter(lastHandoverTime) ? lastShiftEnd : lastHandoverTime;
    }
    return lastShiftEnd ?? lastHandoverTime!;
  }

  List<TransactionRecord> get currentShiftTransactions {
    final start = currentShiftStartTime;
    return _transactions.where((tx) => tx.timestamp.isAfter(start)).toList();
  }

  double get currentShiftInflow => currentShiftTransactions.where((t) =>
      t.type == TransactionType.cashIn ||
      t.type == TransactionType.airtime ||
      t.type == TransactionType.dataBundle ||
      t.type == TransactionType.ecgElectricity ||
      t.type == TransactionType.ghanaWater ||
      t.type == TransactionType.payTv).fold(0.0, (sum, t) => sum + t.amount);

  double get currentShiftOutflow => currentShiftTransactions.where((t) =>
      t.type == TransactionType.cashOut ||
      t.type == TransactionType.bankTransfer).fold(0.0, (sum, t) => sum + t.amount);

  double get currentShiftVolume => currentShiftTransactions.fold(0.0, (sum, t) => sum + t.amount);
  double get currentShiftCommission => currentShiftTransactions.fold(0.0, (sum, t) => sum + t.commission);

  double get currentShiftPettyCashTotal {
    final start = currentShiftStartTime;
    return _pettyCashExpenses
        .where((e) => e.timestamp.isAfter(start))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get todayPettyCashTotal {
    final now = DateTime.now();
    return _pettyCashExpenses
        .where((e) => e.timestamp.year == now.year && e.timestamp.month == now.month && e.timestamp.day == now.day)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalTodayPettyCash => todayPettyCashTotal;

  List<TransactionRecord> get todayTransactions {
    final now = DateTime.now();
    return _transactions.where((tx) {
      return tx.timestamp.year == now.year && tx.timestamp.month == now.month && tx.timestamp.day == now.day;
    }).toList();
  }

  double get todayInflow => todayTransactions.where((t) =>
      t.type == TransactionType.cashIn ||
      t.type == TransactionType.airtime ||
      t.type == TransactionType.dataBundle ||
      t.type == TransactionType.ecgElectricity ||
      t.type == TransactionType.ghanaWater ||
      t.type == TransactionType.payTv).fold(0.0, (sum, t) => sum + t.amount);

  double get todayOutflow => todayTransactions.where((t) =>
      t.type == TransactionType.cashOut ||
      t.type == TransactionType.bankTransfer).fold(0.0, (sum, t) => sum + t.amount);

  double get todayVolume => todayTransactions.fold(0.0, (sum, t) => sum + t.amount);
  double get todayCommission => todayTransactions.fold(0.0, (sum, t) => sum + t.commission);

  double get expectedDrawerCash => _initialDrawerOpeningBalance + currentShiftInflow - currentShiftOutflow - currentShiftPettyCashTotal;
  double get dailyGoalProgress => _dailyCommissionTarget > 0 ? (todayCommission / _dailyCommissionTarget).clamp(0.0, 1.0) : 0.0;
  double get projectedMonthlyCommission => todayCommission * 30;

  double get weeklyCommission {
    final now = DateTime.now();
    return _transactions
        .where((t) => now.difference(t.timestamp).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  double get monthlyCommission {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.timestamp.year == now.year && t.timestamp.month == now.month)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  double get totalCommission => _transactions.fold(0.0, (sum, t) => sum + t.commission);

  Map<NetworkProvider, double> get commissionsByNetwork {
    final map = <NetworkProvider, double>{
      NetworkProvider.mtn: 0.0,
      NetworkProvider.telecel: 0.0,
      NetworkProvider.at: 0.0,
      NetworkProvider.gmoney: 0.0,
    };
    for (final tx in _transactions) {
      map[tx.network] = (map[tx.network] ?? 0.0) + tx.commission;
    }
    return map;
  }

  List<DailyPerformance> get last7DaysPerformance {
    final list = <DailyPerformance>[];
    final now = DateTime.now();
    final dayFormat = DateFormat('E');

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dayTxs = _transactions.where((t) =>
          t.timestamp.year == targetDate.year &&
          t.timestamp.month == targetDate.month &&
          t.timestamp.day == targetDate.day);

      final vol = dayTxs.fold(0.0, (sum, t) => sum + t.amount);
      final comm = dayTxs.fold(0.0, (sum, t) => sum + t.commission);

      list.add(DailyPerformance(
        dayLabel: dayFormat.format(targetDate),
        date: targetDate,
        volume: vol,
        commission: comm,
        transactionCount: dayTxs.length,
      ));
    }
    return list;
  }

  // ─── Shift History Intelligence Getters ───
  ShiftRecord? get lastClosedShift => _shiftHistory.isNotEmpty ? _shiftHistory.first : null;

  double get averageShiftVariance {
    if (_shiftHistory.isEmpty) return 0.0;
    final totalAbsVar = _shiftHistory.fold(0.0, (sum, s) => sum + s.cashVariance.abs());
    return totalAbsVar / _shiftHistory.length;
  }

  int get balancedShiftStreak {
    int streak = 0;
    for (final shift in _shiftHistory) {
      if (shift.status.toUpperCase() == 'BALANCED') {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double get bestSingleShiftCommission {
    if (_shiftHistory.isEmpty) return 0.0;
    return _shiftHistory.map((s) => s.totalCommissions).reduce((a, b) => a > b ? a : b);
  }

  double get totalShiftCommissionsAllTime {
    return _shiftHistory.fold(0.0, (sum, s) => sum + s.totalCommissions);
  }

  double get totalShiftVolumeAllTime {
    return _shiftHistory.fold(0.0, (sum, s) => sum + s.totalCashIn + s.totalCashOut);
  }

  int get totalShiftTxCountAllTime {
    return _shiftHistory.fold(0, (sum, s) => sum + s.transactionCount);
  }

  Map<String, int> get shiftStatusCounts {
    final counts = {'BALANCED': 0, 'SHORTAGE': 0, 'OVERAGE': 0};
    for (final shift in _shiftHistory) {
      final st = shift.status.toUpperCase();
      if (counts.containsKey(st)) {
        counts[st] = counts[st]! + 1;
      } else {
        counts[st] = 1;
      }
    }
    return counts;
  }

  double get balancedShiftRate {
    if (_shiftHistory.isEmpty) return 100.0;
    final balancedCount = _shiftHistory.where((s) => s.status.toUpperCase() == 'BALANCED').length;
    return (balancedCount / _shiftHistory.length) * 100.0;
  }

  List<ShiftRecord> get thisWeekShifts {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return _shiftHistory.where((s) => s.endTime.isAfter(weekStart)).toList();
  }

  double get thisWeekShiftCommissions {
    return thisWeekShifts.fold(0.0, (sum, s) => sum + s.totalCommissions);
  }

  List<ShiftRecord> get lastWeekShifts {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    return _shiftHistory.where((s) => s.endTime.isAfter(prevWeekStart) && s.endTime.isBefore(weekStart)).toList();
  }

  double get lastWeekShiftCommissions {
    return lastWeekShifts.fold(0.0, (sum, s) => sum + s.totalCommissions);
  }

  Future<void> reloadShiftHistory() async {
    _shiftHistory = await DbService.getClosedShifts();
    notifyListeners();
  }

  String exportShiftHistoryToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Shift#,Start Time,End Time,Opening Cash,Closing Cash,Expected Cash,Variance,Cash In,Cash Out,Commissions,Tx Count,Status,AI Diagnosis');
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final s in _shiftHistory) {
      buffer.writeln(
        '${s.shiftNumber},"${df.format(s.startTime)}","${df.format(s.endTime)}",${s.openingCash.toStringAsFixed(2)},${s.closingCash.toStringAsFixed(2)},${s.expectedCash.toStringAsFixed(2)},${s.cashVariance.toStringAsFixed(2)},${s.totalCashIn.toStringAsFixed(2)},${s.totalCashOut.toStringAsFixed(2)},${s.totalCommissions.toStringAsFixed(2)},${s.transactionCount},"${s.status}","${s.aiDiagnosis.replaceAll('"', '""')}"',
      );
    }
    return buffer.toString();
  }

  /// Formats amount with thousand separators taking privacy mask into account
  String formatAmount(double amount, {String prefix = 'GHS '}) {
    if (_isBalancePrivacyEnabled) {
      return '$prefix••••••';
    }
    return '$prefix${_currencyFormatter.format(amount)}';
  }

  /// Formats raw number with thousand separators (e.g. 1,000.00)
  static String formatNumber(double amount) {
    return _currencyFormatter.format(amount);
  }

  /// Returns only SMS records from selected senders within the chosen time period
  List<SmsRecord> get filteredSmsRecords {
    final now = DateTime.now();
    final start = currentShiftStartTime;
    final selectedUpper = _selectedSenders.map((s) => s.toUpperCase().trim()).toSet();
    return _smsRecords.where((sms) {
      if (selectedUpper.isNotEmpty &&
          !selectedUpper.contains(sms.sender.toUpperCase().trim())) {
        return false;
      }
      switch (_reconciliationPeriod) {
        case 'shift':
          return sms.timestamp.isAfter(start);
        case 'today':
          return sms.timestamp.year == now.year &&
              sms.timestamp.month == now.month &&
              sms.timestamp.day == now.day;
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  Till get selectedTill {
    return _tills.firstWhere(
      (t) => t.id == _selectedTillId,
      orElse: () => _tills.isNotEmpty
          ? _tills.first
          : Till(
              id: 'default',
              network: NetworkProvider.mtn,
              tillName: 'MTN Agent Till 1',
              tillNumber: '0244000111',
              simSlot: 'SIM 1',
              currentFloat: 10000.0,
              minFloatAlert: 1000.0,
              ussdPrefix: '*171#',
              agentCode: 'AGT-001',
            ),
    );
  }

  Future<void> init() async {
    // 1. SQLite Database & Migration Check
    await DbService.checkAndMigrateFromPrefs();

    // 2. Load Tills from DB
    final savedTills = await DbService.getTills();
    if (savedTills.isNotEmpty) {
      _tills = savedTills;
    } else {
      _tills = [
        Till(
          id: 'till-mtn-01',
          network: NetworkProvider.mtn,
          tillName: 'MTN MoMo Agent Till',
          tillNumber: '0244123456',
          simSlot: 'SIM 1',
          currentFloat: 15450.00,
          minFloatAlert: 1500.00,
          ussdPrefix: '*171#',
          agentCode: 'MTN-ACC-9921',
        ),
        Till(
          id: 'till-telecel-01',
          network: NetworkProvider.telecel,
          tillName: 'Telecel Cash Till',
          tillNumber: '0205987654',
          simSlot: 'SIM 2',
          currentFloat: 8200.50,
          minFloatAlert: 1000.00,
          ussdPrefix: '*110#',
          agentCode: 'TEL-ACC-4412',
        ),
        Till(
          id: 'till-at-01',
          network: NetworkProvider.at,
          tillName: 'AT Money Till',
          tillNumber: '0261112233',
          simSlot: 'eSIM',
          currentFloat: 3500.00,
          minFloatAlert: 500.00,
          ussdPrefix: '*110#',
          agentCode: 'AT-ACC-1109',
        ),
        Till(
          id: 'till-gmoney-01',
          network: NetworkProvider.gmoney,
          tillName: 'G-Money Agent Account',
          tillNumber: '0509988776',
          simSlot: 'App / USSD',
          currentFloat: 5000.00,
          minFloatAlert: 800.00,
          ussdPrefix: '*422#',
          agentCode: 'GM-ACC-8832',
        ),
      ];
      for (final t in _tills) {
        await DbService.insertTill(t);
      }
    }

    // 3. Load Transactions from DB
    _transactions = await DbService.getTransactions(limit: 300);

    // 4. Load Petty Cash, Tellers, Handovers, Custom Rules from DB
    _pettyCashExpenses = await DbService.getPettyCashExpenses();
    _shiftHandovers = await DbService.getShiftHandovers();
    _customUssdRules = await DbService.getCustomUssdRules();
    _customerContacts = await DbService.getContacts();
    _shiftHistory = await DbService.getClosedShifts();

    // 5. Load Tellers
    final savedTellers = await DbService.getTellers();
    if (savedTellers.isNotEmpty) {
      _tellers = savedTellers;
      _activeTeller = _tellers.firstWhere((t) => t.isActive, orElse: () => _tellers.first);
    } else {
      final defaultOwner = Teller(
        id: 'teller_owner',
        name: 'Shop Owner',
        phone: '0244123456',
        pinHash: '1234',
        role: TellerRole.owner,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final defaultAttendant = Teller(
        id: 'teller_attendant_1',
        name: 'Morning Attendant',
        phone: '0200112233',
        pinHash: '0000',
        role: TellerRole.attendant,
        isActive: false,
        createdAt: DateTime.now(),
      );
      _tellers = [defaultOwner, defaultAttendant];
      _activeTeller = defaultOwner;
      await DbService.insertTeller(defaultOwner);
      await DbService.insertTeller(defaultAttendant);
    }

    // 6. Load Preferences
    final savedCash = await StorageService.loadDrawerCash();
    if (savedCash != null) {
      _currentCashInDrawer = savedCash;
      _initialDrawerOpeningBalance = savedCash;
    }

    _lastReconciliation = await StorageService.loadLastReconciliation();
    _dailyCommissionTarget = await StorageService.loadDailyTarget();
    _monthlyCommissionTarget = await StorageService.loadMonthlyTarget();
    _commissionSettings = await StorageService.loadCommissionSettings();
    _shopProfile = await StorageService.loadShopProfile();
    _ownerPin = await StorageService.loadOwnerPin();
    _hasCompletedOnboarding = await StorageService.loadHasCompletedOnboarding();
    _isBalancePrivacyEnabled = await StorageService.loadBalancePrivacy();
    _isAppLockEnabled = await StorageService.loadAppLock();

    final savedTheme = await StorageService.loadThemeMode();
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    // 7. Initialize Real-Time USSD & SMS Broadcast Callback Listeners
    UssdService.initializeCallbackListener(
      onUssdComplete: _handleUssdCallback,
      onSmsReceived: _handleIncomingSms,
    );

    checkAccessibilityState();
    // Only recalculate on startup if there's a saved reconciliation to restore.
    // Calling it fresh (no cash counted yet) creates a phantom shortage/variance.
    if (_lastReconciliation != null) {
      recalculateReconciliation();
    }
    notifyListeners();
  }

  Future<void> checkAccessibilityState() async {
    _isAccessibilityEnabled = await UssdService.isAccessibilityEnabled();
    notifyListeners();
  }

  // ─── First-Time Onboarding Completion ───
  Future<void> completeOnboarding({
    required ShopProfile profile,
    required double openingCash,
  }) async {
    _shopProfile = profile;
    await StorageService.saveShopProfile(profile);
    _currentCashInDrawer = openingCash;
    _initialDrawerOpeningBalance = openingCash;
    await StorageService.saveDrawerCash(openingCash);
    _hasCompletedOnboarding = true;
    await StorageService.saveHasCompletedOnboarding(true);
    notifyListeners();
  }

  // ─── Shop & Owner Profile Management ───
  Future<void> updateShopProfile(ShopProfile profile) async {
    _shopProfile = profile;
    await StorageService.saveShopProfile(profile);
    notifyListeners();
  }

  // ─── Owner Security PIN ───
  Future<void> setOwnerPin(String? pin) async {
    _ownerPin = pin;
    await StorageService.saveOwnerPin(pin);
    notifyListeners();
  }

  bool verifyOwnerPin(String pin) {
    if (_ownerPin == null || _ownerPin!.isEmpty) return true;
    return _ownerPin == pin;
  }

  // ─── Theme Mode ───
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    final modeStr = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    StorageService.saveThemeMode(modeStr);
    notifyListeners();
  }

  // ─── Balance Privacy ───
  void toggleBalancePrivacy() {
    _isBalancePrivacyEnabled = !_isBalancePrivacyEnabled;
    StorageService.saveBalancePrivacy(_isBalancePrivacyEnabled);
    notifyListeners();
  }

  // ─── App Lock ───
  void toggleAppLock(bool enabled) {
    _isAppLockEnabled = enabled;
    StorageService.saveAppLock(enabled);
    notifyListeners();
  }

  // ─── Commission Settings ───
  void updateCommissionSettings(CommissionSettings settings) {
    _commissionSettings = settings;
    StorageService.saveCommissionSettings(settings);
    recalculateReconciliation();
    notifyListeners();
  }

  // ─── Till Management ───
  Future<void> addCustomTill(Till till) async {
    _tills.add(till);
    await DbService.insertTill(till);
    notifyListeners();
  }

  Future<void> updateTill(Till updated) async {
    _tills = _tills.map((t) => t.id == updated.id ? updated : t).toList();
    await DbService.updateTill(updated);
    notifyListeners();
  }

  Future<void> deleteTill(String tillId) async {
    _tills.removeWhere((t) => t.id == tillId);
    if (_selectedTillId == tillId && _tills.isNotEmpty) {
      _selectedTillId = _tills.first.id;
    }
    notifyListeners();
  }

  // ─── Customer Contacts ───
  Future<void> saveContact(CustomerContact contact) async {
    final index = _customerContacts.indexWhere((c) => c.phone == contact.phone);
    if (index >= 0) {
      _customerContacts[index] = contact;
    } else {
      _customerContacts.insert(0, contact);
    }
    await DbService.insertContact(contact);
    notifyListeners();
  }

  // ─── Petty Cash Expenses ───
  Future<void> addPettyCashExpense(PettyCashExpense expense) async {
    _pettyCashExpenses.insert(0, expense);
    await DbService.insertPettyCash(expense);
    recalculateReconciliation();
    notifyListeners();
  }

  Future<void> deletePettyCashExpense(String id) async {
    _pettyCashExpenses.removeWhere((e) => e.id == id);
    await DbService.deletePettyCash(id);
    recalculateReconciliation();
    notifyListeners();
  }

  // ─── Teller & Shift Handovers ───
  Future<void> addTeller(Teller teller) async {
    _tellers.add(teller);
    await DbService.insertTeller(teller);
    notifyListeners();
  }

  Future<void> switchActiveTeller(String tellerId) async {
    _tellers = _tellers.map((t) => Teller(
      id: t.id,
      name: t.name,
      phone: t.phone,
      pinHash: t.pinHash,
      role: t.role,
      isActive: t.id == tellerId,
      createdAt: t.createdAt,
      lastShiftStartedAt: t.id == tellerId ? DateTime.now() : t.lastShiftStartedAt,
    )).toList();

    _activeTeller = _tellers.firstWhere((t) => t.id == tellerId);
    for (final t in _tellers) {
      await DbService.updateTeller(t);
    }
    notifyListeners();
  }

  Future<void> recordShiftHandover(ShiftHandover handover, {Teller? nextTeller}) async {
    _shiftHandovers.insert(0, handover);
    await DbService.insertShiftHandover(handover);

    // Update drawer opening balance and current cash to counted handover cash
    _initialDrawerOpeningBalance = handover.countedDrawerCash;
    _currentCashInDrawer = handover.countedDrawerCash;
    await StorageService.saveDrawerCash(handover.countedDrawerCash);

    // Clear previous attendant's scan session and reconciliation
    _allScannedRecords.clear();
    _allDiscoveredSenders.clear();
    _smsRecords.clear();
    _discoveredSenders.clear();
    _selectedSenders.clear();
    _cashDenomination = CashDenomination();
    _lastReconciliation = null;
    _reconciliationPeriod = 'shift';
    await StorageService.saveLastReconciliation(null);

    if (nextTeller != null) {
      await switchActiveTeller(nextTeller.id);
    }

    notifyListeners();
  }

  // ─── Custom USSD Rules ───
  Future<void> saveCustomUssdRule(CustomUssdRule rule) async {
    _customUssdRules.removeWhere((r) => r.id == rule.id || (r.network == rule.network && r.transactionType == rule.transactionType));
    _customUssdRules.add(rule);
    await DbService.insertCustomUssdRule(rule);
    notifyListeners();
  }

  Future<void> deleteCustomUssdRule(String id) async {
    _customUssdRules.removeWhere((r) => r.id == id);
    await DbService.deleteCustomUssdRule(id);
    notifyListeners();
  }

  // ─── Bluetooth Thermal Printer ───
  void setPrinter(BluetoothPrinterInfo printer) {
    _selectedPrinter = printer;
    notifyListeners();
  }

  void setAutoPrint(bool value) {
    _autoPrintReceipts = value;
    notifyListeners();
  }

  // ─── Fraud Security Analyzer ───
  FraudCheckResult checkSmsFraud(SmsRecord sms) {
    final isKnownSender = SmsParserService.isMoMoSender(sms.sender);
    final duplicateCount = _transactions.where((t) => t.reference == sms.reference && t.reference.isNotEmpty).length;
    final isDuplicate = duplicateCount > 1;

    final now = DateTime.now();
    final driftMinutes = now.difference(sms.timestamp).inMinutes.abs();
    final isTimestampPlausible = driftMinutes < 1440; // within 24 hours

    if (!isKnownSender) {
      return FraudCheckResult(
        riskLevel: FraudRiskLevel.highRisk,
        message: 'Suspicious sender ID (${sms.sender}). Not an official carrier short code.',
        isSenderAuthentic: false,
        isDuplicateReference: isDuplicate,
        isTimestampValid: isTimestampPlausible,
      );
    }

    if (isDuplicate) {
      return FraudCheckResult(
        riskLevel: FraudRiskLevel.suspicious,
        message: 'Duplicate Transaction Reference (${sms.reference}) already logged in database!',
        isSenderAuthentic: true,
        isDuplicateReference: true,
        isTimestampValid: isTimestampPlausible,
      );
    }

    return FraudCheckResult(
      riskLevel: FraudRiskLevel.safe,
      message: 'Verified official carrier payment confirmation.',
      isSenderAuthentic: true,
      isDuplicateReference: false,
      isTimestampValid: isTimestampPlausible,
    );
  }

  // ─── Shift Closing & EOD Settlement ───
  Future<ShiftRecord> closeCurrentShift({
    required double countedCash,
    required BuildContext context,
    CashDenomination? denomination,
  }) async {
    reconcileShift(physicalCash: countedCash, denomination: denomination);
    final rec = _lastReconciliation!;

    final now = DateTime.now();
    final start = currentShiftStartTime;
    final periodTx = _transactions.where((tx) => tx.timestamp.isAfter(start)).toList();

    final shift = ShiftRecord(
      id: _uuid.v4(),
      shiftNumber: currentShiftNumber,
      startTime: start,
      endTime: now,
      openingCash: _initialDrawerOpeningBalance,
      closingCash: countedCash,
      expectedCash: rec.expectedPhysicalCash,
      cashVariance: rec.cashVariance,
      totalCashIn: rec.totalCashIn,
      totalCashOut: rec.totalCashOut,
      totalCommissions: rec.totalCommissions,
      transactionCount: periodTx.isNotEmpty ? periodTx.length : currentShiftTransactions.length,
      status: rec.status,
      aiDiagnosis: rec.aiDiagnosis,
      denomination: denomination ?? _cashDenomination,
      networkBreakdown: rec.networkBreakdown,
    );

    _shiftHistory.insert(0, shift);
    await DbService.insertShift(shift);

    // Carry forward closing cash to new shift opening balance
    _initialDrawerOpeningBalance = countedCash;
    _currentCashInDrawer = countedCash;
    await StorageService.saveDrawerCash(countedCash);

    // Reset reconciliation and scan session for the fresh new shift
    _allScannedRecords.clear();
    _allDiscoveredSenders.clear();
    _smsRecords.clear();
    _discoveredSenders.clear();
    _selectedSenders.clear();
    _cashDenomination = CashDenomination();
    _lastReconciliation = null;
    _reconciliationPeriod = 'shift';
    await StorageService.saveLastReconciliation(null);

    notifyListeners();
    return shift;
  }

  // ─── CSV Export ───
  String exportLedgerToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Reference,Network,Type,Amount (GHS),Fee (GHS),Commission (GHS),Customer Phone,Till ID,Status,Timestamp');
    for (final tx in _transactions) {
      buffer.writeln('${tx.id},"${tx.reference}",${tx.network.name},${tx.type.name},${tx.amount},${tx.fee},${tx.commission},"${tx.customerPhone}",${tx.tillId},${tx.status.name},"${tx.timestamp.toIso8601String()}"');
    }
    return buffer.toString();
  }

  void selectTill(String id) {
    _selectedTillId = id;
    notifyListeners();
  }

  void setReconciliationPeriod(String period) {
    _reconciliationPeriod = period;
    _applyPeriodFilter();
    recalculateReconciliation();
    notifyListeners();
  }

  String _categorizeSender(String senderAddr) {
    final lowerAddr = senderAddr.toLowerCase();
    if (lowerAddr.contains('mtn') || lowerAddr.contains('mobilemoney') || lowerAddr == '171') {
      return 'MoMo';
    } else if (lowerAddr.contains('telecel') || lowerAddr.contains('vodafone') || lowerAddr == '110') {
      return 'MoMo';
    } else if (lowerAddr.contains('atmoney') || lowerAddr.contains('airteltigo') || lowerAddr.contains('at money')) {
      return 'MoMo';
    } else if (lowerAddr.contains('gmoney') || lowerAddr.contains('gcb')) {
      return 'MoMo';
    } else if (lowerAddr.contains('bank') || lowerAddr.contains('fidelity') ||
        lowerAddr.contains('ecobank') || lowerAddr.contains('stanbic') ||
        lowerAddr.contains('absa') || lowerAddr.contains('zenith') ||
        lowerAddr.contains('calbank') || lowerAddr.contains('gtbank') ||
        lowerAddr.contains('access')) {
      return 'Bank';
    } else if (lowerAddr.contains('zeepay') || lowerAddr.contains('hubtel') || lowerAddr.contains('expresspay')) {
      return 'FinTech';
    } else {
      return 'Other';
    }
  }

  void _applyPeriodFilter() {
    final now = DateTime.now();
    final start = currentShiftStartTime;
    final DateTime cutoff;
    switch (_reconciliationPeriod) {
      case 'shift':
        cutoff = start;
        break;
      case 'today':
        cutoff = DateTime(now.year, now.month, now.day);
        break;
      case 'all':
      default:
        cutoff = now.subtract(const Duration(days: 7));
        break;
    }

    _smsRecords.clear();
    _smsRecords.addAll(_allScannedRecords.where((r) => r.timestamp.isAfter(cutoff)));

    // Rebuild _discoveredSenders with counts scoped to this period
    _discoveredSenders.clear();
    for (final record in _smsRecords) {
      final key = record.sender.toUpperCase().trim();
      final existing = _discoveredSenders[key];
      final category = _categorizeSender(record.sender);
      if (existing == null) {
        _discoveredSenders[key] = SenderInfo(
          address: record.sender,
          totalMessages: 1,
          parsedTransactions: 1,
          category: category,
        );
      } else {
        _discoveredSenders[key] = SenderInfo(
          address: record.sender,
          totalMessages: existing.totalMessages + 1,
          parsedTransactions: existing.parsedTransactions + 1,
          category: category,
        );
      }
    }

    // Smart auto-selection: select only MoMo providers by default
    _selectedSenders.clear();
    for (final entry in _discoveredSenders.entries) {
      if (entry.value.category == 'MoMo') {
        _selectedSenders.add(entry.key);
      }
    }
  }

  void toggleSenderSelection(String sender) {
    final key = sender.toUpperCase().trim();
    if (_selectedSenders.contains(key)) {
      _selectedSenders.remove(key);
    } else {
      _selectedSenders.add(key);
    }
    recalculateReconciliation();
    notifyListeners();
  }

  void selectAllSenders() {
    _selectedSenders.clear();
    _selectedSenders.addAll(_discoveredSenders.keys);
    recalculateReconciliation();
    notifyListeners();
  }

  void clearSenderSelection() {
    _selectedSenders.clear();
    recalculateReconciliation();
    notifyListeners();
  }

  /// Checks if all senders for a given network are selected
  bool isNetworkSelected(NetworkProvider network) {
    final netSenders = _discoveredSenders.values.where((s) {
      final lower = s.address.toLowerCase();
      switch (network) {
        case NetworkProvider.mtn:
          return lower.contains('mtn') || lower.contains('mobilemoney') || lower.contains('171');
        case NetworkProvider.telecel:
          return lower.contains('telecel') || lower.contains('vodafone') || lower.contains('110');
        case NetworkProvider.at:
          return lower.contains('atmoney') || lower.contains('airteltigo') || lower.contains('at money');
        case NetworkProvider.gmoney:
          return lower.contains('gmoney') || lower.contains('gcb') || lower.contains('g-money');
      }
    }).toList();

    if (netSenders.isEmpty) return false;
    return netSenders.every((s) => _selectedSenders.contains(s.address.toUpperCase().trim()));
  }

  /// Returns total parsed transactions for a network in the active session
  int networkParsedTxCount(NetworkProvider network) {
    return filteredSmsRecords.where((r) => r.network == network).length;
  }

  /// Toggles all senders matching a specific telecom network
  void toggleNetworkSelection(NetworkProvider network) {
    final netSenders = _discoveredSenders.values.where((s) {
      final lower = s.address.toLowerCase();
      switch (network) {
        case NetworkProvider.mtn:
          return lower.contains('mtn') || lower.contains('mobilemoney') || lower.contains('171');
        case NetworkProvider.telecel:
          return lower.contains('telecel') || lower.contains('vodafone') || lower.contains('110');
        case NetworkProvider.at:
          return lower.contains('atmoney') || lower.contains('airteltigo') || lower.contains('at money');
        case NetworkProvider.gmoney:
          return lower.contains('gmoney') || lower.contains('gcb') || lower.contains('g-money');
      }
    }).toList();

    final currentlySelected = isNetworkSelected(network);
    for (final s in netSenders) {
      final key = s.address.toUpperCase().trim();
      if (currentlySelected) {
        _selectedSenders.remove(key);
      } else {
        _selectedSenders.add(key);
      }
    }
    recalculateReconciliation();
    notifyListeners();
  }

  /// Returns formatted elapsed duration since current shift started (e.g. "4h 12m ago")
  String get shiftElapsedTimeDisplay {
    final now = DateTime.now();
    final start = currentShiftStartTime;
    final diff = now.difference(start);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just started';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours == 0) {
      return '${minutes}m ago';
    }
    return '${hours}h ${minutes}m ago';
  }

  void updateDailyTarget(double target) {
    _dailyCommissionTarget = target;
    StorageService.saveDailyTarget(target);
    notifyListeners();
  }

  void updateMonthlyTarget(double target) {
    _monthlyCommissionTarget = target;
    StorageService.saveMonthlyTarget(target);
    notifyListeners();
  }

  void recalculateReconciliation() {
    reconcileShift(physicalCash: _currentCashInDrawer);
  }

  /// Scans device SMS inbox, surfaces payment senders, and syncs transactions
  Future<void> scanDeviceInboxAndDiscoverSenders(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    _isScanningInbox = true;
    notifyListeners();

    final permissionStatus = await Permission.sms.request();

    if (!permissionStatus.isGranted) {
      _isScanningInbox = false;
      notifyListeners();

      if (permissionStatus.isPermanentlyDenied && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('SMS Permission Required'),
            content: const Text(
              'MobiBoss requires SMS reading permission to inspect transaction confirmations from your mobile networks and payment providers.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('SMS Permission denied. Unable to scan device messages.')),
        );
      }
      return;
    }

    try {
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 500,
      );

      _allScannedRecords.clear();
      _allDiscoveredSenders.clear();
      _discoveredSenders.clear();
      _smsRecords.clear();
      _selectedSenders.clear();

      final Map<String, List<SmsMessage>> senderMessages = {};

      for (final msg in messages) {
        final rawAddress = (msg.address ?? '').trim();
        final body = (msg.body ?? '').trim();
        if (rawAddress.isEmpty || body.isEmpty) continue;

        final key = rawAddress.toUpperCase();
        senderMessages.putIfAbsent(key, () => []).add(msg);
      }

      for (final entry in senderMessages.entries) {
        final senderAddr = entry.key;
        final msgs = entry.value;
        int parsedCount = 0;
        final category = _categorizeSender(senderAddr);

        for (final msg in msgs) {
          final body = (msg.body ?? '').trim();
          final isKnownSender = SmsParserService.isMoMoSender(senderAddr);
          final hasPaymentKeywords = _containsPaymentKeywords(body);

          if (isKnownSender || hasPaymentKeywords) {
            final parsed = SmsParserService.parse(body, sender: senderAddr, timestamp: msg.date);
            if (parsed != null) {
              final isDup = SmsParserService.isDuplicate(parsed, _allScannedRecords);
              if (!isDup) {
                _allScannedRecords.add(parsed);
                _processReversalMatch(parsed);
                _autoRecordConfirmedTransaction(parsed);
                _autoUpdateContact(parsed.customerPhone, parsed.network);
                parsedCount++;
              }
            }
          }
        }

        if (parsedCount > 0) {
          _allDiscoveredSenders[senderAddr] = SenderInfo(
            address: senderAddr,
            totalMessages: msgs.length,
            parsedTransactions: parsedCount,
            category: category,
          );
        }
      }

      // Filter parsed records to active period (defaults to 'shift')
      _applyPeriodFilter();

      _isScanningInbox = false;
      recalculateReconciliation();
      notifyListeners();

      final momoCount = _discoveredSenders.values.where((s) => s.category == 'MoMo').length;
      final otherCount = _discoveredSenders.length - momoCount;
      String snackMsg = 'Found $momoCount MoMo provider(s) with ${_smsRecords.length} transaction(s).';
      if (otherCount > 0) {
        snackMsg += ' ($otherCount other sender(s) available to review)';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          backgroundColor: const Color(0xFF1E8E3E),
        ),
      );
    } catch (e) {
      _isScanningInbox = false;
      notifyListeners();
      messenger.showSnackBar(
        SnackBar(content: Text('Error reading inbox: $e')),
      );
    }
  }

  /// Processes reversal matches by voiding the matching original SMS and transaction records
  void _processReversalMatch(SmsRecord reversal) {
    if (!reversal.isReversed && reversal.type != TransactionType.reversal) return;

    final origSms = SmsParserService.findOriginalForReversal(reversal, _allScannedRecords);
    if (origSms != null) {
      final idxAll = _allScannedRecords.indexWhere((r) => r.id == origSms.id);
      if (idxAll != -1) {
        _allScannedRecords[idxAll] = _allScannedRecords[idxAll].copyWith(
          isVoided: true,
          voidedByReversalId: reversal.id,
        );
      }
      final idxShift = _smsRecords.indexWhere((r) => r.id == origSms.id);
      if (idxShift != -1) {
        _smsRecords[idxShift] = _smsRecords[idxShift].copyWith(
          isVoided: true,
          voidedByReversalId: reversal.id,
        );
      }
    }

    // Also mark matching transaction record as reversed/voided
    final txIdx = _transactions.indexWhere((t) =>
        !t.isVoided &&
        t.network == reversal.network &&
        (t.amount - reversal.amount).abs() < 0.01 &&
        (reversal.customerPhone.isEmpty || t.customerPhone == reversal.customerPhone));
    if (txIdx != -1) {
      _transactions[txIdx] = _transactions[txIdx].copyWith(
        isVoided: true,
        voidedByReversalId: reversal.id,
        status: TransactionStatus.reversed,
      );
    }
  }

  /// Automatically records confirmed transactions into the ledger and updates float/drawer
  Future<void> _autoRecordConfirmedTransaction(SmsRecord sms) async {
    // If this is a reversal, process the reversal pairing and avoid double-counting
    if (sms.isReversed || sms.type == TransactionType.reversal) {
      _processReversalMatch(sms);
      return;
    }

    final exists = _transactions.any((t) => t.reference == sms.reference);
    if (exists) return;

    final matchingTill = _tills.firstWhere(
      (t) => t.network == sms.network,
      orElse: () => selectedTill,
    );

    final tx = TransactionRecord(
      id: _uuid.v4(),
      tillId: matchingTill.id,
      network: sms.network,
      type: sms.type,
      amount: sms.amount,
      fee: sms.fee,
      commission: _calculateCommission(sms.network, sms.type, sms.amount),
      customerPhone: sms.customerPhone.isNotEmpty ? sms.customerPhone : matchingTill.tillNumber,
      reference: sms.reference,
      ussdString: 'CONFIRMED_${sms.sender}',
      timestamp: sms.timestamp,
      status: TransactionStatus.completed,
    );

    _transactions.insert(0, tx);
    await DbService.insertTransaction(tx);
    await _applyBalanceImpact(matchingTill.id, sms.type, sms.amount, postBalance: sms.postBalance);

    // Auto-print thermal receipt if connected
    if (_autoPrintReceipts && _selectedPrinter != null) {
      final bytes = ReceiptService.buildEscPosTransactionReceipt(tx: tx, till: matchingTill);
      await ReceiptService.printRawBytes(printerAddress: _selectedPrinter!.address, bytes: bytes);
    }
  }

  Future<void> _applyBalanceImpact(String tillId, TransactionType type, double amount, {double? postBalance}) async {
    Till? updatedTill;
    _tills = _tills.map((t) {
      if (t.id == tillId) {
        if (postBalance != null && postBalance > 0) {
          updatedTill = t.copyWith(currentFloat: postBalance);
          return updatedTill!;
        }

        double newFloat = t.currentFloat;
        switch (type) {
          case TransactionType.cashIn:
          case TransactionType.airtime:
          case TransactionType.dataBundle:
          case TransactionType.ecgElectricity:
          case TransactionType.ghanaWater:
          case TransactionType.payTv:
            newFloat -= amount;
            break;
          case TransactionType.cashOut:
          case TransactionType.floatTransfer:
          case TransactionType.bankTransfer:
            newFloat += amount;
            break;
          case TransactionType.reversal:
            break;
        }
        updatedTill = t.copyWith(currentFloat: newFloat);
        return updatedTill!;
      }
      return t;
    }).toList();

    if (updatedTill != null) {
      await DbService.updateTill(updatedTill!);
    }

    // Physical cash drawer balance changes:
    // Cash In / Airtime / Utility / PayTV: customer gives physical cash to drawer -> drawer increases
    // Cash Out: agent hands physical cash to customer -> drawer decreases
    switch (type) {
      case TransactionType.cashIn:
      case TransactionType.airtime:
      case TransactionType.dataBundle:
      case TransactionType.ecgElectricity:
      case TransactionType.ghanaWater:
      case TransactionType.payTv:
        _currentCashInDrawer += amount;
        break;
      case TransactionType.cashOut:
        _currentCashInDrawer -= amount;
        break;
      case TransactionType.floatTransfer:
      case TransactionType.bankTransfer:
      case TransactionType.reversal:
        break;
    }
    await StorageService.saveDrawerCash(_currentCashInDrawer);
  }

  /// Records a completed direct transaction (for manual / offline / feature-phone usage)
  Future<TransactionRecord> recordDirectTransaction({
    required Till till,
    required TransactionType type,
    required double amount,
    required String customerPhone,
    String? reference,
    double? customFee,
  }) async {
    final fee = customFee ?? 0.0;
    final commission = _calculateCommission(till.network, type, amount);
    final ref = (reference != null && reference.trim().isNotEmpty)
        ? reference.trim()
        : 'MB-DIR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final tx = TransactionRecord(
      id: _uuid.v4(),
      tillId: till.id,
      network: till.network,
      type: type,
      amount: amount,
      fee: fee,
      commission: commission,
      customerPhone: customerPhone,
      reference: ref,
      ussdString: 'DIRECT_RECORD',
      timestamp: DateTime.now(),
      status: TransactionStatus.completed,
    );

    _transactions.insert(0, tx);
    await DbService.insertTransaction(tx);
    await _applyBalanceImpact(till.id, type, amount);
    _autoUpdateContact(customerPhone, till.network);

    if (_autoPrintReceipts && _selectedPrinter != null) {
      final bytes = ReceiptService.buildEscPosTransactionReceipt(tx: tx, till: till);
      await ReceiptService.printRawBytes(printerAddress: _selectedPrinter!.address, bytes: bytes);
    }

    recalculateReconciliation();
    notifyListeners();
    return tx;
  }

  /// Records a pending transaction when USSD session is initiated
  Future<TransactionRecord> recordPendingUssdTransaction({
    required Till till,
    required TransactionType type,
    required double amount,
    required String customerPhone,
    required String ussdCode,
  }) async {
    final commission = _calculateCommission(till.network, type, amount);
    final tx = TransactionRecord(
      id: _uuid.v4(),
      tillId: till.id,
      network: till.network,
      type: type,
      amount: amount,
      fee: 0.0,
      commission: commission,
      customerPhone: customerPhone,
      reference: 'PENDING-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      ussdString: ussdCode,
      timestamp: DateTime.now(),
      status: TransactionStatus.pending,
    );

    _transactions.insert(0, tx);
    await DbService.insertTransaction(tx);
    notifyListeners();
    return tx;
  }

  /// Global lightweight 1-tap SMS sync that queries device inbox and auto-reconciles
  Future<int> syncRecentSms() async {
    final permission = await Permission.sms.request();
    if (!permission.isGranted) return 0;

    try {
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );

      final start = currentShiftStartTime;
      int newlySynced = 0;
      for (final msg in messages) {
        if (msg.date != null && !msg.date!.isAfter(start)) continue;

        final rawAddress = (msg.address ?? '').trim();
        final body = (msg.body ?? '').trim();
        if (rawAddress.isEmpty || body.isEmpty) continue;

        final isKnownSender = SmsParserService.isMoMoSender(rawAddress);
        final hasPaymentKeywords = _containsPaymentKeywords(body);

        if (isKnownSender || hasPaymentKeywords) {
          final parsed = SmsParserService.parse(body, sender: rawAddress, timestamp: msg.date);
          if (parsed != null) {
            final existsInAll = _allScannedRecords.any((r) => r.reference == parsed.reference);
            if (!existsInAll) {
              _allScannedRecords.insert(0, parsed);
            }

            // Check if matches a pending transaction in ledger
            final pendingIdx = _transactions.indexWhere(
              (t) =>
                  t.status == TransactionStatus.pending &&
                  (t.amount == parsed.amount ||
                      (parsed.customerPhone.isNotEmpty && t.customerPhone == parsed.customerPhone)),
            );

            if (pendingIdx != -1) {
              final pendingTx = _transactions[pendingIdx];
              final updatedTx = TransactionRecord(
                id: pendingTx.id,
                tillId: pendingTx.tillId,
                network: parsed.network,
                type: parsed.type,
                amount: parsed.amount,
                fee: parsed.fee,
                commission: _calculateCommission(parsed.network, parsed.type, parsed.amount),
                customerPhone: parsed.customerPhone.isNotEmpty ? parsed.customerPhone : pendingTx.customerPhone,
                reference: parsed.reference,
                ussdString: pendingTx.ussdString,
                timestamp: parsed.timestamp,
                status: TransactionStatus.completed,
              );
              _transactions[pendingIdx] = updatedTx;
              await DbService.insertTransaction(updatedTx);
              await _applyBalanceImpact(pendingTx.tillId, parsed.type, parsed.amount, postBalance: parsed.postBalance);
              newlySynced++;
            } else {
              final isDupInSms = SmsParserService.isDuplicate(parsed, _smsRecords);
              final isDupInAll = SmsParserService.isDuplicate(parsed, _allScannedRecords);
              final existsInTx = _transactions.any((t) => t.reference == parsed.reference);

              if (!isDupInSms) {
                _smsRecords.insert(0, parsed);
              }
              if (!isDupInAll) {
                _allScannedRecords.insert(0, parsed);
              }
              if (parsed.isReversed || parsed.type == TransactionType.reversal) {
                _processReversalMatch(parsed);
                newlySynced++;
              } else if (!existsInTx) {
                await _autoRecordConfirmedTransaction(parsed);
                newlySynced++;
              }
            }
          }
        }
      }

      if (newlySynced > 0) {
        recalculateReconciliation();
        notifyListeners();
      }
      return newlySynced;
    } catch (_) {
      return 0;
    }
  }

  /// Top-up till float using drawer cash or transfer float between SIM tills
  Future<void> topUpTillFloat({
    required String tillId,
    required double amount,
    required bool paidFromDrawer,
    String? sourceTillId,
  }) async {
    final targetTill = _tills.firstWhere((t) => t.id == tillId);

    if (sourceTillId != null && sourceTillId != tillId) {
      final srcTill = _tills.firstWhere((t) => t.id == sourceTillId);
      final updatedSrc = srcTill.copyWith(currentFloat: srcTill.currentFloat - amount);
      final updatedTarget = targetTill.copyWith(currentFloat: targetTill.currentFloat + amount);
      await updateTill(updatedSrc);
      await updateTill(updatedTarget);

      final tx = TransactionRecord(
        id: _uuid.v4(),
        tillId: tillId,
        network: targetTill.network,
        type: TransactionType.floatTransfer,
        amount: amount,
        fee: 0.0,
        commission: 0.0,
        customerPhone: '${srcTill.tillName} -> ${targetTill.tillName}',
        reference: 'REBAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        ussdString: 'FLOAT_TRANSFER',
        timestamp: DateTime.now(),
        status: TransactionStatus.completed,
      );
      _transactions.insert(0, tx);
      await DbService.insertTransaction(tx);
    } else {
      final updatedTarget = targetTill.copyWith(currentFloat: targetTill.currentFloat + amount);
      await updateTill(updatedTarget);

      if (paidFromDrawer) {
        _currentCashInDrawer -= amount;
        await StorageService.saveDrawerCash(_currentCashInDrawer);
      }

      final tx = TransactionRecord(
        id: _uuid.v4(),
        tillId: tillId,
        network: targetTill.network,
        type: TransactionType.floatTransfer,
        amount: amount,
        fee: 0.0,
        commission: 0.0,
        customerPhone: paidFromDrawer ? 'Drawer Cash Top-Up' : 'Bank/Super-Agent Purchase',
        reference: 'TOPUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        ussdString: 'FLOAT_PURCHASE',
        timestamp: DateTime.now(),
        status: TransactionStatus.completed,
      );
      _transactions.insert(0, tx);
      await DbService.insertTransaction(tx);
    }

    recalculateReconciliation();
    notifyListeners();
  }

  /// Adjusts drawer cash balance (e.g. morning opening float or midday deposit/withdrawal)
  Future<void> adjustDrawerCash({required double newAmount, required String reason}) async {
    _currentCashInDrawer = newAmount;
    await StorageService.saveDrawerCash(_currentCashInDrawer);
    recalculateReconciliation();
    notifyListeners();
  }

  /// Verifies PIN against active teller or store owners
  bool verifyTellerPin(String pin) {
    if (_tellers.isEmpty) return true;
    final trimmed = pin.trim();
    if (_activeTeller != null && _activeTeller!.pinHash == trimmed) return true;
    return _tellers.any(
      (t) => (t.role == TellerRole.owner || t.role == TellerRole.shiftSupervisor) && t.pinHash == trimmed,
    );
  }

  /// Builds a formatted plain text digital receipt for WhatsApp or clipboard
  String buildDigitalReceipt(TransactionRecord tx) {
    final till = _tills.firstWhere((t) => t.id == tx.tillId, orElse: () => selectedTill);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp);
    final typeName = tx.type == TransactionType.cashIn
        ? 'Cash In (Deposit)'
        : tx.type == TransactionType.cashOut
            ? 'Cash Out (Withdrawal)'
            : tx.type == TransactionType.airtime
                ? 'Airtime Top-Up'
                : tx.type == TransactionType.dataBundle
                    ? 'Data Bundle'
                    : tx.type.name.toUpperCase();

    return '''
🧾 MOBIBOSS TRANSACTION RECEIPT
────────────────────────
Network: ${till.network.name.toUpperCase()}
Type: $typeName
Amount: GHS ${formatNumber(tx.amount)}
Fee: GHS ${formatNumber(tx.fee)}
Customer: ${tx.customerPhone}
Ref: ${tx.reference}
Date: $dateStr
Till: ${till.tillName} (${till.simSlot})
Attendant: ${_activeTeller?.name ?? 'Main Attendant'}
Status: ${tx.status == TransactionStatus.completed ? 'CONFIRMED ✓' : tx.status.name.toUpperCase()}
────────────────────────
Thank you for transacting with us!''';
  }

  /// Calculates volume, inflow, outflow, and commissions grouped by carrier network
  Map<String, NetworkVolumeSummary> get networkVolumeSummaries {
    final Map<String, NetworkVolumeSummary> map = {
      NetworkProvider.mtn.name: NetworkVolumeSummary(network: NetworkProvider.mtn),
      NetworkProvider.telecel.name: NetworkVolumeSummary(network: NetworkProvider.telecel),
      NetworkProvider.at.name: NetworkVolumeSummary(network: NetworkProvider.at),
      NetworkProvider.gmoney.name: NetworkVolumeSummary(network: NetworkProvider.gmoney),
    };

    final activeRecords = filteredSmsRecords;
    if (activeRecords.isNotEmpty) {
      for (final r in activeRecords) {
        final current = map[r.network.name] ?? NetworkVolumeSummary(network: r.network);
        final comm = _calculateCommission(r.network, r.type, r.amount);

        double cashIn = current.cashInTotal;
        double cashOut = current.cashOutTotal;
        double airtime = current.airtimeTotal;
        double data = current.dataTotal;

        if (r.isReversed || r.type == TransactionType.reversal) {
          // Reversals do not add positive sales volume
        } else if (r.type == TransactionType.cashIn) {
          cashIn += r.amount;
        } else if (r.type == TransactionType.cashOut) {
          cashOut += r.amount;
        } else if (r.type == TransactionType.airtime) {
          airtime += r.amount;
        } else if (r.type == TransactionType.dataBundle) {
          data += r.amount;
        }

        map[r.network.name] = NetworkVolumeSummary(
          network: r.network,
          cashInTotal: cashIn,
          cashOutTotal: cashOut,
          airtimeTotal: airtime,
          dataTotal: data,
          commissionsTotal: current.commissionsTotal + (r.isReversed ? 0.0 : comm),
          txCount: current.txCount + 1,
        );
      }
    } else {
      for (final tx in currentShiftTransactions) {
        final current = map[tx.network.name] ?? NetworkVolumeSummary(network: tx.network);
        double cashIn = current.cashInTotal;
        double cashOut = current.cashOutTotal;
        double airtime = current.airtimeTotal;
        double data = current.dataTotal;

        if (tx.type == TransactionType.reversal) {
          // Ignore
        } else if (tx.type == TransactionType.cashIn) {
          cashIn += tx.amount;
        } else if (tx.type == TransactionType.cashOut) {
          cashOut += tx.amount;
        } else if (tx.type == TransactionType.airtime) {
          airtime += tx.amount;
        } else if (tx.type == TransactionType.dataBundle) {
          data += tx.amount;
        }

        map[tx.network.name] = NetworkVolumeSummary(
          network: tx.network,
          cashInTotal: cashIn,
          cashOutTotal: cashOut,
          airtimeTotal: airtime,
          dataTotal: data,
          commissionsTotal: current.commissionsTotal + tx.commission,
          txCount: current.txCount + 1,
        );
      }
    }
    return map;
  }

  /// Sends a WhatsApp-formatted audit report to the shop owner
  Future<bool> sendShiftSummaryToWhatsApp({required BuildContext context, ShiftRecord? shift}) async {
    String recipient = _shopProfile.ownerPhone.trim();
    if (recipient.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Owner WhatsApp number is not set. Please configure it in Settings.'),
            backgroundColor: Color(0xFFE37400),
          ),
        );
      }
      return false;
    }

    String message;
    if (shift != null) {
      message = WhatsAppService.formatShiftReport(
        shift: shift,
        shopProfile: _shopProfile,
        tellerName: _activeTeller?.name,
      );
    } else if (_lastReconciliation != null) {
      message = WhatsAppService.formatLiveReconciliationReport(
        result: _lastReconciliation!,
        shopProfile: _shopProfile,
        shiftNumber: currentShiftNumber,
        timeRangeDisplay: shiftTimeRangeDisplay,
        tellerName: _activeTeller?.name,
      );
    } else {
      return false;
    }

    return await WhatsAppService.sendWhatsAppReport(
      message: message,
      recipientPhone: recipient,
    );
  }

  /// Reconciles shift using active filtered SMS records and recorded transactions
  void reconcileShift({required double physicalCash, CashDenomination? denomination}) {
    double totalIn = 0;
    double totalOut = 0;
    double totalComm = 0;
    int reversalsCount = 0;

    final activeRecords = filteredSmsRecords;

    if (activeRecords.isNotEmpty) {
      for (final r in activeRecords) {
        if (r.isReversed || r.isVoided || r.type == TransactionType.reversal) {
          reversalsCount++;
          // When a transaction is reversed or voided by a reversal, its amount is not added as inflow/outflow
          continue;
        }

        final comm = _calculateCommission(r.network, r.type, r.amount);
        if (r.type == TransactionType.cashIn ||
            r.type == TransactionType.airtime ||
            r.type == TransactionType.dataBundle ||
            r.type == TransactionType.ecgElectricity ||
            r.type == TransactionType.ghanaWater ||
            r.type == TransactionType.payTv) {
          totalIn += r.amount;
        } else if (r.type == TransactionType.cashOut ||
            r.type == TransactionType.bankTransfer) {
          totalOut += r.amount;
        }
        totalComm += comm;
      }
    } else {
      final now = DateTime.now();
      final start = currentShiftStartTime;
      final periodTx = _transactions.where((tx) {
        switch (_reconciliationPeriod) {
          case 'shift':
            return tx.timestamp.isAfter(start);
          case 'today':
            return tx.timestamp.year == now.year &&
                tx.timestamp.month == now.month &&
                tx.timestamp.day == now.day;
          case 'all':
          default:
            return true;
        }
      }).toList();

      for (var tx in periodTx) {
        if (tx.isVoided || tx.status == TransactionStatus.reversed || tx.type == TransactionType.reversal) {
          reversalsCount++;
          continue;
        }

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
        totalComm += tx.commission;
      }
    }

    // Calculate petty cash expenses for the selected reconciliation period
    double periodPettyCash = 0;
    final now = DateTime.now();
    final start = currentShiftStartTime;
    for (final exp in _pettyCashExpenses) {
      bool include = false;
      switch (_reconciliationPeriod) {
        case 'shift':
          include = exp.timestamp.isAfter(start);
          break;
        case 'today':
          include = exp.timestamp.year == now.year &&
              exp.timestamp.month == now.month &&
              exp.timestamp.day == now.day;
          break;
        case 'all':
        default:
          include = true;
          break;
      }
      if (include) {
        periodPettyCash += exp.amount;
      }
    }

    final expectedCash = _initialDrawerOpeningBalance + totalIn - totalOut - periodPettyCash;
    final variance = physicalCash - expectedCash;

    String status = 'BALANCED';
    String diagnosis = 'All physical drawer funds match recorded POS transactions, airtime/data sales, and SIM float ledger.';
    if (periodPettyCash > 0) {
      diagnosis += ' Accounted for GHS ${formatNumber(periodPettyCash)} in petty cash shop expenses.';
    }
    if (reversalsCount > 0) {
      diagnosis += ' Auto-neutralized $reversalsCount reversed/voided transaction leg(s) from drawer balance.';
    }

    if (variance < -0.01) {
      status = 'SHORTAGE';
      diagnosis = 'Shortage of GHS ${variance.abs().toStringAsFixed(2)} in cash drawer! '
          'Check for unrecorded cash payouts, uncollected customer change, or unlogged petty cash.';
      if (reversalsCount > 0) {
        diagnosis += ' ($reversalsCount reversal(s) were auto-neutralized).';
      }
    } else if (variance > 0.01) {
      status = 'OVERAGE';
      diagnosis = 'Surplus of GHS ${variance.toStringAsFixed(2)} in cash drawer! '
          'Check for unrecorded cash-in deposits or received payments not yet logged.';
      if (reversalsCount > 0) {
        diagnosis += ' ($reversalsCount reversal(s) were auto-neutralized).';
      }
    }

    final breakdown = networkVolumeSummaries;

    _lastReconciliation = ReconciliationResult(
      physicalCashCount: physicalCash,
      expectedPhysicalCash: expectedCash,
      cashVariance: variance,
      totalCashIn: totalIn,
      totalCashOut: totalOut,
      totalPettyCash: periodPettyCash,
      totalCommissions: totalComm,
      status: status,
      aiDiagnosis: diagnosis,
      denomination: denomination ?? _cashDenomination,
      networkBreakdown: breakdown,
    );

    _currentCashInDrawer = physicalCash;
    StorageService.saveLastReconciliation(_lastReconciliation);
    StorageService.saveDrawerCash(physicalCash);
    notifyListeners();
  }

  bool _containsPaymentKeywords(String body) {
    final b = body.toLowerCase();
    final hasActionVerb = b.contains('payment received') ||
        b.contains('payment made') ||
        b.contains('cash in') ||
        b.contains('cash out') ||
        b.contains('cashout') ||
        b.contains('cashed out') ||
        b.contains('you have received') ||
        b.contains('you have sent') ||
        b.contains('transferred to') ||
        b.contains('paid to') ||
        b.contains('recharge successful') ||
        b.contains('bundle purchased');

    final isNotErrorOrPromo = !b.contains('invalid mmi') &&
        !b.contains('connection problem') &&
        !b.contains('try our new momo app') &&
        !b.contains('promotional');

    return hasActionVerb && isNotErrorOrPromo;
  }

  void _autoUpdateContact(String phone, NetworkProvider network) {
    if (phone.isEmpty || phone.length < 9) return;
    final index = _customerContacts.indexWhere((c) => c.phone == phone);
    if (index >= 0) {
      final existing = _customerContacts[index];
      final updated = CustomerContact(
        id: existing.id,
        name: existing.name,
        phone: existing.phone,
        network: existing.network,
        totalTransactions: existing.totalTransactions + 1,
        lastTransacted: DateTime.now(),
      );
      _customerContacts[index] = updated;
      DbService.insertContact(updated);
    } else {
      final newContact = CustomerContact(
        id: _uuid.v4(),
        name: 'Customer $phone',
        phone: phone,
        network: network,
        totalTransactions: 1,
        lastTransacted: DateTime.now(),
      );
      _customerContacts.insert(0, newContact);
      DbService.insertContact(newContact);
    }
  }

  double _calculateCommission(NetworkProvider network, TransactionType type, double amount) {
    final rate = _commissionSettings.getRateFor(network, type);
    if (type == TransactionType.ecgElectricity || type == TransactionType.ghanaWater || type == TransactionType.payTv) {
      return rate;
    }
    return amount * rate;
  }

  void _handleUssdCallback(Map<String, dynamic> data) {
    final raw = data['rawResponse'] as String? ?? '';
    final isSuccess = data['isSuccess'] as bool? ?? false;
    if (isSuccess && raw.isNotEmpty) {
      final parsed = SmsParserService.parse(raw, sender: selectedTill.network.name.toUpperCase());
      if (parsed != null) {
        _autoRecordConfirmedTransaction(parsed);
      }
    }
  }

  void _handleIncomingSms(Map<String, dynamic> data) {
    final sender = data['sender'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final ts = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final parsed = SmsParserService.parse(body, sender: sender, timestamp: DateTime.fromMillisecondsSinceEpoch(ts));
    if (parsed != null) {
      _autoRecordConfirmedTransaction(parsed);
      _autoUpdateContact(parsed.customerPhone, parsed.network);
    }
  }

  void checkRecentCarrierSms() {}
}

class SenderInfo {
  final String address;
  final int totalMessages;
  final int parsedTransactions;
  final String category;

  SenderInfo({
    required this.address,
    required this.totalMessages,
    required this.parsedTransactions,
    required this.category,
  });
}

class DailyPerformance {
  final String dayLabel;
  final DateTime date;
  final double volume;
  final double commission;
  final int transactionCount;

  DailyPerformance({
    required this.dayLabel,
    required this.date,
    required this.volume,
    required this.commission,
    required this.transactionCount,
  });
}

typedef MobiBossProvider = MoMoProvider;
