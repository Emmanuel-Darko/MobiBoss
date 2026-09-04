import 'package:uuid/uuid.dart';
import '../models/mobiboss_models.dart';

class SmsParserService {
  static const _uuid = Uuid();

  /// List of known telecom SMS sender IDs in Ghana
  static const List<String> momoSenders = [
    'MobileMoney',
    'MTN',
    'MTNMomo',
    '171',
    'TelecelCash',
    'Telecel',
    'VodafoneCash',
    'Vodafone',
    '110',
    'ATMoney',
    'AirtelTigo',
    'AirtelTigoMoney',
    'GMoney',
    'GCB',
  ];

  /// Checks if a sender address matches mobile money services
  static bool isMoMoSender(String address) {
    if (address.isEmpty) return false;
    final normalized = address.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return momoSenders.any((s) {
      final sNorm = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return normalized.contains(sNorm) || sNorm.contains(normalized);
    });
  }

  /// Parses raw SMS text or confirmed USSD prompt and extracts structured transaction metadata.
  /// Returns NULL if the text is not an actual completed transaction (e.g., balance check, promo, MMI error).
  static SmsRecord? parse(String rawText, {String sender = '', DateTime? timestamp}) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();

    // 1. Filter out non-transaction texts immediately
    if (_isNonTransactionMessage(lower)) {
      return null;
    }

    // 2. Detect transaction type strictly (returns null if no transaction verb found)
    final type = _detectTransactionType(lower);
    if (type == null) {
      return null;
    }

    // 3. Extract transaction amount (must be > 0 and not the post-balance)
    final amount = _extractTransactionAmount(text);
    if (amount <= 0) {
      return null;
    }

    final net = _detectNetwork(sender, lower);
    final fee = _extractFee(text);
    final reference = _extractReference(text);
    final phone = _extractPhoneNumber(text);
    final postBalance = _extractPostBalance(text);

    return SmsRecord(
      id: _uuid.v4(),
      sender: sender.isNotEmpty ? sender : _defaultSenderName(net),
      rawText: text,
      network: net,
      type: type,
      amount: amount,
      fee: fee,
      reference: reference,
      customerPhone: phone,
      postBalance: postBalance,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Extracts just the account balance if present (e.g. from balance checks) without creating a transaction
  static double? extractBalanceOnly(String text) {
    return _extractPostBalance(text);
  }

  static bool _isNonTransactionMessage(String lower) {
    // MMI errors, progress texts, menus, and marketing
    if (lower.contains('connection problem') ||
        lower.contains('invalid mmi') ||
        lower.contains('mmi code') ||
        lower.contains('ussd code running') ||
        lower.contains('unlock more deals') ||
        lower.contains('try our new momo app') ||
        lower.contains('welcome to') ||
        lower.contains('select option') ||
        lower.contains('# for next') ||
        lower.contains('0 for more')) {
      return true;
    }

    // Pure balance inquiry message with NO payment action
    final isPureBalanceCheck = (lower.contains('current balance') || lower.contains('available balance') || lower.contains('your balance is')) &&
        !lower.contains('payment made') &&
        !lower.contains('payment received') &&
        !lower.contains('transferred to') &&
        !lower.contains('cash in') &&
        !lower.contains('cash out') &&
        !lower.contains('cashed out') &&
        !lower.contains('you have received') &&
        !lower.contains('you have sent') &&
        !lower.contains('recharge') &&
        !lower.contains('bundle purchased');

    return isPureBalanceCheck;
  }

  static NetworkProvider _detectNetwork(String sender, String lowerText) {
    final lowerSender = sender.toLowerCase();

    if (lowerSender.contains('telecel') ||
        lowerSender.contains('vodafone') ||
        lowerText.contains('telecel') ||
        lowerText.contains('vodafone')) {
      return NetworkProvider.telecel;
    }
    if (lowerSender.contains('atmoney') ||
        lowerSender.contains('airteltigo') ||
        lowerText.contains('airteltigo') ||
        lowerText.contains('at money')) {
      return NetworkProvider.at;
    }
    if (lowerSender.contains('gmoney') ||
        lowerSender.contains('gcb') ||
        lowerText.contains('g-money') ||
        lowerText.contains('gmoney')) {
      return NetworkProvider.gmoney;
    }
    return NetworkProvider.mtn;
  }

  static TransactionType? _detectTransactionType(String lower) {
    // 1. Data Bundle
    if (lower.contains('data bundle') ||
        lower.contains('internet bundle') ||
        lower.contains('bundle purchased') ||
        lower.contains('package purchased')) {
      return TransactionType.dataBundle;
    }

    // 2. Airtime Top-up
    if (lower.contains('airtime') ||
        lower.contains('top-up') ||
        lower.contains('topup') ||
        lower.contains('credit purchase') ||
        lower.contains('recharge successful') ||
        lower.contains('recharged')) {
      return TransactionType.airtime;
    }

    // 3. Float Transfer / Bank to Wallet
    if (lower.contains('bank to wallet') ||
        lower.contains('wallet to bank') ||
        lower.contains('float transfer') ||
        lower.contains('agent float')) {
      return TransactionType.floatTransfer;
    }

    // 4. Cash Out (Withdrawal / Payment Received)
    if (lower.contains('payment received') ||
        lower.contains('cash out') ||
        lower.contains('cashout') ||
        lower.contains('cash received') ||
        lower.contains('you have received') ||
        lower.contains('received ghs') ||
        lower.contains('received ghc') ||
        lower.contains('cashed out') ||
        lower.contains('withdrawal of') ||
        lower.contains('withdrawal from')) {
      return TransactionType.cashOut;
    }

    // 5. Cash In (Deposit / Payment Made / Transfer to Customer)
    if (lower.contains('payment made') ||
        lower.contains('cash in') ||
        lower.contains('cashin') ||
        lower.contains('you have sent') ||
        lower.contains('transferred to') ||
        lower.contains('deposit of') ||
        lower.contains('paid to') ||
        lower.contains('transfer to')) {
      return TransactionType.cashIn;
    }

    // If none of the explicit transaction verbs matched, return NULL
    return null;
  }

  static double _extractTransactionAmount(String text) {
    // 1. Target amount immediately preceded by transaction verbs:
    // "Payment made for GHS 100.00", "Payment received for GHS 250", "sent GHS 50 to", "paid GHS 30 to"
    final actionMatch = RegExp(
      r'(?:for|received|sent|paid|of|amount|amt)[:\s]+(?:GHS|GHC|GHc|GH¢)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (actionMatch != null) {
      final clean = actionMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(clean) ?? 0.0;
      if (val > 0) return val;
    }

    // 2. Standard currency match, taking care to avoid "Current Balance" or "Fee"
    final matches = RegExp(
      r'(?:GHS|GHC|GHc|GH¢)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).allMatches(text);

    for (final m in matches) {
      final startIdx = m.start;
      final precedingText = text.substring(0, startIdx).toLowerCase();

      // Skip if this currency amount is part of "Balance:" or "Fee:"
      if (precedingText.endsWith('balance:') ||
          precedingText.endsWith('balance ') ||
          precedingText.endsWith('fee:') ||
          precedingText.endsWith('fee ')) {
        continue;
      }

      final clean = m.group(1)!.replaceAll(',', '');
      final val = double.tryParse(clean) ?? 0.0;
      if (val > 0) return val;
    }

    return 0.0;
  }

  static double _extractFee(String text) {
    final match = RegExp(
      r'(?:Fee|Charge|Commission)[:\s]*(?:GHS|GHC|GHc|GH¢)?\s*([0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static String _extractReference(String text) {
    final match = RegExp(
      r'(?:Ref|Txn ID|Transaction ID|ID|Reference|Token|Approval)[:\s]+([A-Za-z0-9.\-_]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      return match.group(1)!;
    }
    return 'SMS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  static String _extractPhoneNumber(String text) {
    final match = RegExp(
      r'(?:to|from|for|by|number)?\s*(\b(?:0[235][0-9]{8}|233[235][0-9]{8})\b)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      return match.group(1)!;
    }
    return '';
  }

  static double? _extractPostBalance(String text) {
    final match = RegExp(
      r'(?:Current Balance|Available Balance|New Balance|Balance)[:\s]*(?:GHS|GHC|GHc|GH¢)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final clean = match.group(1)!.replaceAll(',', '');
      return double.tryParse(clean);
    }
    return null;
  }

  static String _defaultSenderName(NetworkProvider net) {
    switch (net) {
      case NetworkProvider.mtn:
        return 'MobileMoney';
      case NetworkProvider.telecel:
        return 'TelecelCash';
      case NetworkProvider.at:
        return 'ATMoney';
      case NetworkProvider.gmoney:
        return 'GMoney';
    }
  }
}
