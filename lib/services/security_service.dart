import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'database_service.dart';

/// Handles PIN hashing/verification and biometric authentication.
/// PIN is never stored in plaintext -- only a salted SHA-256 hash.
class SecurityService {
  static const String _pinHashKey = 'pin_hash';
  static const String _pinSaltKey = 'pin_salt';
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _biometricEnabledKey = 'biometric_enabled';

  final DatabaseService _db = DatabaseService.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get isAppLockEnabled =>
      _db.settingsBox.get(_appLockEnabledKey, defaultValue: false) as bool;

  bool get isBiometricEnabled =>
      _db.settingsBox.get(_biometricEnabledKey, defaultValue: false) as bool;

  bool get hasPinSet => _db.settingsBox.get(_pinHashKey) != null;

  Future<void> setAppLockEnabled(bool enabled) async {
    await _db.settingsBox.put(_appLockEnabledKey, enabled);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _db.settingsBox.put(_biometricEnabledKey, enabled);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = _hash(pin, salt);
    await _db.settingsBox.put(_pinSaltKey, salt);
    await _db.settingsBox.put(_pinHashKey, hash);
    await setAppLockEnabled(true);
  }

  bool verifyPin(String pin) {
    final salt = _db.settingsBox.get(_pinSaltKey) as String?;
    final storedHash = _db.settingsBox.get(_pinHashKey) as String?;
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  Future<void> clearPin() async {
    await _db.settingsBox.delete(_pinHashKey);
    await _db.settingsBox.delete(_pinSaltKey);
    await setAppLockEnabled(false);
    await setBiometricEnabled(false);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'অ্যাপ আনলক করতে যাচাই করুন',
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
