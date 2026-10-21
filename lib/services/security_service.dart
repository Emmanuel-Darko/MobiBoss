import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'storage_service.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if biometrics or device PIN/pattern is supported on the phone
  static Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the agent for fingerprint, face, or device PIN
  static Future<bool> authenticate({String reason = 'Authenticate to access MobiBoss'}) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return true; // If device has no hardware security, allow pass

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows Android PIN/pattern/fingerprint
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifies the 4-digit Owner PIN before sensitive actions.
  /// If no PIN is configured, returns true immediately.
  /// If a PIN is configured, displays a modern PIN dialog.
  static Future<bool> requireOwnerPin(
    BuildContext context, {
    String title = 'Owner Authorization Required',
    String message = 'Enter the 4-digit Owner PIN to proceed.',
  }) async {
    final savedPin = await StorageService.loadOwnerPin();
    if (savedPin == null || savedPin.isEmpty) {
      return true; // No PIN configured by owner
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OwnerPinDialog(
        title: title,
        message: message,
        expectedPin: savedPin,
      ),
    );

    return result ?? false;
  }
}

class _OwnerPinDialog extends StatefulWidget {
  final String title;
  final String message;
  final String expectedPin;

  const _OwnerPinDialog({
    required this.title,
    required this.message,
    required this.expectedPin,
  });

  @override
  State<_OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<_OwnerPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verify() {
    if (_pinController.text == widget.expectedPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'Incorrect PIN. Try again.';
      });
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8F0FE),
            child: Icon(Icons.shield_rounded, color: Color(0xFF1A73E8), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '••••',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              errorText: _hasError ? _errorMessage : null,
            ),
            onChanged: (val) {
              if (_hasError) setState(() => _hasError = false);
              if (val.length == 4) {
                _verify();
              }
            },
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _verify,
          child: const Text('Authorize'),
        ),
      ],
    );
  }
}

