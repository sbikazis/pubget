// lib/services/monetization/ad_service.dart
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/utils/time_utils.dart';
import '../local/local_storage_service.dart';
import 'package:flutter/foundation.dart';

/// AdService - AdMob Real Dual Implementation (Interstitial + Rewarded Tri-Bundle)
class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ==========================================
  // 🆔 معرفات الوحدات الإعلانية (Ad Units IDs)
  // ==========================================
  static const String _interstitialId = 'ca-app-pub-3303379299409244/1725699149';
  static const String _rewardedAdId = 'ca-app-pub-3303379299409244/3412540085';

  // ==========================================
  // 💾 إدارة حالات الإعلانات (State Management)
  // ==========================================
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _groupAdsShownToday = 0;
  bool _isInitialized = false;

  final List<RewardedAd> _preloadedRewardedPool = [];
  bool _isRewardedPoolLoading = false;
  static const int maxBundleSize = 3;

  /// دالة التهيئة الشاملة
  Future<void> init() async {
    if (_isInitialized) {
      _fillRewardedPool();
      return;
    }
    await _localStorage.init();

    _groupAdsShownToday = _localStorage.getAdsCountToday();
    _isInitialized = true;

    _loadInterstitial();
    _fillRewardedPool();

    debugPrint("✅ AdService Initialized. Interstitial & Rewarded Pool ready.");
  }

  // =========================================================================
  // 🎁 نظام حزمة إعلانات المكافأة
  // =========================================================================

  Future<void> _fillRewardedPool() async {
    if (_isRewardedPoolLoading || _preloadedRewardedPool.length >= maxBundleSize) return;

    int needsToLoad = maxBundleSize - _preloadedRewardedPool.length;
    debugPrint("🔄 Rewarded Pool missing $needsToLoad ads. Preloading dynamically...");

    for (int i = 0; i < needsToLoad; i++) {
      _loadSingleRewardedAdToPool();
    }
  }

  void _loadSingleRewardedAdToPool() {
    RewardedAd.load(
      adUnitId: _rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadedRewardedPool.add(ad);
          debugPrint("🎁 Rewarded Ad loaded and pooled. Current Size: ${_preloadedRewardedPool.length}");
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Single Rewarded Ad failed to load: $error. Retrying in background...");
          Future.delayed(const Duration(seconds: 5), () => _loadSingleRewardedAdToPool());
        },
      ),
    );
  }

  /// ✅ دالة جديدة: تشغيل إعلان مكافأة واحد فقط
  Future<bool> showSingleRewardedAd({required VoidCallback onReward}) async {
    await init();
    if (_preloadedRewardedPool.isEmpty) {
      debugPrint("⚠️ Rewarded Pool empty. Triggering fill...");
      _fillRewardedPool();
      return false; // غير جاهز
    }

    final ad = _preloadedRewardedPool.removeAt(0);
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _fillRewardedPool(); // عبي الخزنة بعد كل مشاهدة
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _fillRewardedPool();
        debugPrint("❌ Failed to show Rewarded Ad: $e");
      },
    );

    ad.show(onUserEarnedReward: (_, __) {
      rewarded = true;
      onReward();
      debugPrint("💎 User earned reward for single ad");
    });

    return true;
  }

  /// 🔥 تشغيل حزمة الـ 3 إعلانات المتتالية
  Future<bool> showRewardedAdBundle({
    required VoidCallback onSingleAdFinished,
    required VoidCallback onAllAdsCompleted,
    required VoidCallback onFailed,
  }) async {
    await init();

    if (_preloadedRewardedPool.length < maxBundleSize) {
      debugPrint("⚠️ Rewarded Pool not ready yet. Available: ${_preloadedRewardedPool.length}/$maxBundleSize");
      _fillRewardedPool();
      return false;
    }

    final List<RewardedAd> adsToBrief = List.from(_preloadedRewardedPool.take(maxBundleSize));
    _preloadedRewardedPool.removeRange(0, maxBundleSize);

    int currentAdIndex = 0;

    void showNextRewarded() {
      if (currentAdIndex >= adsToBrief.length) {
        debugPrint("🎉 Success: All 3 bundled Rewarded Ads finished successfully!");
        _fillRewardedPool();
        onAllAdsCompleted();
        return;
      }

      final ad = adsToBrief[currentAdIndex];

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (dismissedAd) {
          dismissedAd.dispose();
          onSingleAdFinished();
          currentAdIndex++;
          showNextRewarded();
        },
        onAdFailedToShowFullScreenContent: (failedAd, error) {
          failedAd.dispose();
          debugPrint("❌ Failed to show Rewarded Ad at index $currentAdIndex: $error");
          _fillRewardedPool();
          onFailed();
        },
      );

      ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint("💎 User verified for single ad reward by Admob backend.");
      });
    }

    showNextRewarded();
    return true;
  }

  // =========================================================================
  // 🔒 نظام الإعلانات البينية (Interstitial)
  // =========================================================================

  Future<void> _loadInterstitial() async {
    if (_isInterstitialLoading || _interstitialAd!= null) return;
    _isInterstitialLoading = true;

    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint("📢 Interstitial loaded");
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint("❌ Interstitial failed: $error");
        },
      ),
    );
  }

  Future<bool> showCreateGroupAd({required bool isPremium}) async {
    if (isPremium) return false;
    await init();

    if (_interstitialAd == null) {
      await _loadInterstitial();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadInterstitial(); },
      onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _loadInterstitial(); },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
    return true;
  }

  Future<bool> showGroupClickAd({required bool isPremium}) async {
    if (isPremium) return false;
    await init();

    final lastAdTime = _localStorage.getLastAdTime();

    if (lastAdTime!= null && TimeUtils.isNewDay(lastAdTime)) {
      _groupAdsShownToday = 0;
      await _localStorage.saveAdsCountToday(0);
    }

    if (_groupAdsShownToday >= 2) return false;
    if (lastAdTime!= null &&!TimeUtils.hasMinutesPassed(lastAdTime, 10)) return false;

    if (_interstitialAd == null) {
      await _loadInterstitial();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadInterstitial(); },
      onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _loadInterstitial(); },
    );

    _interstitialAd!.show();
    _interstitialAd = null;

    await _updateGroupAdStats();
    return true;
  }

  Future<void> _updateGroupAdStats() async {
    _groupAdsShownToday++;
    await _localStorage.saveLastAdTime(DateTime.now());
    await _localStorage.saveAdsCountToday(_groupAdsShownToday);
  }
}
