// lib/services/monetization/ad_service.dart
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/utils/time_utils.dart';
import '../../core/logic/ad_display_logic.dart';
import '../local/local_storage_service.dart';
import 'package:flutter/foundation.dart';

class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ==========================================
  // 🆔 Ad Unit IDs
  // ==========================================
  static const String _interstitialId =
      'ca-app-pub-3303379299409244/1725699149';
  static const String _rewardedAdId =
      'ca-app-pub-3303379299409244/3412540085';

  // ==========================================
  // 💾 State Management
  // ==========================================
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _groupAdsShownToday = 0;
  bool _isInitialized = false;

  final List<RewardedAd> _preloadedRewardedPool = [];

  // ✅ إصلاح #3: الآن يُضبط true قبل بدء التحميل ويُعاد false عند الانتهاء
  bool _isRewardedPoolLoading = false;

  static const int maxBundleSize = 3;

  // ==========================================
  // 🔧 التهيئة
  // ==========================================
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
    debugPrint('✅ AdService Initialized.');
  }

  // =========================================================================
  // 🎁 Rewarded Pool
  // =========================================================================

  // ✅ إصلاح #3: وضع _isRewardedPoolLoading = true فور الدخول
  Future<void> _fillRewardedPool() async {
    if (_isRewardedPoolLoading ||
        _preloadedRewardedPool.length >= maxBundleSize) return;

    _isRewardedPoolLoading = true;
    final int needsToLoad =
        maxBundleSize - _preloadedRewardedPool.length;
    debugPrint(
        '🔄 Rewarded Pool missing $needsToLoad ads. Preloading...');

    int loadedCount = 0;

    for (int i = 0; i < needsToLoad; i++) {
      await _loadSingleRewardedAdToPool();
      loadedCount++;
      if (_preloadedRewardedPool.length >= maxBundleSize) break;
    }

    _isRewardedPoolLoading = false;
    debugPrint(
        '✅ Pool fill complete. Size: ${_preloadedRewardedPool.length}');
  }

  Future<void> _loadSingleRewardedAdToPool() async {
    final completer = Completer<void>();

    RewardedAd.load(
      adUnitId: _rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_preloadedRewardedPool.length < maxBundleSize) {
            _preloadedRewardedPool.add(ad);
            debugPrint(
                '🎁 Rewarded pooled. Size: ${_preloadedRewardedPool.length}');
          } else {
            ad.dispose(); // تجاهل الزائد
          }
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded failed: $error');
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    return completer.future;
  }

  /// تشغيل إعلان مكافأة واحد (صفحة كسب العملات)
  Future<bool> showSingleRewardedAd(
      {required VoidCallback onReward}) async {
    await init();

    if (_preloadedRewardedPool.isEmpty) {
      debugPrint('⚠️ Rewarded Pool empty.');
      _fillRewardedPool();
      return false;
    }

    final ad = _preloadedRewardedPool.removeAt(0);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _fillRewardedPool();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _fillRewardedPool();
        debugPrint('❌ Failed to show Rewarded: $e');
      },
    );

    ad.show(onUserEarnedReward: (_, __) {
      onReward();
      debugPrint('💎 User earned reward');
    });

    return true;
  }

  /// تشغيل حزمة 3 إعلانات متتالية
  Future<bool> showRewardedAdBundle({
    required VoidCallback onSingleAdFinished,
    required VoidCallback onAllAdsCompleted,
    required VoidCallback onFailed,
  }) async {
    await init();

    if (_preloadedRewardedPool.length < maxBundleSize) {
      debugPrint(
          '⚠️ Pool not ready: ${_preloadedRewardedPool.length}/$maxBundleSize');
      _fillRewardedPool();
      return false;
    }

    final List<RewardedAd> bundle =
        List.from(_preloadedRewardedPool.take(maxBundleSize));
    _preloadedRewardedPool.removeRange(0, maxBundleSize);

    int index = 0;

    void showNext() {
      if (index >= bundle.length) {
        debugPrint('🎉 All 3 bundled ads done!');
        _fillRewardedPool();
        onAllAdsCompleted();
        return;
      }

      final ad = bundle[index];
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          onSingleAdFinished();
          index++;
          showNext();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          a.dispose();
          debugPrint('❌ Bundle ad $index failed: $e');
          _fillRewardedPool();
          onFailed();
        },
      );
      ad.show(onUserEarnedReward: (_, __) {
        debugPrint('💎 Bundle reward #$index verified');
      });
    }

    showNext();
    return true;
  }

  // =========================================================================
  // 🔒 Interstitial
  // =========================================================================

  Future<void> _loadInterstitial() async {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('📢 Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('❌ Interstitial failed: $error');
        },
      ),
    );
  }

  bool _showInterstitialNow() {
    if (_interstitialAd == null) return false;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        debugPrint('❌ Interstitial show failed: $error');
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
    return true;
  }

  // ✅ إصلاح #1 + #2: دالة إنشاء المجموعة — بدون حد يومي، تعمل مع await
  Future<bool> showCreateGroupAd({required bool isPremium}) async {
    // ✅ إصلاح #4: استخدام AdDisplayLogic
    final premiumCheck = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: const AdDisplayDecision(shouldShow: true, reason: 'create_group'),
    );
    if (!premiumCheck.shouldShow) {
      debugPrint('📢 Create Group Ad: blocked — ${premiumCheck.reason}');
      return false;
    }

    await init();

    if (_interstitialAd == null) {
      _loadInterstitial(); // تحميل للمرة القادمة
      debugPrint('📢 Create Group Ad: not ready');
      return false;
    }

    debugPrint('📢 Showing Create Group Interstitial...');
    return _showInterstitialNow();
  }

  // ✅ إصلاح #1: دالة منفصلة لدخول المجموعة — مع حد يومي و10 دقائق
  Future<bool> showGroupEntryAd({required bool isPremium}) async {
    // ✅ إصلاح #4: استخدام AdDisplayLogic للـ premium check
    final premiumCheck = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: const AdDisplayDecision(shouldShow: true, reason: 'group_entry'),
    );
    if (!premiumCheck.shouldShow) {
      debugPrint('📢 Group Entry Ad: blocked — ${premiumCheck.reason}');
      return false;
    }

    await init();

    final lastAdTime = _localStorage.getLastAdTime();

    // ✅ إصلاح #4: استخدام AdDisplayLogic لفحص اليوم الجديد
    if (lastAdTime != null && TimeUtils.isNewDay(lastAdTime)) {
      _groupAdsShownToday = 0;
      await _localStorage.saveAdsCountToday(0);
    }

    // ✅ إصلاح #4: استخدام AdDisplayLogic للحد اليومي
    final dailyCheck =
        AdDisplayLogic.checkDailyLimit(_groupAdsShownToday);
    if (!dailyCheck.shouldShow) {
      debugPrint('📢 Group Entry Ad: ${dailyCheck.reason}');
      return false;
    }

    // ✅ إصلاح #4: استخدام AdDisplayLogic لقاعدة 10 دقائق
    final cooldownCheck =
        AdDisplayLogic.checkTenMinutesRule(lastAdTime);
    if (!cooldownCheck.shouldShow) {
      debugPrint('📢 Group Entry Ad: ${cooldownCheck.reason}');
      return false;
    }

    if (_interstitialAd == null) {
      _loadInterstitial();
      debugPrint('📢 Group Entry Ad: not ready');
      return false;
    }

    debugPrint('📢 Showing Group Entry Interstitial...');
    final shown = _showInterstitialNow();
    if (shown) await _updateGroupAdStats();
    return shown;
  }

  // باقي للتوافق مع الكود القديم إذا كان هناك استدعاء لها في مكان آخر
  Future<bool> showGroupClickAd({required bool isPremium}) =>
      showGroupEntryAd(isPremium: isPremium);

  Future<void> _updateGroupAdStats() async {
    _groupAdsShownToday++;
    await _localStorage.saveLastAdTime(DateTime.now());
    await _localStorage.saveAdsCountToday(_groupAdsShownToday);
  }
}