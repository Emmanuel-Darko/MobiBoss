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

  // Smart sender discovery
  final Map<String, SenderInfo> _discoveredSenders = {};
  final Set<String> _selectedSenders = {};
  bool _isScanningInbox = false;
  String _reconciliationPeriod = 'today'; // today, shift, 24h, all

  // Getters
  double get currentCashInDrawer => _currentCashInDrawer;
  double get initialDrawerOpeningBalance => _initialDrawerOpeningBalance;
  List<Till> get tills => List.unmodifiable(_tills);
  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  List<SmsRecord> get smsRecords => List.unmodifiable(_smsRecords);
  List<ShiftRecord> get shiftHistory => List.unmodifiable(_shiftHistory);
  List<CustomerContact> get customerContacts => List.unmodifiable(_customerContacts);
  CommissionSettings get commissionSettings => _commissionSettings;
  Map<String, SenderInfo> get discoveredSenders => Map.unmodifiable(_discoveredSenders);
  Set<String> get selectedSenders => Set.unmodifiable(_selectedSenders);
  bool get isScanningInbox => _isScanningInbox;
  ReconciliationResult? get lastReconciliation => _lastReconciliation;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  bool get isBalancePrivacyEnabled => _isBalancePrivacyEnabled;
  bool get isAppLockEnabled => _isAppLockEnabled;
  ThemeMode get themeMode => _themeMode;
  String get reconciliationPeriod => _reconciliationPeriod;
  double get dailyCommissionTarget => _dailyCommissionTarget;
  double get monthlyCommissionTarget => _monthlyCommissionTarget;

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

  double get expectedDrawerCash => _initialDrawerOpeningBalance + todayInflow - todayOutflow - todayPettyCashTotal;
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
    return _smsRecords.where((sms) {
      if (_selectedSenders.isNotEmpty &&
          !_selectedSenders.contains(sms.sender.toUpperCase())) {
        return false;
      }
      switch (_reconciliationPeriod) {
        case 'today':
          return sms.timestamp.year == now.year &&
              sms.timestamp.month == now.month &&
              sms.timestamp.day == now.day;
        case 'shift':
          return now.difference(sms.timestamp).inHours <= 8;
        case '24h':
          return now.difference(sms.timestamp).inHours <= 24;
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
    recalculateReconciliation();
    notifyListeners();
  }

  Future<void> checkAccessibilityState() async {
    _isAccessibilityEnabled = await UssdService.isAccessibilityEnabled();
    notifyListeners();
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
  }) async {
    reconcileShift(physicalCash: countedCash);
    final rec = _lastReconciliation!;

    final now = DateTime.now();
    final periodTx = _transactions.where((tx) {
      if (_shiftHistory.isEmpty) return true;
      return tx.timestamp.isAfter(_shiftHistory.first.endTime);
    }).toList();

    final shift = ShiftRecord(
      id: _uuid.v4(),
      shiftNumber: currentShiftNumber,
      startTime: _shiftHistory.isNotEmpty ? _shiftHistory.first.endTime : now.subtract(const Duration(hours: 8)),
      endTime: now,
      openingCash: _initialDrawerOpeningBalance,
      closingCash: countedCash,
      expectedCash: rec.expectedPhysicalCash,
      cashVariance: rec.cashVariance,
      totalCashIn: rec.totalCashIn,
      totalCashOut: rec.totalCashOut,
      totalCommissions: rec.totalCommissions,
      transactionCount: periodTx.isNotEmpty ? periodTx.length : _transactions.length,
      status: rec.status,
      aiDiagnosis: rec.aiDiagnosis,
    );

    _shiftHistory.insert(0, shift);
    await DbService.insertShift(shift);

    // Carry forward closing cash to new shift opening balance
    _initialDrawerOpeningBalance = countedCash;
    _currentCashInDrawer = countedCash;
    await StorageService.saveDrawerCash(countedCash);

    recalculateReconciliation();
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
    recalculateReconciliation();
    notifyListeners();
  }

  void toggleSenderSelection(String sender) {
    final key = sender.toUpperCase();
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

      int totalParsed = 0;

      for (final entry in senderMessages.entries) {
        final senderAddr = entry.key;
        final msgs = entry.value;
        int parsedCount = 0;
        String category = 'unknown';

        for (final msg in msgs) {
          final body = (msg.body ?? '').trim();
          final isKnownSender = SmsParserService.isMoMoSender(senderAddr);
          final hasPaymentKeywords = _containsPaymentKeywords(body);

          if (isKnownSender || hasPaymentKeywords) {
            final parsed = SmsParserService.parse(body, sender: senderAddr, timestamp: msg.date);
            if (parsed != null) {
              final isDup = _smsRecords.any((r) => r.reference == parsed.reference);
              if (!isDup) {
                _smsRecords.add(parsed);
                _autoRecordConfirmedTransaction(parsed);
                _autoUpdateContact(parsed.customerPhone, parsed.network);
                parsedCount++;
                totalParsed++;
              }
            }
          }
        }

        if (parsedCount > 0) {
          final lowerAddr = senderAddr.toLowerCase();
          if (lowerAddr.contains('mtn') || lowerAddr.contains('mobilemoney') || lowerAddr == '171') {
            category = 'MoMo';
          } else if (lowerAddr.contains('telecel') || lowerAddr.contains('vodafone') || lowerAddr == '110') {
            category = 'MoMo';
          } else if (lowerAddr.contains('atmoney') || lowerAddr.contains('airteltigo')) {
            category = 'MoMo';
          } else if (lowerAddr.contains('gmoney') || lowerAddr.contains('gcb')) {
            category = 'FinTech';
          } else if (lowerAddr.contains('bank') || lowerAddr.contains('fidelity') ||
              lowerAddr.contains('ecobank') || lowerAddr.contains('stanbic') ||
              lowerAddr.contains('absa') || lowerAddr.contains('zenith')) {
            category = 'Bank';
          } else {
            category = 'Other';
          }

          _discoveredSenders[senderAddr] = SenderInfo(
            address: senderAddr,
            totalMessages: msgs.length,
            parsedTransactions: parsedCount,
            category: category,
          );

          if (category == 'MoMo') {
            _selectedSenders.add(senderAddr);
          }
        }
      }

      if (_selectedSenders.isEmpty && _discoveredSenders.isNotEmpty) {
        _selectedSenders.addAll(_discoveredSenders.keys);
      }

      _isScanningInbox = false;
      recalculateReconciliation();
      notifyListeners();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Found ${_discoveredSenders.length} payment providers with $totalParsed confirmed transactions.',
          ),
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

  /// Automatically records confirmed transactions into the ledger and updates float/drawer
  Future<void> _autoRecordConfirmedTransaction(SmsRecord sms) async {
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
        }
        updatedTill = t.copyWith(currentFloat: newFloat);
        return updatedTill!;
      }
      return t;
    }).toList();

    if (updatedTill != null) {
      await DbService.updateTill(updatedTill!);
    }
  }

  /// Reconciles shift using active filtered SMS records and recorded transactions
  void reconcileShift({required double physicalCash}) {
    double totalIn = 0;
    double totalOut = 0;
    double totalComm = 0;

    final activeRecords = filteredSmsRecords;

    if (activeRecords.isNotEmpty) {
      for (final r in activeRecords) {
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
      final periodTx = _transactions.where((tx) {
        switch (_reconciliationPeriod) {
          case 'today':
            return tx.timestamp.year == now.year &&
                tx.timestamp.month == now.month &&
                tx.timestamp.day == now.day;
          case 'shift':
            return now.difference(tx.timestamp).inHours <= 8;
          case '24h':
            return now.difference(tx.timestamp).inHours <= 24;
          case 'all':
          default:
            return true;
        }
      }).toList();

      for (var tx in periodTx) {
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
    for (final exp in _pettyCashExpenses) {
      bool include = false;
      switch (_reconciliationPeriod) {
        case 'today':
          include = exp.timestamp.year == now.year &&
              exp.timestamp.month == now.month &&
              exp.timestamp.day == now.day;
          break;
        case 'shift':
          include = now.difference(exp.timestamp).inHours <= 8;
          break;
        case '24h':
          include = now.difference(exp.timestamp).inHours <= 24;
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

    if (variance < -0.01) {
      status = 'SHORTAGE';
      diagnosis = 'Shortage of GHS ${variance.abs().toStringAsFixed(2)} in cash drawer! '
          'Check for unrecorded cash payouts, uncollected customer change, or unlogged petty cash.';
    } else if (variance > 0.01) {
      status = 'OVERAGE';
      diagnosis = 'Surplus of GHS ${variance.toStringAsFixed(2)} in cash drawer! '
          'Check for unrecorded cash-in deposits or received payments not yet logged.';
    }

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
