import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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
  }) {
    final amtFormatted = amount.toStringAsFixed(0);

    switch (till.network) {
      case NetworkProvider.mtn:
        if (type == TransactionType.cashIn) {
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['1', '1', customerPhone, customerPhone, amtFormatted, 'POS'],
            displayShortCode: '*171*1*1*$customerPhone*$customerPhone*$amtFormatted#',
          );
        } else if (type == TransactionType.cashOut) {
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['1', '2', customerPhone, amtFormatted],
            displayShortCode: '*171*1*2*$customerPhone*$amtFormatted#',
          );
        } else if (type == TransactionType.airtime) {
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['3', '1', customerPhone, amtFormatted],
            displayShortCode: '*171*3*1*$customerPhone*$amtFormatted#',
          );
        } else {
          return MultiStepUssdPlan(
            rootCode: '*171#',
            steps: ['3', '2', customerPhone, amtFormatted],
            displayShortCode: '*171*3*2*$customerPhone*$amtFormatted#',
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
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['3', '1', targetAccountOrPhone, amtFormatted]
              : ['3', '1', targetAccountOrPhone, amtFormatted],
          displayShortCode: '*171*3*1*$targetAccountOrPhone*$amtFormatted#',
        );

      case TransactionType.dataBundle:
        final packageOption = extraParameter ?? '1';
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: till.network == NetworkProvider.mtn
              ? ['3', '2', targetAccountOrPhone, packageOption, amtFormatted]
              : ['3', '2', targetAccountOrPhone, packageOption],
          displayShortCode: '*171*3*2*$targetAccountOrPhone#',
        );

      case TransactionType.ecgElectricity:
        final meterNumber = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: ['2', '1', '1', meterNumber, amtFormatted],
          displayShortCode: '*171*2*1*1*$meterNumber*$amtFormatted#',
        );

      case TransactionType.ghanaWater:
        final accountNo = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: ['2', '1', '2', accountNo, amtFormatted],
          displayShortCode: '*171*2*1*2*$accountNo*$amtFormatted#',
        );

      case TransactionType.payTv:
        final smartcard = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: ['2', '2', '1', smartcard, amtFormatted],
          displayShortCode: '*171*2*2*1*$smartcard*$amtFormatted#',
        );

      case TransactionType.bankTransfer:
        final accountNumber = extraParameter ?? targetAccountOrPhone;
        return MultiStepUssdPlan(
          rootCode: till.network == NetworkProvider.mtn ? '*171#' : '*110#',
          steps: ['1', '3', '1', accountNumber, amtFormatted],
          displayShortCode: '*171*1*3*1*$accountNumber*$amtFormatted#',
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
          '5', // My Account
          '3', // Commission
          toMainFloat ? '1' : '2', // 1 = To Float, 2 = To MoMo Wallet
          amtFormatted,
        ],
        displayShortCode: '*171*5*3*${toMainFloat ? "1" : "2"}*$amtFormatted#',
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

  /// Initiates automated multi-step USSD session with arbitrary root code and step sequence
  static Future<bool> initiateCustomAutomatedSession({
    required String rootCode,
    required List<String> steps,
    String? fallbackShortCode,
    int simSlot = 0,
  }) async {
    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        final bool? success = await _channel.invokeMethod<bool>('initiateMultiStepUssd', {
          'rootCode': rootCode,
          'steps': steps,
          'simSlot': simSlot,
        });
        if (success == true) return true;
      }
    } catch (_) {}

    return dialUssd(fallbackShortCode ?? rootCode, simSlot: simSlot);
  }

  /// Single code dialer
  static Future<bool> dialUssd(String ussdCode, {int simSlot = 0}) async {
    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        final bool? success = await _channel.invokeMethod<bool>('initiateUssd', {
          'ussdCode': ussdCode,
          'simSlot': simSlot,
        });
        if (success == true) return true;
      }
    } catch (_) {}

    final encodedCode = ussdCode.replaceAll('#', '%23');
    final Uri uri = Uri.parse('tel:$encodedCode');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
}
