// lib/services/local/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// LocalStorageService
class LocalStorageService {
  // المفاتيح المستخدمة للتخزين
  static const String _lastAdTimeKey = 'last_ad_time';
  static const String _adsCountKey = 'ads_count_today';
  static const String _lastAdDateKey = 'last_ad_date_string';
  static const String _darkModeKey = 'dark_mode';
  static const String _savedGifsKey = 'saved_gifs';
  static const String _pendingInviterKey = 'pending_inviter'; // <-- جديد

  // Singleton instance
  LocalStorageService._privateConstructor();
  static final LocalStorageService instance = LocalStorageService._privateConstructor();

  SharedPreferences? _prefs;

  /// تهيئة SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // =========================
  // ✅ وظائف الدعوة والإحالة - جديد
  // =========================

  Future<void> savePendingInviter(String id) => saveString(_pendingInviterKey, id);
  
  String? getPendingInviter() => getString(_pendingInviterKey);
  
  Future<void> clearPendingInviter() => remove(_pendingInviterKey);

  // =========================
  // ✅ وظائف الإعلان
  // =========================

  Future<void> saveLastAdTime(DateTime time) async {
    await init();
    await _prefs!.setInt(_lastAdTimeKey, time.millisecondsSinceEpoch);
    await _prefs!.setString(_lastAdDateKey, "${time.year}-${time.month}-${time.day}");
  }

  DateTime? getLastAdTime() {
    if (_prefs == null) return null;
    final millis = _prefs!.getInt(_lastAdTimeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> saveAdsCountToday(int count) async {
    await init();
    await _prefs!.setInt(_adsCountKey, count);
  }

  int getAdsCountToday() {
    if (_prefs == null) return 0;

    final lastDate = _prefs!.getString(_lastAdDateKey);
    final now = DateTime.now();
    final todayDate = "${now.year}-${now.month}-${now.day}";

    if (lastDate != todayDate) {
      saveAdsCountToday(0);
      return 0;
    }

    return _prefs!.getInt(_adsCountKey) ?? 0;
  }

  bool canShowAd(Duration cooldown) {
    final lastAd = getLastAdTime();
    if (lastAd == null) return true;
    return DateTime.now().difference(lastAd) >= cooldown;
  }

  // =========================
  // إعدادات عامة
  // =========================

  Future<void> saveDarkMode(bool isDark) async {
    await init();
    await _prefs!.setBool(_darkModeKey, isDark);
  }

  bool getDarkMode() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_darkModeKey) ?? false;
  }

  // =========================
  // ✅ وظائف GIF المحفوظة
  // =========================

  Future<void> saveGifs(List<String> urls) async {
    await init();
    await _prefs!.setStringList(_savedGifsKey, urls);
  }

  List<String> getSavedGifs() {
    if (_prefs == null) return [];
    return _prefs!.getStringList(_savedGifsKey) ?? [];
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

  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }
}
