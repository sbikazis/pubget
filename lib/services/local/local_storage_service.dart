
import 'package:shared_preferences/shared_preferences.dart';

/// LocalStorageService

class LocalStorageService {
  // المفاتيح المستخدمة للتخزين
  static const String _lastAdTimeKey = 'last_ad_time';
  static const String _darkModeKey = 'dark_mode';

  // Singleton instance
  LocalStorageService._privateConstructor();
  static final LocalStorageService instance = LocalStorageService._privateConstructor();

  SharedPreferences? _prefs;

  /// تهيئة SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // =========================
  // وظائف الإعلان
  // =========================

  /// حفظ آخر وقت ظهور إعلان
  Future<void> saveLastAdTime(DateTime time) async {
    await init();
    await _prefs!.setInt(_lastAdTimeKey, time.millisecondsSinceEpoch);
  }

  /// استرجاع آخر وقت ظهور إعلان
  DateTime? getLastAdTime() {
    if (_prefs == null) return null;
    final millis = _prefs!.getInt(_lastAdTimeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// التحقق إذا يمكن عرض إعلان بناءً على مدة التهدئة
  bool canShowAd(Duration cooldown) {
    final lastAd = getLastAdTime();
    if (lastAd == null) return true;
    return DateTime.now().difference(lastAd) >= cooldown;
  }

  // =========================
  // إعدادات عامة
  // =========================

  /// حفظ وضع التطبيق (داكن/فاتح)
  Future<void> saveDarkMode(bool isDark) async {
    await init();
    await _prefs!.setBool(_darkModeKey, isDark);
  }

  /// استرجاع وضع التطبيق
  bool getDarkMode() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_darkModeKey) ?? false;
  }

  // =========================
  // وظائف عامة للتخزين
  // =========================

  Future<void> saveString(String key, String value) async {
    await init();
    await _prefs!.setString(key, value);
  }

  String? getString(String key) {
    if (_prefs == null) return null;
    return _prefs!.getString(key);
  }

  Future<void> saveBool(String key, bool value) async {
    await init();
    await _prefs!.setBool(key, value);
  }

  bool? getBool(String key) {
    if (_prefs == null) return null;
    return _prefs!.getBool(key);
  }

  Future<void> saveInt(String key, int value) async {
    await init();
    await _prefs!.setInt(key, value);
  }

  int? getInt(String key) {
    if (_prefs == null) return null;
    return _prefs!.getInt(key);
  }

  Future<void> remove(String key) async {
    await init();
    await _prefs!.remove(key);
  }

  /// مسح جميع البيانات المحلية (لتسجيل الخروج أو إعادة ضبط التطبيق)
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }
}