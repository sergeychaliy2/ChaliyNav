import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric / device-credential gate. Used by [AppLockScreen] on launch
/// (when the user enabled appLock in settings) and by `secretCategoryLocked`
/// guards.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final _auth = LocalAuthentication();

  Future<bool> get canCheckBiometrics async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Prompt the user — returns `true` on success.
  /// Caller should handle false (do not unlock the app / show login).
  Future<bool> authenticate({
    String reason = 'Подтвердите доступ к ChaliyNav',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN / pattern as fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
