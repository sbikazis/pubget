// lib/services/monetization/ad_service.dart
import 'dart:async'; 
import '../../core/logic/ad_display_logic.dart';
import '../local/local_storage_service.dart';
import 'package:flutter/foundation.dart'; // مضاف للطباعة في الـ debug

/// AdService - Ghost Logic Version (تجهيز لنظام AppLovin مستقبلاً)
class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ===============================
  // Ghost State Management
  // ===============================
  int _adsShownToday = 0;
  bool _isInitialized = false;

  // دالة التهيئة لتحميل العدادات من التخزين المحلي
  Future<void> init() async {
    if (_isInitialized) return;
    await _localStorage.init();
    
    // جلب عدد إعلانات اليوم المخزنة (سنفترض وجود دالة في الـ local storage لهذا)
    // وإعادة تعيينها إذا بدأ يوم جديد
    _adsShownToday = _localStorage.getAdsCountToday(); 
    _isInitialized = true;
    debugPrint("✅ AdService (Ghost) Initialized. Ads shown today: $_adsShownToday");
  }

  // ===============================
  // Morning App Open Ad (Ghost)
  // ===============================
  Future<bool> tryShowMorningAd({
    required bool isPremium,
  }) async {
    await init();

    final lastAdTime = _localStorage.getLastAdTime();

    // التحقق من المنطق (يوم جديد، بريميوم، إلخ)
    var decision = AdDisplayLogic.checkMorningAd(lastAdTime);
    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    // التحقق من الحد اليومي (3 إعلانات)
    if (decision.shouldShow && _adsShownToday >= 3) {
      debugPrint("📢 Ad Logic (Ghost): Daily limit reached (3 ads). Skipping.");
      return false;
    }

    if (!decision.shouldShow) return false;

    // محاكاة إظهار الإعلان
    _executeGhostAd("Morning App Open Ad");
    
    // تحديث البيانات
    await _updateAdStats();

    return true;
  }

  // ===============================
  // Group/Action Ad (Ghost)
  // ===============================
  Future<bool> tryShowGroupAd({
    required bool isPremium,
  }) async {
    await init();

    final lastAdTime = _localStorage.getLastAdTime();

    // التحقق من قاعدة الـ 5 دقائق
    var decision = AdDisplayLogic.checkFiveMinutesRule(lastAdTime);
    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    // التحقق من الحد اليومي
    if (decision.shouldShow && _adsShownToday >= 3) {
      debugPrint("📢 Ad Logic (Ghost): Daily limit reached (3 ads). Skipping.");
      return false;
    }

    if (!decision.shouldShow) return false;

    // محاكاة إظهار الإعلان
    _executeGhostAd("Interstitial/Action Ad");

    // تحديث البيانات
    await _updateAdStats();

    return true;
  }

  // ===============================
  // PRIVATE HELPER METHODS
  // ===============================

  // وظيفة وهمية تحاكي تشغيل الإعلان
  void _executeGhostAd(String adType) {
    debugPrint("--------------------------------------------------");
    debugPrint("📢 AppLovin Ghost: $adType triggered!");
    debugPrint("💡 This is where the SDK code will be placed.");
    debugPrint("--------------------------------------------------");
  }

  // تحديث العدادات في الذاكرة وفي التخزين المحلي
  Future<void> _updateAdStats() async {
    _adsShownToday++;
    await _localStorage.saveLastAdTime(DateTime.now());
    await _localStorage.saveAdsCountToday(_adsShownToday);
    debugPrint("📊 Ad stats updated: Shown Today = $_adsShownToday");
  }
}