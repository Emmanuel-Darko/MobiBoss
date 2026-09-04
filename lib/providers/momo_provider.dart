import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/momo_models.dart';
import '../services/sms_parser_service.dart';
import '../services/storage_service.dart';
import '../services/ussd_service.dart';

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

  int get currentShiftNumber => _shiftHistory.length + 1;

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
    // 1. Load persisted data
    final savedTills = await StorageService.loadTills();
    if (savedTills != null && savedTills.isNotEmpty) {
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
      await StorageService.saveTills(_tills);
    }

    final savedTransactions = await StorageService.loadTransactions();
    if (savedTransactions.isNotEmpty) {
      _transactions = savedTransactions;
    }

    final savedCash = await StorageService.loadDrawerCash();
    if (savedCash != null) {
      _currentCashInDrawer = savedCash;
      _initialDrawerOpeningBalance = savedCash;
    }

    _lastReconciliation = await StorageService.loadLastReconciliation();
    _dailyCommissionTarget = await StorageService.loadDailyTarget();
    _monthlyCommissionTarget = await StorageService.loadMonthlyTarget();
    _shiftHistory = await StorageService.loadShiftHistory();
    _customerContacts = await StorageService.loadCustomerContacts();
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

    // 2. Initialize Real-Time USSD & SMS Broadcast Callback Listeners
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
  void addCustomTill(Till till) {
    _tills.add(till);
    StorageService.saveTills(_tills);
    notifyListeners();
  }

  void updateTill(Till updated) {
    _tills = _tills.map((t) => t.id == updated.id ? updated : t).toList();
    StorageService.saveTills(_tills);
    notifyListeners();
  }

  void deleteTill(String tillId) {
    _tills.removeWhere((t) => t.id == tillId);
    if (_selectedTillId == tillId && _tills.isNotEmpty) {
      _selectedTillId = _tills.first.id;
    }
    StorageService.saveTills(_tills);
    notifyListeners();
  }

  // ─── Customer Contacts ───
  void saveContact(CustomerContact contact) {
    final index = _customerContacts.indexWhere((c) => c.phone == contact.phone);
    if (index >= 0) {
      _customerContacts[index] = contact;
    } else {
      _customerContacts.insert(0, contact);
    }
    StorageService.saveCustomerContacts(_customerContacts);
    notifyListeners();
  }

  void deleteContact(String id) {
    _customerContacts.removeWhere((c) => c.id == id);
    StorageService.saveCustomerContacts(_customerContacts);
    notifyListeners();
  }

  // ─── Shift Closing & EOD Settlement ───
  ShiftRecord closeCurrentShift({
    required double countedCash,
    required BuildContext context,
  }) {
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
    StorageService.saveShiftHistory(_shiftHistory);

    // Carry forward closing cash to new shift opening balance
    _initialDrawerOpeningBalance = countedCash;
    _currentCashInDrawer = countedCash;
    StorageService.saveDrawerCash(countedCash);

    recalculateReconciliation();
    notifyListeners();
    return shift;
  }

  // ─── CSV Export ───
  String exportLedgerToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Reference,Network,Type,Amount (GHS),Fee (GHS),Commission (GHS),Customer Phone,Till ID,Status,Timestamp');
    for (final tx in _transactions) {
      buffer.writeln(
        '"${tx.id}","${tx.reference}","${tx.network.name.toUpperCase()}","${tx.type.name}","${tx.amount}","${tx.fee}","${tx.commission}","${tx.customerPhone}","${tx.tillId}","${tx.status.name}","${tx.timestamp.toIso8601String()}"',
      );
    }
    return buffer.toString();
  }

  /// Real-time callback triggered the instant an SMS arrives on the device via BroadcastReceiver
  void _handleIncomingSms(Map<String, dynamic> data) {
    final sender = (data['sender'] as String? ?? '').trim();
    final body = (data['body'] as String? ?? '').trim();
    final timestampMs = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

    if (sender.isEmpty || body.isEmpty) return;

    if (SmsParserService.isMoMoSender(sender) || _containsPaymentKeywords(body)) {
      final parsed = SmsParserService.parse(body, sender: sender, timestamp: timestamp);
      if (parsed != null) {
        final isDup = _transactions.any((t) => t.reference == parsed.reference);
        if (!isDup) {
          _smsRecords.insert(0, parsed);
          _autoRecordConfirmedTransaction(parsed);
          _autoUpdateContact(parsed.customerPhone, parsed.network);
          recalculateReconciliation();
          notifyListeners();
        }
      }
    }
  }

  void _autoUpdateContact(String phone, NetworkProvider network) {
    if (phone.isEmpty || phone.length < 9) return;
    final existingIndex = _customerContacts.indexWhere((c) => c.phone == phone);
    if (existingIndex >= 0) {
      final old = _customerContacts[existingIndex];
      _customerContacts[existingIndex] = CustomerContact(
        id: old.id,
        name: old.name,
        phone: old.phone,
        network: old.network,
        totalTransactions: old.totalTransactions + 1,
        lastTransacted: DateTime.now(),
      );
    } else {
      _customerContacts.insert(
        0,
        CustomerContact(
          id: _uuid.v4(),
          name: 'Customer $phone',
          phone: phone,
          network: network,
          totalTransactions: 1,
          lastTransacted: DateTime.now(),
        ),
      );
    }
    StorageService.saveCustomerContacts(_customerContacts);
  }

  /// Starts an active listening window after a USSD session finishes, polling for delayed carrier SMS
  void startPostSessionSmsWatcher() {
    final checkIntervals = [3, 8, 15, 30, 60];
    for (final seconds in checkIntervals) {
      Future.delayed(Duration(seconds: seconds), () {
        checkRecentCarrierSms();
      });
    }
  }

  /// Real-time callback triggered when the USSD session finishes with a telecom confirmation
  void _handleUssdCallback(Map<String, dynamic> data) {
    final rawResponse = data['rawResponse'] as String? ?? '';
    final isSuccess = data['isSuccess'] as bool? ?? true;

    if (rawResponse.isEmpty || !isSuccess) return;

    // 1. If the USSD response contains a balance inquiry result, update the selected till's float
    final balance = SmsParserService.extractBalanceOnly(rawResponse);
    if (balance != null && balance > 0) {
      updateTillFloat(selectedTill.id, balance);
    }

    // 2. ONLY record a transaction if it contains an explicit completed transaction verb
    final parsed = SmsParserService.parse(rawResponse, sender: 'USSD_CONFIRMED');
    if (parsed != null) {
      final isDuplicate = _transactions.any((t) => t.reference == parsed.reference);
      if (!isDuplicate) {
        _smsRecords.insert(0, parsed);
        _autoRecordConfirmedTransaction(parsed);
        _autoUpdateContact(parsed.customerPhone, parsed.network);
        recalculateReconciliation();
        notifyListeners();
      }
    }

    // 3. Start automated watcher window for delayed carrier SMS
    startPostSessionSmsWatcher();
  }

  /// Checks for any newly received carrier SMS
  Future<void> checkRecentCarrierSms() async {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) return;

      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 10,
      );

      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));

      for (final msg in messages) {
        if (msg.date != null && msg.date!.isBefore(cutoff)) continue;
        final sender = (msg.address ?? '').trim();
        final body = (msg.body ?? '').trim();
        if (sender.isEmpty || body.isEmpty) continue;

        if (SmsParserService.isMoMoSender(sender) || _containsPaymentKeywords(body)) {
          final parsed = SmsParserService.parse(body, sender: sender, timestamp: msg.date);
          if (parsed != null) {
            final isDup = _transactions.any((t) => t.reference == parsed.reference);
            if (!isDup) {
              _smsRecords.insert(0, parsed);
              _autoRecordConfirmedTransaction(parsed);
              _autoUpdateContact(parsed.customerPhone, parsed.network);
              recalculateReconciliation();
              notifyListeners();
            }
          }
        }
      }
    } catch (_) {}
  }

  void selectTill(String tillId) {
    _selectedTillId = tillId;
    notifyListeners();
  }

  void updateDrawerCash(double amount) {
    _currentCashInDrawer = amount;
    StorageService.saveDrawerCash(amount);
    recalculateReconciliation();
    notifyListeners();
  }

  void updateTillFloat(String tillId, double newFloat) {
    _tills = _tills.map((t) {
      if (t.id == tillId) {
        return t.copyWith(currentFloat: newFloat);
      }
      return t;
    }).toList();
    StorageService.saveTills(_tills);
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
  void _autoRecordConfirmedTransaction(SmsRecord sms) {
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
    StorageService.saveTransactions(_transactions);
    _applyBalanceImpact(matchingTill.id, sms.type, sms.amount, postBalance: sms.postBalance);
  }

  void _applyBalanceImpact(String tillId, TransactionType type, double amount, {double? postBalance}) {
    _tills = _tills.map((t) {
      if (t.id == tillId) {
        if (postBalance != null && postBalance > 0) {
          return t.copyWith(currentFloat: postBalance);
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
        return t.copyWith(currentFloat: newFloat);
      }
      return t;
    }).toList();

    StorageService.saveTills(_tills);
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

    final expectedCash = _initialDrawerOpeningBalance + totalIn - totalOut;
    final variance = physicalCash - expectedCash;

    String status = 'BALANCED';
    String diagnosis = 'All physical drawer funds match recorded POS transactions, airtime/data sales, and SIM float ledger for the selected period.';

    if (variance < -0.01) {
      status = 'SHORTAGE';
      diagnosis = 'Shortage of GHS ${variance.abs().toStringAsFixed(2)} in cash drawer! '
          'Check for unrecorded cash payouts, uncollected customer change, or transactions outside the scanned SMS period.';
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
        !b.contains('unlock more deals');

    return hasActionVerb && isNotErrorOrPromo;
  }

  double _calculateCommission(NetworkProvider network, TransactionType type, double amount) {
    final rateOrFee = _commissionSettings.getRateFor(network, type);
    switch (type) {
      case TransactionType.cashIn:
      case TransactionType.cashOut:
      case TransactionType.airtime:
      case TransactionType.dataBundle:
      case TransactionType.bankTransfer:
        return amount * rateOrFee;
      case TransactionType.ecgElectricity:
      case TransactionType.ghanaWater:
      case TransactionType.payTv:
        return rateOrFee;
      case TransactionType.floatTransfer:
        return 0.0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ─── COMMISSIONS & ANALYTICS HELPER GETTERS ──────────────
  // ═══════════════════════════════════════════════════════════

  double get todayCommission {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.timestamp.year == now.year &&
            t.timestamp.month == now.month &&
            t.timestamp.day == now.day)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  double get weeklyCommission {
    final now = DateTime.now();
    return _transactions
        .where((t) => now.difference(t.timestamp).inDays <= 7)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  double get monthlyCommission {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.timestamp.year == now.year && t.timestamp.month == now.month)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  double get totalCommission {
    return _transactions.fold(0.0, (sum, t) => sum + t.commission);
  }

  Map<NetworkProvider, double> get commissionsByNetwork {
    final Map<NetworkProvider, double> map = {
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

  Map<TransactionType, double> get commissionsByService {
    final Map<TransactionType, double> map = {};
    for (final tx in _transactions) {
      map[tx.type] = (map[tx.type] ?? 0.0) + tx.commission;
    }
    return map;
  }

  /// Weekly daily breakdown for bar charts (last 7 days)
  List<DailyPerformance> get last7DaysPerformance {
    final now = DateTime.now();
    final List<DailyPerformance> list = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayTx = _transactions.where((t) =>
          t.timestamp.year == date.year &&
          t.timestamp.month == date.month &&
          t.timestamp.day == date.day);

      final totalVolume = dayTx.fold(0.0, (sum, t) => sum + t.amount);
      final totalComm = dayTx.fold(0.0, (sum, t) => sum + t.commission);
      final txCount = dayTx.length;

      final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final label = dayLabels[date.weekday - 1];

      list.add(DailyPerformance(
        dayLabel: label,
        date: date,
        volume: totalVolume,
        commission: totalComm,
        transactionCount: txCount,
      ));
    }
    return list;
  }

  Future<void> syncQueue(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All confirmed transactions are in sync.'),
        backgroundColor: Color(0xFF1E8E3E),
      ),
    );
  }
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
