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
}

enum TransactionStatus { completed, pending, failed, offlineQueued }

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
  });

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
  });

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
      );
}

class ReconciliationResult {
  final double physicalCashCount;
  final double expectedPhysicalCash;
  final double cashVariance;
  final double totalCashIn;
  final double totalCashOut;
  final double totalCommissions;
  final String status; // BALANCED, SHORTAGE, OVERAGE
  final String aiDiagnosis;

  ReconciliationResult({
    required this.physicalCashCount,
    required this.expectedPhysicalCash,
    required this.cashVariance,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalCommissions,
    required this.status,
    required this.aiDiagnosis,
  });

  Map<String, dynamic> toJson() => {
        'physicalCashCount': physicalCashCount,
        'expectedPhysicalCash': expectedPhysicalCash,
        'cashVariance': cashVariance,
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'totalCommissions': totalCommissions,
        'status': status,
        'aiDiagnosis': aiDiagnosis,
      };

  factory ReconciliationResult.fromJson(Map<String, dynamic> json) =>
      ReconciliationResult(
        physicalCashCount: (json['physicalCashCount'] as num).toDouble(),
        expectedPhysicalCash: (json['expectedPhysicalCash'] as num).toDouble(),
        cashVariance: (json['cashVariance'] as num).toDouble(),
        totalCashIn: (json['totalCashIn'] as num).toDouble(),
        totalCashOut: (json['totalCashOut'] as num).toDouble(),
        totalCommissions: (json['totalCommissions'] as num).toDouble(),
        status: json['status'] as String,
        aiDiagnosis: json['aiDiagnosis'] as String,
      );
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
      };

  factory ShiftRecord.fromJson(Map<String, dynamic> json) => ShiftRecord(
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
      );
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
