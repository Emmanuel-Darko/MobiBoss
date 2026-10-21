import 'dart:convert';

enum NetworkProvider { mtn, telecel, at, gmoney }

enum TransactionType {
  cashIn,
  cashOut,
  airtime,
  dataBundle,
  floatTransfer,
  ecgElectricity,
  ghanaWater,
  payTv,
  bankTransfer,
  reversal,
}

class ShopProfile {
  final String shopName;
  final String ownerName;
  final String ownerPhone;
  final String branchLocation;
  final String currencySymbol;

  ShopProfile({
    this.shopName = 'MobiBoss Agent Shop',
    this.ownerName = 'Shop Owner',
    this.ownerPhone = '',
    this.branchLocation = 'Main Kiosk',
    this.currencySymbol = 'GHS',
  });

  ShopProfile copyWith({
    String? shopName,
    String? ownerName,
    String? ownerPhone,
    String? branchLocation,
    String? currencySymbol,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      branchLocation: branchLocation ?? this.branchLocation,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'branchLocation': branchLocation,
        'currencySymbol': currencySymbol,
      };

  factory ShopProfile.fromJson(Map<String, dynamic> json) => ShopProfile(
        shopName: json['shopName'] as String? ?? 'MobiBoss Agent Shop',
        ownerName: json['ownerName'] as String? ?? 'Shop Owner',
        ownerPhone: json['ownerPhone'] as String? ?? '',
        branchLocation: json['branchLocation'] as String? ?? 'Main Kiosk',
        currencySymbol: json['currencySymbol'] as String? ?? 'GHS',
      );
}

class NetworkVolumeSummary {
  final NetworkProvider network;
  final double cashInTotal;
  final double cashOutTotal;
  final double airtimeTotal;
  final double dataTotal;
  final double commissionsTotal;
  final int txCount;

  NetworkVolumeSummary({
    required this.network,
    this.cashInTotal = 0.0,
    this.cashOutTotal = 0.0,
    this.airtimeTotal = 0.0,
    this.dataTotal = 0.0,
    this.commissionsTotal = 0.0,
    this.txCount = 0,
  });

  double get netVolume => cashInTotal + cashOutTotal + airtimeTotal + dataTotal;

  Map<String, dynamic> toJson() => {
        'network': network.name,
        'cashInTotal': cashInTotal,
        'cashOutTotal': cashOutTotal,
        'airtimeTotal': airtimeTotal,
        'dataTotal': dataTotal,
        'commissionsTotal': commissionsTotal,
        'txCount': txCount,
      };

  factory NetworkVolumeSummary.fromJson(Map<String, dynamic> json) =>
      NetworkVolumeSummary(
        network: NetworkProvider.values.byName(json['network'] as String),
        cashInTotal: (json['cashInTotal'] as num?)?.toDouble() ?? 0.0,
        cashOutTotal: (json['cashOutTotal'] as num?)?.toDouble() ?? 0.0,
        airtimeTotal: (json['airtimeTotal'] as num?)?.toDouble() ?? 0.0,
        dataTotal: (json['dataTotal'] as num?)?.toDouble() ?? 0.0,
        commissionsTotal: (json['commissionsTotal'] as num?)?.toDouble() ?? 0.0,
        txCount: (json['txCount'] as num?)?.toInt() ?? 0,
      );
}

enum TransactionStatus { completed, pending, failed, offlineQueued, reversed }

class Till {
  final String id;
  final NetworkProvider network;
  final String tillName;
  final String tillNumber;
  final String simSlot;
  final double currentFloat;
  final double minFloatAlert;
  final String ussdPrefix;
  final String agentCode;

  Till({
    required this.id,
    required this.network,
    required this.tillName,
    required this.tillNumber,
    required this.simSlot,
    required this.currentFloat,
    required this.minFloatAlert,
    required this.ussdPrefix,
    required this.agentCode,
  });

  Till copyWith({
    String? tillName,
    String? tillNumber,
    String? simSlot,
    double? currentFloat,
    double? minFloatAlert,
    String? ussdPrefix,
    String? agentCode,
  }) {
    return Till(
      id: id,
      network: network,
      tillName: tillName ?? this.tillName,
      tillNumber: tillNumber ?? this.tillNumber,
      simSlot: simSlot ?? this.simSlot,
      currentFloat: currentFloat ?? this.currentFloat,
      minFloatAlert: minFloatAlert ?? this.minFloatAlert,
      ussdPrefix: ussdPrefix ?? this.ussdPrefix,
      agentCode: agentCode ?? this.agentCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'network': network.name,
        'tillName': tillName,
        'tillNumber': tillNumber,
        'simSlot': simSlot,
        'currentFloat': currentFloat,
        'minFloatAlert': minFloatAlert,
        'ussdPrefix': ussdPrefix,
        'agentCode': agentCode,
      };

  factory Till.fromJson(Map<String, dynamic> json) => Till(
        id: json['id'] as String,
        network: NetworkProvider.values.byName(json['network'] as String),
        tillName: json['tillName'] as String,
        tillNumber: json['tillNumber'] as String,
        simSlot: json['simSlot'] as String,
        currentFloat: (json['currentFloat'] as num).toDouble(),
        minFloatAlert: (json['minFloatAlert'] as num).toDouble(),
        ussdPrefix: json['ussdPrefix'] as String,
        agentCode: json['agentCode'] as String,
      );
}

class TransactionRecord {
  final String id;
  final String tillId;
  final NetworkProvider network;
  final TransactionType type;
  final double amount;
  final double fee;
  final double commission;
  final String customerPhone;
  final String reference;
  final String ussdString;
  final DateTime timestamp;
  final TransactionStatus status;
  final bool isVoided;
  final String? voidedByReversalId;

  TransactionRecord({
    required this.id,
    required this.tillId,
    required this.network,
    required this.type,
    required this.amount,
    required this.fee,
    required this.commission,
    required this.customerPhone,
    required this.reference,
    required this.ussdString,
    required this.timestamp,
    required this.status,
    this.isVoided = false,
    this.voidedByReversalId,
  });

  TransactionRecord copyWith({
    String? id,
    String? tillId,
    NetworkProvider? network,
    TransactionType? type,
    double? amount,
    double? fee,
    double? commission,
    String? customerPhone,
    String? reference,
    String? ussdString,
    DateTime? timestamp,
    TransactionStatus? status,
    bool? isVoided,
    String? voidedByReversalId,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      tillId: tillId ?? this.tillId,
      network: network ?? this.network,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      commission: commission ?? this.commission,
      customerPhone: customerPhone ?? this.customerPhone,
      reference: reference ?? this.reference,
      ussdString: ussdString ?? this.ussdString,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isVoided: isVoided ?? this.isVoided,
      voidedByReversalId: voidedByReversalId ?? this.voidedByReversalId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tillId': tillId,
        'network': network.name,
        'type': type.name,
        'amount': amount,
        'fee': fee,
        'commission': commission,
        'customerPhone': customerPhone,
        'reference': reference,
        'ussdString': ussdString,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'isVoided': isVoided,
        'voidedByReversalId': voidedByReversalId,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] as String,
        tillId: json['tillId'] as String,
        network: NetworkProvider.values.byName(json['network'] as String),
        type: TransactionType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        fee: (json['fee'] as num).toDouble(),
        commission: (json['commission'] as num).toDouble(),
        customerPhone: json['customerPhone'] as String,
        reference: json['reference'] as String,
        ussdString: json['ussdString'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: TransactionStatus.values.byName(json['status'] as String),
        isVoided: json['isVoided'] == true || json['isVoided'] == 1,
        voidedByReversalId: json['voidedByReversalId'] as String?,
      );
}

class SmsRecord {
  final String id;
  final String sender;
  final String rawText;
  final NetworkProvider network;
  final TransactionType type;
  final double amount;
  final double fee;
  final String reference;
  final String customerPhone;
  final double? postBalance;
  final DateTime timestamp;
  final bool isReversed;
  final bool isVoided;
  final String? voidedByReversalId;

  SmsRecord({
    required this.id,
    required this.sender,
    required this.rawText,
    required this.network,
    required this.type,
    required this.amount,
    required this.fee,
    required this.reference,
    this.customerPhone = '',
    this.postBalance,
    required this.timestamp,
    this.isReversed = false,
    this.isVoided = false,
    this.voidedByReversalId,
  });

  SmsRecord copyWith({
    String? id,
    String? sender,
    String? rawText,
    NetworkProvider? network,
    TransactionType? type,
    double? amount,
    double? fee,
    String? reference,
    String? customerPhone,
    double? postBalance,
    DateTime? timestamp,
    bool? isReversed,
    bool? isVoided,
    String? voidedByReversalId,
  }) {
    return SmsRecord(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      rawText: rawText ?? this.rawText,
      network: network ?? this.network,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      reference: reference ?? this.reference,
      customerPhone: customerPhone ?? this.customerPhone,
      postBalance: postBalance ?? this.postBalance,
      timestamp: timestamp ?? this.timestamp,
      isReversed: isReversed ?? this.isReversed,
      isVoided: isVoided ?? this.isVoided,
      voidedByReversalId: voidedByReversalId ?? this.voidedByReversalId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'rawText': rawText,
        'network': network.name,
        'type': type.name,
        'amount': amount,
        'fee': fee,
        'reference': reference,
        'customerPhone': customerPhone,
        'postBalance': postBalance,
        'timestamp': timestamp.toIso8601String(),
        'isReversed': isReversed,
        'isVoided': isVoided,
        'voidedByReversalId': voidedByReversalId,
      };

  factory SmsRecord.fromJson(Map<String, dynamic> json) => SmsRecord(
        id: json['id'] as String,
        sender: json['sender'] as String,
        rawText: json['rawText'] as String,
        network: NetworkProvider.values.byName(json['network'] as String),
        type: TransactionType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        fee: (json['fee'] as num).toDouble(),
        reference: json['reference'] as String,
        customerPhone: json['customerPhone'] as String? ?? '',
        postBalance: json['postBalance'] != null
            ? (json['postBalance'] as num).toDouble()
            : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isReversed: json['isReversed'] as bool? ?? false,
        isVoided: json['isVoided'] as bool? ?? false,
        voidedByReversalId: json['voidedByReversalId'] as String?,
      );
}

class CashDenomination {
  final Map<int, int> noteCounts; // e.g. {200: 0, 100: 2, 50: 10, 20: 5, 10: 0, 5: 0, 2: 0, 1: 0}
  final double coinTotal;

  CashDenomination({
    Map<int, int>? noteCounts,
    this.coinTotal = 0.0,
  }) : noteCounts = noteCounts ??
            {
              200: 0,
              100: 0,
              50: 0,
              20: 0,
              10: 0,
              5: 0,
              2: 0,
              1: 0,
            };

  double get totalNotes =>
      noteCounts.entries.fold(0.0, (sum, entry) => sum + (entry.key * entry.value));

  double get total => totalNotes + coinTotal;

  int get totalNoteCount =>
      noteCounts.values.fold(0, (sum, count) => sum + count);

  CashDenomination copyWith({
    Map<int, int>? noteCounts,
    double? coinTotal,
  }) {
    return CashDenomination(
      noteCounts: noteCounts != null ? Map<int, int>.from(noteCounts) : Map<int, int>.from(this.noteCounts),
      coinTotal: coinTotal ?? this.coinTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'noteCounts': noteCounts.map((k, v) => MapEntry(k.toString(), v)),
        'coinTotal': coinTotal,
      };

  factory CashDenomination.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['noteCounts'] as Map<String, dynamic>? ?? {};
    final parsedNotes = <int, int>{};
    for (final entry in rawNotes.entries) {
      final key = int.tryParse(entry.key);
      if (key != null) {
        parsedNotes[key] = (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return CashDenomination(
      noteCounts: parsedNotes,
      coinTotal: (json['coinTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReconciliationResult {
  final double physicalCashCount;
  final double expectedPhysicalCash;
  final double cashVariance;
  final double totalCashIn;
  final double totalCashOut;
  final double totalPettyCash;
  final double totalCommissions;
  final String status; // BALANCED, SHORTAGE, OVERAGE
  final String aiDiagnosis;
  final CashDenomination? denomination;
  final Map<String, NetworkVolumeSummary>? networkBreakdown;

  ReconciliationResult({
    required this.physicalCashCount,
    required this.expectedPhysicalCash,
    required this.cashVariance,
    required this.totalCashIn,
    required this.totalCashOut,
    this.totalPettyCash = 0.0,
    required this.totalCommissions,
    required this.status,
    required this.aiDiagnosis,
    this.denomination,
    this.networkBreakdown,
  });

  Map<String, dynamic> toJson() => {
        'physicalCashCount': physicalCashCount,
        'expectedPhysicalCash': expectedPhysicalCash,
        'cashVariance': cashVariance,
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'totalPettyCash': totalPettyCash,
        'totalCommissions': totalCommissions,
        'status': status,
        'aiDiagnosis': aiDiagnosis,
        if (denomination != null) 'denomination': denomination!.toJson(),
        if (networkBreakdown != null)
          'networkBreakdown': networkBreakdown!.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ReconciliationResult.fromJson(Map<String, dynamic> json) {
    Map<String, NetworkVolumeSummary>? breakdown;
    if (json['networkBreakdown'] != null) {
      final map = json['networkBreakdown'] as Map<String, dynamic>;
      breakdown = map.map((k, v) => MapEntry(k, NetworkVolumeSummary.fromJson(v as Map<String, dynamic>)));
    }

    return ReconciliationResult(
      physicalCashCount: (json['physicalCashCount'] as num).toDouble(),
      expectedPhysicalCash: (json['expectedPhysicalCash'] as num).toDouble(),
      cashVariance: (json['cashVariance'] as num).toDouble(),
      totalCashIn: (json['totalCashIn'] as num).toDouble(),
      totalCashOut: (json['totalCashOut'] as num).toDouble(),
      totalPettyCash: (json['totalPettyCash'] as num?)?.toDouble() ?? 0.0,
      totalCommissions: (json['totalCommissions'] as num).toDouble(),
      status: json['status'] as String,
      aiDiagnosis: json['aiDiagnosis'] as String,
      denomination: json['denomination'] != null
          ? (json['denomination'] is String
              ? CashDenomination.fromJson(jsonDecode(json['denomination'] as String) as Map<String, dynamic>)
              : CashDenomination.fromJson(json['denomination'] as Map<String, dynamic>))
          : null,
      networkBreakdown: breakdown,
    );
  }
}

class ShiftRecord {
  final String id;
  final int shiftNumber;
  final DateTime startTime;
  final DateTime endTime;
  final double openingCash;
  final double closingCash;
  final double expectedCash;
  final double cashVariance;
  final double totalCashIn;
  final double totalCashOut;
  final double totalCommissions;
  final int transactionCount;
  final String status; // BALANCED, SHORTAGE, OVERAGE
  final String aiDiagnosis;
  final CashDenomination? denomination;
  final Map<String, NetworkVolumeSummary>? networkBreakdown;

  ShiftRecord({
    required this.id,
    required this.shiftNumber,
    required this.startTime,
    required this.endTime,
    required this.openingCash,
    required this.closingCash,
    required this.expectedCash,
    required this.cashVariance,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalCommissions,
    required this.transactionCount,
    required this.status,
    required this.aiDiagnosis,
    this.denomination,
    this.networkBreakdown,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'shiftNumber': shiftNumber,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'openingCash': openingCash,
        'closingCash': closingCash,
        'expectedCash': expectedCash,
        'cashVariance': cashVariance,
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'totalCommissions': totalCommissions,
        'transactionCount': transactionCount,
        'status': status,
        'aiDiagnosis': aiDiagnosis,
        if (denomination != null) 'denomination': denomination!.toJson(),
        if (networkBreakdown != null)
          'networkBreakdown': networkBreakdown!.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ShiftRecord.fromJson(Map<String, dynamic> json) {
    Map<String, NetworkVolumeSummary>? breakdown;
    if (json['networkBreakdown'] != null) {
      final map = json['networkBreakdown'] as Map<String, dynamic>;
      breakdown = map.map((k, v) => MapEntry(k, NetworkVolumeSummary.fromJson(v as Map<String, dynamic>)));
    }

    return ShiftRecord(
      id: json['id'] as String,
      shiftNumber: json['shiftNumber'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      openingCash: (json['openingCash'] as num).toDouble(),
      closingCash: (json['closingCash'] as num).toDouble(),
      expectedCash: (json['expectedCash'] as num).toDouble(),
      cashVariance: (json['cashVariance'] as num).toDouble(),
      totalCashIn: (json['totalCashIn'] as num).toDouble(),
      totalCashOut: (json['totalCashOut'] as num).toDouble(),
      totalCommissions: (json['totalCommissions'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
      status: json['status'] as String,
      aiDiagnosis: json['aiDiagnosis'] as String,
      denomination: json['denomination'] != null
          ? (json['denomination'] is String
              ? CashDenomination.fromJson(jsonDecode(json['denomination'] as String) as Map<String, dynamic>)
              : CashDenomination.fromJson(json['denomination'] as Map<String, dynamic>))
          : null,
      networkBreakdown: breakdown,
    );
  }
}

class CustomerContact {
  final String id;
  final String name;
  final String phone;
  final NetworkProvider network;
  final int totalTransactions;
  final DateTime lastTransacted;

  CustomerContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.network,
    required this.totalTransactions,
    required this.lastTransacted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'network': network.name,
        'totalTransactions': totalTransactions,
        'lastTransacted': lastTransacted.toIso8601String(),
      };

  factory CustomerContact.fromJson(Map<String, dynamic> json) =>
      CustomerContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        network: NetworkProvider.values.byName(json['network'] as String),
        totalTransactions: json['totalTransactions'] as int,
        lastTransacted: DateTime.parse(json['lastTransacted'] as String),
      );
}

class NetworkCommissionOverride {
  final double? cashInRate;
  final double? cashOutRate;
  final double? airtimeRate;
  final double? dataBundleRate;

  NetworkCommissionOverride({
    this.cashInRate,
    this.cashOutRate,
    this.airtimeRate,
    this.dataBundleRate,
  });

  Map<String, dynamic> toJson() => {
        'cashInRate': cashInRate,
        'cashOutRate': cashOutRate,
        'airtimeRate': airtimeRate,
        'dataBundleRate': dataBundleRate,
      };

  factory NetworkCommissionOverride.fromJson(Map<String, dynamic> json) =>
      NetworkCommissionOverride(
        cashInRate: (json['cashInRate'] as num?)?.toDouble(),
        cashOutRate: (json['cashOutRate'] as num?)?.toDouble(),
        airtimeRate: (json['airtimeRate'] as num?)?.toDouble(),
        dataBundleRate: (json['dataBundleRate'] as num?)?.toDouble(),
      );
}

class CommissionSettings {
  final double cashInRate; // default: 0.005 (0.5%)
  final double cashOutRate; // default: 0.01 (1.0%)
  final double airtimeRate; // default: 0.03 (3.0%)
  final double dataBundleRate; // default: 0.04 (4.0%)
  final double utilityFlatFee; // default: 1.50
  final double payTvFlatFee; // default: 2.00
  final double bankTransferRate; // default: 0.006 (0.6%)
  final Map<String, NetworkCommissionOverride> networkOverrides;

  CommissionSettings({
    this.cashInRate = 0.005,
    this.cashOutRate = 0.01,
    this.airtimeRate = 0.03,
    this.dataBundleRate = 0.04,
    this.utilityFlatFee = 1.50,
    this.payTvFlatFee = 2.00,
    this.bankTransferRate = 0.006,
    Map<String, NetworkCommissionOverride>? networkOverrides,
  }) : networkOverrides = networkOverrides ?? {};

  double getRateFor(NetworkProvider network, TransactionType type) {
    final override = networkOverrides[network.name];
    switch (type) {
      case TransactionType.cashIn:
        return override?.cashInRate ?? cashInRate;
      case TransactionType.cashOut:
        return override?.cashOutRate ?? cashOutRate;
      case TransactionType.airtime:
        return override?.airtimeRate ?? airtimeRate;
      case TransactionType.dataBundle:
        return override?.dataBundleRate ?? dataBundleRate;
      case TransactionType.ecgElectricity:
      case TransactionType.ghanaWater:
        return utilityFlatFee;
      case TransactionType.payTv:
        return payTvFlatFee;
      case TransactionType.bankTransfer:
        return bankTransferRate;
      case TransactionType.floatTransfer:
      case TransactionType.reversal:
        return 0.0;
    }
  }

  Map<String, dynamic> toJson() => {
        'cashInRate': cashInRate,
        'cashOutRate': cashOutRate,
        'airtimeRate': airtimeRate,
        'dataBundleRate': dataBundleRate,
        'utilityFlatFee': utilityFlatFee,
        'payTvFlatFee': payTvFlatFee,
        'bankTransferRate': bankTransferRate,
        'networkOverrides':
            networkOverrides.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory CommissionSettings.fromJson(Map<String, dynamic> json) {
    final overridesJson =
        json['networkOverrides'] as Map<String, dynamic>? ?? {};
    final overrides = overridesJson.map((k, v) => MapEntry(
          k,
          NetworkCommissionOverride.fromJson(v as Map<String, dynamic>),
        ));

    return CommissionSettings(
      cashInRate: (json['cashInRate'] as num?)?.toDouble() ?? 0.005,
      cashOutRate: (json['cashOutRate'] as num?)?.toDouble() ?? 0.01,
      airtimeRate: (json['airtimeRate'] as num?)?.toDouble() ?? 0.03,
      dataBundleRate: (json['dataBundleRate'] as num?)?.toDouble() ?? 0.04,
      utilityFlatFee: (json['utilityFlatFee'] as num?)?.toDouble() ?? 1.50,
      payTvFlatFee: (json['payTvFlatFee'] as num?)?.toDouble() ?? 2.00,
      bankTransferRate:
          (json['bankTransferRate'] as num?)?.toDouble() ?? 0.006,
      networkOverrides: overrides,
    );
  }
}

enum PettyCashCategory {
  shopRent,
  electricityUtility,
  attendantMeal,
  airtimeFloatTopup,
  stationery,
  maintenance,
  ownerDraw,
  other,
}

class PettyCashExpense {
  final String id;
  final double amount;
  final PettyCashCategory category;
  final String note;
  final String tellerName;
  final DateTime timestamp;

  PettyCashExpense({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.tellerName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.name,
        'note': note,
        'tellerName': tellerName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PettyCashExpense.fromJson(Map<String, dynamic> json) =>
      PettyCashExpense(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: PettyCashCategory.values.byName(json['category'] as String),
        note: json['note'] as String,
        tellerName: json['tellerName'] as String? ?? 'Primary Attendant',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

enum TellerRole { owner, attendant, shiftSupervisor }

class Teller {
  final String id;
  final String name;
  final String phone;
  final String pinHash;
  final TellerRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastShiftStartedAt;

  Teller({
    required this.id,
    required this.name,
    required this.phone,
    required this.pinHash,
    this.role = TellerRole.attendant,
    this.isActive = true,
    required this.createdAt,
    this.lastShiftStartedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'pinHash': pinHash,
        'role': role.name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'lastShiftStartedAt': lastShiftStartedAt?.toIso8601String(),
      };

  factory Teller.fromJson(Map<String, dynamic> json) => Teller(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String? ?? '',
        pinHash: json['pinHash'] as String? ?? '',
        role: TellerRole.values.byName(json['role'] as String? ?? 'attendant'),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        lastShiftStartedAt: json['lastShiftStartedAt'] != null
            ? DateTime.parse(json['lastShiftStartedAt'] as String)
            : null,
      );
}

class ShiftHandover {
  final String id;
  final String outgoingTellerName;
  final String incomingTellerName;
  final DateTime handoverTime;
  final double countedDrawerCash;
  final double expectedDrawerCash;
  final double cashVariance;
  final int shiftTransactionCount;
  final double shiftVolume;
  final double shiftCommissions;
  final double shiftPettyCashSpent;
  final String notes;

  ShiftHandover({
    required this.id,
    required this.outgoingTellerName,
    required this.incomingTellerName,
    required this.handoverTime,
    required this.countedDrawerCash,
    required this.expectedDrawerCash,
    required this.cashVariance,
    required this.shiftTransactionCount,
    required this.shiftVolume,
    required this.shiftCommissions,
    required this.shiftPettyCashSpent,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'outgoingTellerName': outgoingTellerName,
        'incomingTellerName': incomingTellerName,
        'handoverTime': handoverTime.toIso8601String(),
        'countedDrawerCash': countedDrawerCash,
        'expectedDrawerCash': expectedDrawerCash,
        'cashVariance': cashVariance,
        'shiftTransactionCount': shiftTransactionCount,
        'shiftVolume': shiftVolume,
        'shiftCommissions': shiftCommissions,
        'shiftPettyCashSpent': shiftPettyCashSpent,
        'notes': notes,
      };

  factory ShiftHandover.fromJson(Map<String, dynamic> json) => ShiftHandover(
        id: json['id'] as String,
        outgoingTellerName: json['outgoingTellerName'] as String,
        incomingTellerName: json['incomingTellerName'] as String,
        handoverTime: DateTime.parse(json['handoverTime'] as String),
        countedDrawerCash: (json['countedDrawerCash'] as num).toDouble(),
        expectedDrawerCash: (json['expectedDrawerCash'] as num).toDouble(),
        cashVariance: (json['cashVariance'] as num).toDouble(),
        shiftTransactionCount: json['shiftTransactionCount'] as int,
        shiftVolume: (json['shiftVolume'] as num).toDouble(),
        shiftCommissions: (json['shiftCommissions'] as num).toDouble(),
        shiftPettyCashSpent:
            (json['shiftPettyCashSpent'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String? ?? '',
      );
}

class CustomUssdRule {
  final String id;
  final NetworkProvider network;
  final TransactionType transactionType;
  final String customRootCode;
  final List<String> customSteps;
  final bool isEnabled;

  CustomUssdRule({
    required this.id,
    required this.network,
    required this.transactionType,
    required this.customRootCode,
    required this.customSteps,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'network': network.name,
        'transactionType': transactionType.name,
        'customRootCode': customRootCode,
        'customSteps': customSteps,
        'isEnabled': isEnabled,
      };

  factory CustomUssdRule.fromJson(Map<String, dynamic> json) => CustomUssdRule(
        id: json['id'] as String,
        network: NetworkProvider.values.byName(json['network'] as String),
        transactionType:
            TransactionType.values.byName(json['transactionType'] as String),
        customRootCode: json['customRootCode'] as String,
        customSteps: List<String>.from(json['customSteps'] as List),
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}

enum FraudRiskLevel { safe, warning, suspicious, highRisk }

class FraudCheckResult {
  final FraudRiskLevel riskLevel;
  final String message;
  final bool isSenderAuthentic;
  final bool isDuplicateReference;
  final bool isTimestampValid;

  FraudCheckResult({
    required this.riskLevel,
    required this.message,
    required this.isSenderAuthentic,
    required this.isDuplicateReference,
    required this.isTimestampValid,
  });

  bool get isFraudSuspicious =>
      riskLevel == FraudRiskLevel.suspicious ||
      riskLevel == FraudRiskLevel.highRisk ||
      !isSenderAuthentic ||
      isDuplicateReference;

  String get reason => message;
}

class BluetoothPrinterInfo {
  final String name;
  final String address;
  final bool isConnected;
  final int paperWidthMm; // 58 or 80

  BluetoothPrinterInfo({
    required this.name,
    required this.address,
    this.isConnected = false,
    this.paperWidthMm = 58,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'isConnected': isConnected,
        'paperWidthMm': paperWidthMm,
      };

  factory BluetoothPrinterInfo.fromJson(Map<String, dynamic> json) =>
      BluetoothPrinterInfo(
        name: json['name'] as String,
        address: json['address'] as String,
        isConnected: json['isConnected'] as bool? ?? false,
        paperWidthMm: json['paperWidthMm'] as int? ?? 58,
      );
}

