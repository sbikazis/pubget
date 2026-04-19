// lib/services/local/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// LocalStorageService
class LocalStorageService {
  // المفاتيح المستخدمة للتخزين
  static const String _lastAdTimeKey = 'last_ad_time';
  static const String _adsCountKey = 'ads_count_today'; // ✅ مفتاح العداد
  static const String _lastAdDateKey = 'last_ad_date_string'; // ✅ مفتاح تاريخ اليوم
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
  // ✅ وظائف الإعلان (المحدثة)
  // =========================

  /// حفظ آخر وقت ظهور إعلان
  Future<void> saveLastAdTime(DateTime time) async {
    await init();
    await _prefs!.setInt(_lastAdTimeKey, time.millisecondsSinceEpoch);
    // حفظ تاريخ اليوم بصيغة (YYYY-MM-DD) لمقارنته لاحقاً وتصفير العداد
    await _prefs!.setString(_lastAdDateKey, "${time.year}-${time.month}-${time.day}");
  }

  /// استرجاع آخر وقت ظهور إعلان
  DateTime? getLastAdTime() {
    if (_prefs == null) return null;
    final millis = _prefs!.getInt(_lastAdTimeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// ✅ حفظ عدد إعلانات اليوم
  Future<void> saveAdsCountToday(int count) async {
    await init();
    await _prefs!.setInt(_adsCountKey, count);
  }

  /// ✅ استرجاع عدد إعلانات اليوم مع منطق التصفير التلقائي
  int getAdsCountToday() {
    if (_prefs == null) return 0;

    final lastDate = _prefs!.getString(_lastAdDateKey);
    final now = DateTime.now();
    final todayDate = "${now.year}-${now.month}-${now.day}";

    // إذا كان التاريخ المخزن يختلف عن تاريخ اليوم، صفر العداد فوراً
    if (lastDate != todayDate) {
      saveAdsCountToday(0);
      return 0;
    }

    return _prefs!.getInt(_adsCountKey) ?? 0;
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

  /// مسح جميع البيانات المحلية
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }
}