// lib/services/monetization/ad_service.dart
import 'dart:async'; 
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/logic/ad_display_logic.dart';
import '../../core/utils/time_utils.dart';
import '../local/local_storage_service.dart';
import 'package:flutter/foundation.dart'; // مضاف للطباعة في الـ debug

/// AdService - AdMob Real Implementation
class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ===============================
  // AdMob State Management
  // ===============================
  static const String _interstitialId = 'ca-app-pub-3303379299409244/1725699149';
  
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  int _groupAdsShownToday = 0;
  bool _isInitialized = false;

  // دالة التهيئة لتحميل العدادات من التخزين المحلي
  Future<void> init() async {
    if (_isInitialized) return;
    await _localStorage.init();
    
    // جلب عدد إعلانات الدخول للمجموعات اليوم
    _groupAdsShownToday = _localStorage.getAdsCountToday();
    _isInitialized = true;
    
    await _loadInterstitial();
    debugPrint("✅ AdService Initialized. Group ads shown today: $_groupAdsShownToday");
  }

  Future<void> _loadInterstitial() async {
    if (_isLoading) return;
    _isLoading = true;

    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          debugPrint("📢 Interstitial loaded");
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoading = false;
          debugPrint("❌ Interstitial failed: $error");
        },
      ),
    );
  }

  // ===============================
  // Create Group Ad (بدون حد)
  // ===============================
  Future<bool> showCreateGroupAd({
    required bool isPremium,
  }) async {
    if (isPremium) {
      debugPrint("📢 Ad blocked: premium user");
      return false;
    }

    await init();

    if (_interstitialAd == null) {
      await _loadInterstitial();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
    
    debugPrint("📢 Create Group Ad shown");
    return true;
  }

  // ===============================
  // Group Click Ad (مرتين/يوم + 10 دقائق)
  // ===============================
  Future<bool> showGroupClickAd({
    required bool isPremium,
  }) async {
    if (isPremium) {
      debugPrint("📢 Ad blocked: premium user");
      return false;
    }

    await init();

    final lastAdTime = _localStorage.getLastAdTime();

    // إعادة تعيين العداد إذا بدأ يوم جديد
    if (lastAdTime != null && TimeUtils.isNewDay(lastAdTime)) {
      _groupAdsShownToday = 0;
      await _localStorage.saveAdsCountToday(0);
    }

    // التحقق من الحد اليومي (إعلانين)
    if (_groupAdsShownToday >= 2) {
      debugPrint("📢 Ad Logic: Daily limit reached (2 ads). Skipping.");
      return false;
    }

    // التحقق من مرور 10 دقائق
    if (lastAdTime != null && !TimeUtils.hasMinutesPassed(lastAdTime, 10)) {
      debugPrint("📢 Ad Logic: cooldown active (<10 min). Skipping.");
      return false;
    }

    if (_interstitialAd == null) {
      await _loadInterstitial();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;

    // تحديث البيانات
    await _updateGroupAdStats();

    debugPrint("📢 Group Click Ad shown");
    return true;
  }

  // ===============================
  // PRIVATE HELPER METHODS
  // ===============================

  // تحديث العدادات في الذاكرة وفي التخزين المحلي
  Future<void> _updateGroupAdStats() async {
    _groupAdsShownToday++;
    await _localStorage.saveLastAdTime(DateTime.now());
    await _localStorage.saveAdsCountToday(_groupAdsShownToday);
    debugPrint("📊 Ad stats updated: Group ads today = $_groupAdsShownToday");
  }
}