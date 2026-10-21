import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mobiboss_models.dart';

class MultiStepUssdPlan {
  final String rootCode;
  final List<String> steps;
  final String displayShortCode;

  MultiStepUssdPlan({
    required this.rootCode,
    required this.steps,
    required this.displayShortCode,
  });
}

class UssdService {
  static const MethodChannel _channel = MethodChannel('com.kodetech.mobiboss/ussd');
  static Function(Map<String, dynamic> data)? _onTransactionCompleteCallback;
  static Function(Map<String, dynamic> data)? _onSmsReceivedCallback;

  static void initializeCallbackListener({
    required Function(Map<String, dynamic> data) onUssdComplete,
    Function(Map<String, dynamic> data)? onSmsReceived,
  }) {
    _onTransactionCompleteCallback = onUssdComplete;
    _onSmsReceivedCallback = onSmsReceived;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUssdTransactionComplete') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        _onTransactionCompleteCallback?.call(data);
      } else if (call.method == 'onSmsReceived') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        _onSmsReceivedCallback?.call(data);
      }
    });
  }

  /// Checks whether the background Accessibility Service is enabled in Android settings
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled == true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android Accessibility Settings screen so the agent can enable the service
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Builds multi-step sequence for Ghana telecom operators where long-string chaining is restricted
  static MultiStepUssdPlan buildMultiStepPlan({
    required Till till,
    required TransactionType type,
    required String customerPhone,
    required double amount,
    List<CustomUssdRule>? customRules,
  }) {
    final amtFormatted = amount.toStringAsFixed(0);

    // Check if custom rule exists for this network and transaction type
    if (customRules != null) {
      final custom = customRules.firstWhere(
        (r) => r.network == till.network && r.transactionType == type && r.isEnabled,
        orElse: () => CustomUssdRule(
          id: '',
          network: till.network,
          transactionType: type,
          customRootCode: '',
          customSteps: [],
          isEnabled: false,
        ),
      );

      if (custom.isEnabled && custom.customSteps.isNotEmpty) {
        final substitutedSteps = custom.customSteps.map((step) {
          return step
              .replaceAll('{phone}', customerPhone)
              .replaceAll('{amount}', amtFormatted)
              .replaceAll('{ref}', 'POS');
        }).toList();

        return MultiStepUssdPlan(
          rootCode: custom.customRootCode.isNotEmpty ? custom.customRootCode : till.ussdPrefix,
          steps: substitutedSteps,
          displayShortCode: '${custom.customRootCode} (${substitutedSteps.length} steps)',
        );
      }
    }

    switch (till.network) {
      case NetworkProvider.mtn:
        if (type == TransactionType.cashIn) {
          // *171# > 3 (Cash In) > 1 (MoMo User) > {mobile} > {confirm_mobile} > {amount} > {reference} > [agent_pin]
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['3', '1', customerPhone, customerPhone, amtFormatted, 'POS'],
            displayShortCode: '*171*3*1*$customerPhone*$customerPhone*$amtFormatted*POS#',
          );
        } else if (type == TransactionType.cashOut) {
          // *171# > 2 (Cash Out) > 1 (MoMo User) > {mobile} > {confirm_mobile} > {amount} > {reference} > [agent_pin]
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['2', '1', customerPhone, customerPhone, amtFormatted, 'POS'],
            displayShortCode: '*171*2*1*$customerPhone*$customerPhone*$amtFormatted*POS#',
          );
        } else if (type == TransactionType.airtime) {
          // *171# > 5 (Airtime & Bundles) > 1 (Airtime) > 5 (Other Networks / Customer) > {amount} > {mobile} > {confirm_mobile} > [agent_pin]
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['5', '1', '5', amtFormatted, customerPhone, customerPhone],
            displayShortCode: '*171*5*1*5*$amtFormatted*$customerPhone*$customerPhone#',
          );
        } else {
          // Data bundle: *171# > 5 > 2 > 1 > 1 > 2 > {mobile} > {confirm_mobile} > 1 > {amount} > 1 > 2 > [agent_pin]
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['5', '2', '1', '1', '2', customerPhone, customerPhone, '1', amtFormatted, '1', '2'],
            displayShortCode: '*171*5*2*1*1*2*$customerPhone*$customerPhone*1*$amtFormatted*1*2#',
          );
        }

      case NetworkProvider.telecel:
        if (type == TransactionType.cashIn) {
          return MultiStepUssdPlan(
            rootCode: '*110#',
            steps: ['1', '1', customerPhone, amtFormatted],
            displayShortCode: '*110*1*1*$customerPhone*$amtFormatted#',
          );
        } else if (type == TransactionType.cashOut) {
          return MultiStepUssdPlan(
            rootCode: '*110#',
            steps: ['1', '2', customerPhone, amtFormatted],
            displayShortCode: '*110*2*$customerPhone*$amtFormatted#',
          );
        } else {
          return MultiStepUssdPlan(
            rootCode: '*110#',
            steps: ['3', customerPhone, amtFormatted],
            displayShortCode: '*110*3*$customerPhone*$amtFormatted#',
          );
        }

      case NetworkProvider.at:
        return MultiStepUssdPlan(
          rootCode: '*110#',
          steps: ['1', customerPhone, amtFormatted],
          displayShortCode: '*110*1*$customerPhone*$amtFormatted#',
        );

      case NetworkProvider.gmoney:
        return MultiStepUssdPlan(
          rootCode: '*422#',
          steps: ['1', customerPhone, amtFormatted],
          displayShortCode: '*422*1*$customerPhone*$amtFormatted#',
        );
    }
  }

  /// Builds GhIPSS Mobile Money Interoperability (MMI) cross-network transfer sequence
  static MultiStepUssdPlan buildCrossNetworkMmiPlan({
    required NetworkProvider destinationNetwork,
    required String customerPhone,
    required double amount,
    String reference = 'POS',
  }) {
    final amtFormatted = amount.toStringAsFixed(0);
    String netOption = '1'; // 1: Telecel, 2: AT, 3: G-Money
    if (destinationNetwork == NetworkProvider.telecel) {
      netOption = '1';
    } else if (destinationNetwork == NetworkProvider.at) {
      netOption = '2';
    } else if (destinationNetwork == NetworkProvider.gmoney) {
      netOption = '3';
    }

    return MultiStepUssdPlan(
      rootCode: '*170#',
      steps: ['1', '2', netOption, customerPhone, customerPhone, amtFormatted, reference],
      displayShortCode: '*170*1*2*$netOption*$customerPhone*$amtFormatted#',
    );
  }

  /// Builds multi-step sequence for expanded agent services: Airtime, Data, ECG, Water, PayTV, Bank
  static MultiStepUssdPlan buildServicePlan({
    required Till till,
    required TransactionType type,
    required String targetAccountOrPhone,
    required double amount,
    String? extraParameter, // meter number, package option, bank code
  }) {
    final amtFormatted = amount.toStringAsFixed(0);

    switch (type) {
      case TransactionType.airtime:
        // MTN: 171,5,1,5,{amount},{mobile},{confirm_mobile},{pin}
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['5', '1', '5', amtFormatted, targetAccountOrPhone, targetAccountOrPhone]
              : ['3', '1', targetAccountOrPhone, amtFormatted],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*5*1*5*$amtFormatted*$targetAccountOrPhone*$targetAccountOrPhone#'
              : '*110*3*1*$targetAccountOrPhone*$amtFormatted#',
        );

      case TransactionType.dataBundle:
        // MTN: 171,5,2,1,1,2,{mobile},{confirm_mobile},1,{amount},1,2,{pin}
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['5', '2', '1', '1', '2', targetAccountOrPhone, targetAccountOrPhone, '1', amtFormatted, '1', '2']
              : ['3', '2', targetAccountOrPhone, extraParameter ?? '1'],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*5*2*1*1*2*$targetAccountOrPhone*$targetAccountOrPhone*1*$amtFormatted*1*2#'
              : '*110*3*2*$targetAccountOrPhone#',
        );

      case TransactionType.ecgElectricity:
        // MTN: 171,4,1,1,{payment_id},{amount},{pin}
        final meterNumber = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['4', '1', '1', meterNumber, amtFormatted]
              : ['2', '1', '1', meterNumber, amtFormatted],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*4*1*1*$meterNumber*$amtFormatted#'
              : '*110*2*1*1*$meterNumber*$amtFormatted#',
        );

      case TransactionType.ghanaWater:
        // MTN: 171,4,1,2,{payment_id},{amount},{pin}
        final accountNo = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['4', '1', '2', accountNo, amtFormatted]
              : ['2', '1', '2', accountNo, amtFormatted],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*4*1*2*$accountNo*$amtFormatted#'
              : '*110*2*1*2*$accountNo*$amtFormatted#',
        );

      case TransactionType.payTv:
        // MTN: 171,4,2,{provider},{account_number},{amount},{pin}
        final smartcard = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['4', '2', '1', smartcard, amtFormatted]
              : ['2', '2', '1', smartcard, amtFormatted],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*4*2*1*$smartcard*$amtFormatted#'
              : '*110*2*2*1*$smartcard*$amtFormatted#',
        );

      case TransactionType.bankTransfer:
        // MTN: 171,6,1,1,{bank},{account},{amount},{pin}
        final bankCode = extraParameter ?? '1';
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['6', '1', '1', bankCode, targetAccountOrPhone, amtFormatted]
              : ['1', '3', '1', targetAccountOrPhone, amtFormatted],
          displayShortCode: till.network == NetworkProvider.mtn
              ? '*171*6*1*1*$bankCode*$targetAccountOrPhone*$amtFormatted#'
              : '*110*1*3*1*$targetAccountOrPhone*$amtFormatted#',
        );

      default:
        return buildMultiStepPlan(
          till: till,
          type: type,
          customerPhone: targetAccountOrPhone,
          amount: amount,
        );
    }
  }

  /// Builds multi-step sequence to sweep accumulated agent commission into Main Float or Personal Wallet
  static MultiStepUssdPlan buildCommissionTransferPlan({
    required Till till,
    required double amount,
    required bool toMainFloat, // true = to Main Float, false = to Personal MoMo
  }) {
    final amtFormatted = amount.toStringAsFixed(0);

    if (till.network == NetworkProvider.mtn) {
      return MultiStepUssdPlan(
        rootCode: '*171#',
        steps: [
          '7', // My Account
          '3', // Commission Transfer
          toMainFloat ? '1' : '2', // 1 = To Float, 2 = To MoMo Wallet
          amtFormatted,
        ],
        displayShortCode: '*171*7*3*${toMainFloat ? "1" : "2"}*$amtFormatted#',
      );
    } else {
      return MultiStepUssdPlan(
        rootCode: '*110#',
        steps: [
          '5', // My Account
          '3', // Commission
          toMainFloat ? '1' : '2',
          amtFormatted,
        ],
        displayShortCode: '*110*5*3*${toMainFloat ? "1" : "2"}*$amtFormatted#',
      );
    }
  }

  /// Builds USSD plan for Balance Check: 171,7,1,{pin}
  static MultiStepUssdPlan buildCheckBalancePlan(Till till) {
    if (till.network == NetworkProvider.mtn) {
      return MultiStepUssdPlan(
        rootCode: '*171#',
        steps: ['7', '1'],
        displayShortCode: '*171*7*1#',
      );
    } else {
      return MultiStepUssdPlan(
        rootCode: '*110#',
        steps: ['5', '1'],
        displayShortCode: '*110*5*1#',
      );
    }
  }

  /// Builds USSD plan for Commissions Inquiry: 171,7,2,{pin}
  static MultiStepUssdPlan buildCheckCommissionsPlan(Till till) {
    if (till.network == NetworkProvider.mtn) {
      return MultiStepUssdPlan(
        rootCode: '*171#',
        steps: ['7', '2'],
        displayShortCode: '*171*7*2#',
      );
    } else {
      return MultiStepUssdPlan(
        rootCode: '*110#',
        steps: ['5', '2'],
        displayShortCode: '*110*5*2#',
      );
    }
  }

  /// Builds USSD plan for Check Wallet Limit: 171,7,7,{pin}
  static MultiStepUssdPlan buildCheckWalletLimitPlan(Till till) {
    if (till.network == NetworkProvider.mtn) {
      return MultiStepUssdPlan(
        rootCode: '*171#',
        steps: ['7', '7'],
        displayShortCode: '*171*7*7#',
      );
    } else {
      return MultiStepUssdPlan(
        rootCode: '*110#',
        steps: ['5', '7'],
        displayShortCode: '*110*5*7#',
      );
    }
  }

  /// Initiates automated multi-step USSD navigation up to PIN prompt
  static Future<bool> initiateAutomatedSession({
    required Till till,
    required TransactionType type,
    required String customerPhone,
    required double amount,
  }) async {
    final plan = buildMultiStepPlan(
      till: till,
      type: type,
      customerPhone: customerPhone,
      amount: amount,
    );

    return initiateCustomAutomatedSession(
      rootCode: plan.rootCode,
      steps: plan.steps,
      fallbackShortCode: plan.displayShortCode,
      simSlot: till.simSlot.contains('2') ? 1 : 0,
    );
  }

  /// Check if CALL_PHONE permission is granted natively
  static Future<bool> hasPhonePermission() async {
    try {
      final bool? hasPerm = await _channel.invokeMethod<bool>('hasPhonePermission');
      return hasPerm ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request phone permission natively
  static Future<void> requestPhonePermission() async {
    try {
      await _channel.invokeMethod('requestPhonePermission');
    } catch (_) {}
  }

  /// Initiates automated multi-step USSD session with arbitrary root code and step sequence
  static Future<bool> initiateCustomAutomatedSession({
    required String rootCode,
    required List<String> steps,
    String? fallbackShortCode,
    int simSlot = 0,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('initiateMultiStepUssd', {
        'rootCode': rootCode,
        'steps': steps,
        'simSlot': simSlot,
      });
      if (success == true) return true;
    } catch (e) {
      debugPrint('initiateMultiStepUssd channel call error: $e');
    }

    return dialUssd(fallbackShortCode ?? rootCode, simSlot: simSlot);
  }

  /// Single code dialer
  static Future<bool> dialUssd(String ussdCode, {int simSlot = 0}) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('initiateUssd', {
        'ussdCode': ussdCode,
        'simSlot': simSlot,
      });
      if (success == true) return true;
    } catch (e) {
      debugPrint('initiateUssd channel call error: $e');
    }

    try {
      final encodedCode = ussdCode.replaceAll('#', '%23');
      final Uri uri = Uri.parse('tel:$encodedCode');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('canLaunchUrl error: $e');
    }
    return false;
  }
}
