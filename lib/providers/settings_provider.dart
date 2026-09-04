import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';

/// Holds theme mode + security/app-lock settings, backed by Hive settings
/// box for persistence across app restarts.
class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  final DatabaseService _db = DatabaseService.instance;
  final SecurityService security = SecurityService();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// True once the app has been unlocked for the current session
  /// (relevant only when app lock is enabled).
  bool isUnlocked = false;

  void load() {
    final stored = _db.settingsBox.get(_themeModeKey) as String?;
    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    // If no app lock configured, session starts unlocked.
    isUnlocked = !security.isAppLockEnabled;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _db.settingsBox.put(_themeModeKey, value);
    notifyListeners();
  }

  void unlock() {
    isUnlocked = true;
    notifyListeners();
  }

  void lock() {
    if (security.isAppLockEnabled) {
      isUnlocked = false;
      notifyListeners();
    }
  }
}
