import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

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
}
