import 'package:flutter/material.dart';
import '../services/local/local_storage_service.dart';
import '../core/theme/dark_theme.dart';
import '../core/theme/light_theme.dart';


class SettingsProvider extends ChangeNotifier {
  // ===============================
  //  SERVICES
  // ===============================
  final LocalStorageService _localStorage = LocalStorageService.instance;

  // ===============================
  //  SETTINGS STATE
  // ===============================

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  ThemeData get currentTheme => _isDarkMode ? DarkTheme.theme : LightTheme.theme;

  // ===============================
  //  INITIALIZATION
  // ===============================

  /// تحميل الإعدادات من التخزين المحلي عند بدء التطبيق
  Future<void> loadSettings() async {
    await _localStorage.init();
    _isDarkMode = _localStorage.getDarkMode();
    // يمكن إضافة استرجاع الإشعارات هنا مستقبلاً
    notifyListeners();
  }

  // ===============================
  //  DARK MODE
  // ===============================

  /// تبديل الوضع الداكن / الفاتح
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _localStorage.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  /// تعيين الوضع مباشرة (مثلاً عند تحميل الإعدادات)
  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _localStorage.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  // ===============================
  //  NOTIFICATIONS
  // ===============================

  /// تمكين أو تعطيل الإشعارات
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _localStorage.saveBool('notifications_enabled', enabled);
    notifyListeners();
  }

  /// استرجاع حالة الإشعارات
  Future<void> loadNotificationsSetting() async {
    await _localStorage.init();
    _notificationsEnabled = _localStorage.getBool('notifications_enabled') ?? true;
    notifyListeners();
  }

  // ===============================
  //  RESET SETTINGS
  // ===============================

  /// إعادة ضبط جميع الإعدادات (مثلاً عند تسجيل الخروج)
  Future<void> resetSettings() async {
    _isDarkMode = false;
    _notificationsEnabled = true;
    await _localStorage.clearAll();
    notifyListeners();
  }
}