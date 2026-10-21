import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mobiboss_models.dart';

class DbService {
  static Database? _db;
  static const String _dbName = 'mobiboss.db';
  static const int _dbVersion = 3;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE closed_shifts ADD COLUMN denomination TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN isVoided INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN voidedByReversalId TEXT');
          } catch (_) {}
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            tillId TEXT,
            network TEXT,
            type TEXT,
            amount REAL,
            fee REAL,
            commission REAL,
            customerPhone TEXT,
            reference TEXT,
            ussdString TEXT,
            timestamp TEXT,
            status TEXT,
            isVoided INTEGER DEFAULT 0,
            voidedByReversalId TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE tills (
            id TEXT PRIMARY KEY,
            network TEXT,
            tillName TEXT,
            tillNumber TEXT,
            simSlot TEXT,
            currentFloat REAL,
            minFloatAlert REAL,
            ussdPrefix TEXT,
            agentCode TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE petty_cash (
            id TEXT PRIMARY KEY,
            amount REAL,
            category TEXT,
            note TEXT,
            tellerName TEXT,
            timestamp TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE tellers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            pinHash TEXT,
            role TEXT,
            isActive INTEGER,
            createdAt TEXT,
            lastShiftStartedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE shift_handovers (
            id TEXT PRIMARY KEY,
            outgoingTellerName TEXT,
            incomingTellerName TEXT,
            handoverTime TEXT,
            countedDrawerCash REAL,
            expectedDrawerCash REAL,
            cashVariance REAL,
            shiftTransactionCount INTEGER,
            shiftVolume REAL,
            shiftCommissions REAL,
            shiftPettyCashSpent REAL,
            notes TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE custom_ussd_rules (
            id TEXT PRIMARY KEY,
            network TEXT,
            transactionType TEXT,
            customRootCode TEXT,
            customSteps TEXT,
            isEnabled INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE closed_shifts (
            id TEXT PRIMARY KEY,
            shiftNumber INTEGER,
            startTime TEXT,
            endTime TEXT,
            openingCash REAL,
            closingCash REAL,
            expectedCash REAL,
            cashVariance REAL,
            totalCashIn REAL,
            totalCashOut REAL,
            totalCommissions REAL,
            transactionCount INTEGER,
            status TEXT,
            aiDiagnosis TEXT,
            denomination TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE contacts (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            network TEXT,
            totalTransactions INTEGER,
            lastTransacted TEXT
          )
        ''');
      },
    );

    // Auto-heal table if columns are missing in existing database files
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN isVoided INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN voidedByReversalId TEXT');
    } catch (_) {}

    return db;
  }

  // ==========================================
  // MIGRATION FROM SHAREDPREFERENCES
  // ==========================================
  static Future<void> checkAndMigrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isMigrated = prefs.getBool('sqlite_migrated_v1') ?? false;
    if (isMigrated) return;

    // Migrate transactions
    final txJson = prefs.getString('momo_transactions');
    if (txJson != null) {
      try {
        final List list = jsonDecode(txJson);
        for (var item in list) {
          final tx = TransactionRecord.fromJson(item as Map<String, dynamic>);
          await insertTransaction(tx);
        }
      } catch (_) {}
    }

    // Migrate tills
    final tillsJson = prefs.getString('momo_tills');
    if (tillsJson != null) {
      try {
        final List list = jsonDecode(tillsJson);
        for (var item in list) {
          final till = Till.fromJson(item as Map<String, dynamic>);
          await insertTill(till);
        }
      } catch (_) {}
    }

    // Migrate contacts
    final contactsJson = prefs.getString('momo_contacts');
    if (contactsJson != null) {
      try {
        final List list = jsonDecode(contactsJson);
        for (var item in list) {
          final contact = CustomerContact.fromJson(item as Map<String, dynamic>);
          await insertContact(contact);
        }
      } catch (_) {}
    }

    // Migrate closed shifts
    final shiftsJson = prefs.getString('momo_closed_shifts');
    if (shiftsJson != null) {
      try {
        final List list = jsonDecode(shiftsJson);
        for (var item in list) {
          final s = ShiftRecord.fromJson(item as Map<String, dynamic>);
          await insertShift(s);
        }
      } catch (_) {}
    }

    await prefs.setBool('sqlite_migrated_v1', true);
  }

  // ==========================================
  // TRANSACTIONS
  // ==========================================
  static Future<void> insertTransaction(TransactionRecord tx) async {
    final db = await database;
    final map = Map<String, dynamic>.from(tx.toJson());
    map['isVoided'] = tx.isVoided ? 1 : 0;
    await db.insert(
      'transactions',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TransactionRecord>> getTransactions({
    int limit = 200,
    String? searchQuery,
    String? tillId,
    TransactionType? type,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(customerPhone LIKE ? OR reference LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    if (tillId != null && tillId.isNotEmpty) {
      conditions.add('tillId = ?');
      args.add(tillId);
    }

    if (type != null) {
      conditions.add('type = ?');
      args.add(type.name);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((m) => TransactionRecord.fromJson(m)).toList();
  }

  // ==========================================
  // TILLS
  // ==========================================
  static Future<void> insertTill(Till till) async {
    final db = await database;
    await db.insert('tills', till.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Till>> getTills() async {
    final db = await database;
    final maps = await db.query('tills');
    return maps.map((m) => Till.fromJson(m)).toList();
  }

  static Future<void> updateTill(Till till) async {
    final db = await database;
    await db.update('tills', till.toJson(), where: 'id = ?', whereArgs: [till.id]);
  }

  // ==========================================
  // PETTY CASH / EXPENSES
  // ==========================================
  static Future<void> insertPettyCash(PettyCashExpense expense) async {
    final db = await database;
    await db.insert('petty_cash', expense.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<PettyCashExpense>> getPettyCashExpenses({DateTime? since}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (since != null) {
      where = 'timestamp >= ?';
      whereArgs = [since.toIso8601String()];
    }

    final maps = await db.query('petty_cash', where: where, whereArgs: whereArgs, orderBy: 'timestamp DESC');
    return maps.map((m) => PettyCashExpense.fromJson(m)).toList();
  }

  static Future<void> deletePettyCash(String id) async {
    final db = await database;
    await db.delete('petty_cash', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // TELLERS
  // ==========================================
  static Future<void> insertTeller(Teller teller) async {
    final db = await database;
    await db.insert('tellers', {
      'id': teller.id,
      'name': teller.name,
      'phone': teller.phone,
      'pinHash': teller.pinHash,
      'role': teller.role.name,
      'isActive': teller.isActive ? 1 : 0,
      'createdAt': teller.createdAt.toIso8601String(),
      'lastShiftStartedAt': teller.lastShiftStartedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Teller>> getTellers() async {
    final db = await database;
    final maps = await db.query('tellers');
    return maps.map((m) {
      return Teller(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String? ?? '',
        pinHash: m['pinHash'] as String? ?? '',
        role: TellerRole.values.byName(m['role'] as String? ?? 'attendant'),
        isActive: (m['isActive'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(m['createdAt'] as String),
        lastShiftStartedAt: m['lastShiftStartedAt'] != null
            ? DateTime.parse(m['lastShiftStartedAt'] as String)
            : null,
      );
    }).toList();
  }

  static Future<void> updateTeller(Teller teller) async {
    final db = await database;
    await db.update('tellers', {
      'name': teller.name,
      'phone': teller.phone,
      'pinHash': teller.pinHash,
      'role': teller.role.name,
      'isActive': teller.isActive ? 1 : 0,
      'lastShiftStartedAt': teller.lastShiftStartedAt?.toIso8601String(),
    }, where: 'id = ?', whereArgs: [teller.id]);
  }

  // ==========================================
  // SHIFT HANDOVERS
  // ==========================================
  static Future<void> insertShiftHandover(ShiftHandover handover) async {
    final db = await database;
    await db.insert('shift_handovers', handover.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<ShiftHandover>> getShiftHandovers({int limit = 50}) async {
    final db = await database;
    final maps = await db.query('shift_handovers', orderBy: 'handoverTime DESC', limit: limit);
    return maps.map((m) => ShiftHandover.fromJson(m)).toList();
  }

  // ==========================================
  // CUSTOM USSD RULES
  // ==========================================
  static Future<void> insertCustomUssdRule(CustomUssdRule rule) async {
    final db = await database;
    await db.insert('custom_ussd_rules', {
      'id': rule.id,
      'network': rule.network.name,
      'transactionType': rule.transactionType.name,
      'customRootCode': rule.customRootCode,
      'customSteps': jsonEncode(rule.customSteps),
      'isEnabled': rule.isEnabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<CustomUssdRule>> getCustomUssdRules() async {
    final db = await database;
    final maps = await db.query('custom_ussd_rules');
    return maps.map((m) {
      return CustomUssdRule(
        id: m['id'] as String,
        network: NetworkProvider.values.byName(m['network'] as String),
        transactionType: TransactionType.values.byName(m['transactionType'] as String),
        customRootCode: m['customRootCode'] as String,
        customSteps: List<String>.from(jsonDecode(m['customSteps'] as String) as List),
        isEnabled: (m['isEnabled'] as int? ?? 1) == 1,
      );
    }).toList();
  }

  static Future<void> deleteCustomUssdRule(String id) async {
    final db = await database;
    await db.delete('custom_ussd_rules', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // CLOSED SHIFTS / SETTLEMENTS
  // ==========================================
  static Future<void> insertShift(ShiftRecord s) async {
    final db = await database;
    final map = s.toJson();
    if (map['denomination'] != null && map['denomination'] is! String) {
      map['denomination'] = jsonEncode(map['denomination']);
    }
    await db.insert('closed_shifts', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<ShiftRecord>> getClosedShifts({int limit = 100, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'closed_shifts',
      orderBy: 'endTime DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => ShiftRecord.fromJson(m)).toList();
  }

  static Future<List<ShiftRecord>> getShiftsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'closed_shifts',
      where: 'endTime >= ? AND endTime <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'endTime DESC',
    );
    return maps.map((m) => ShiftRecord.fromJson(m)).toList();
  }

  static Future<int> getShiftCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM closed_shifts');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==========================================
  // CONTACTS
  // ==========================================
  static Future<void> insertContact(CustomerContact contact) async {
    final db = await database;
    await db.insert('contacts', contact.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<CustomerContact>> getContacts() async {
    final db = await database;
    final maps = await db.query('contacts', orderBy: 'totalTransactions DESC');
    return maps.map((m) => CustomerContact.fromJson(m)).toList();
  }
}
