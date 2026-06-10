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
  static const String _appOpenAdId =
      'ca-app-pub-3303379299409244/3412540085';

  // ==========================================
  // 💾 State Management
  // ==========================================
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _groupAdsShownToday = 0;
  bool _isInitialized = false;

  final List<AppOpenAd> _preloadedAppOpenPool = [];
  bool _isAppOpenPoolLoading = false;

  Completer<void>? _poolReadyCompleter;

  static const int maxBundleSize = 3;
  static const Duration _adLoadTimeout = Duration(seconds: 15);

  // ==========================================
  // 🔧 التهيئة
  // ==========================================
  Future<void> init() async {
    if (_isInitialized) {
      _fillAppOpenPool();
      return;
    }
    await _localStorage.init();
    _groupAdsShownToday = _localStorage.getAdsCountToday();
    _isInitialized = true;
    _loadInterstitial();
    _fillAppOpenPool();
    debugPrint('✅ AdService Initialized.');
  }

  // =========================================================================
  // 🎁 App Open Pool
  // =========================================================================

  Future<void> _fillAppOpenPool() async {
    if (_isAppOpenPoolLoading ||
        _preloadedAppOpenPool.length >= maxBundleSize) return;

    _isAppOpenPoolLoading = true;
    final int needsToLoad = maxBundleSize - _preloadedAppOpenPool.length;
    debugPrint('🔄 AppOpen Pool missing $needsToLoad ads. Preloading...');

    for (int i = 0; i < needsToLoad; i++) {
      await _loadSingleAppOpenAdToPool();
      if (_preloadedAppOpenPool.length >= maxBundleSize) break;
    }

    _isAppOpenPoolLoading = false;
    debugPrint('✅ Pool fill complete. Size: ${_preloadedAppOpenPool.length}');
  }

  Future<void> _loadSingleAppOpenAdToPool() async {
    final completer = Completer<void>();

    AppOpenAd.load(
      adUnitId: _appOpenAdId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (_preloadedAppOpenPool.length < maxBundleSize) {
            _preloadedAppOpenPool.add(ad);
            debugPrint(
                '🎁 AppOpen pooled. Size: ${_preloadedAppOpenPool.length}');

            if (_poolReadyCompleter != null &&
                !_poolReadyCompleter!.isCompleted) {
              _poolReadyCompleter!.complete();
            }
          } else {
            ad.dispose();
          }
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ AppOpen failed: $error');
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    return completer.future;
  }

  Future<bool> _waitForPoolReady() async {
    if (_preloadedAppOpenPool.isNotEmpty) return true;

    debugPrint('⏳ Waiting for AppOpen pool (max ${_adLoadTimeout.inSeconds}s)...');

    if (_poolReadyCompleter == null || _poolReadyCompleter!.isCompleted) {
      _poolReadyCompleter = Completer<void>();
    }

    if (!_isAppOpenPoolLoading) {
      _fillAppOpenPool();
    }

    try {
      await _poolReadyCompleter!.future.timeout(_adLoadTimeout);
      debugPrint('✅ Pool ready after waiting.');
      return _preloadedAppOpenPool.isNotEmpty;
    } on TimeoutException {
      debugPrint('⏰ Timeout: AppOpen pool did not load in time.');
      return false;
    }
  }

  /// تشغيل إعلان AppOpen واحد
  Future<bool> showSingleRewardedAd({required VoidCallback onReward}) async {
    await init();

    if (_preloadedAppOpenPool.isEmpty) {
      final ready = await _waitForPoolReady();
      if (!ready) {
        debugPrint('❌ showSingleAppOpenAd: pool still empty after timeout.');
        return false;
      }
    }

    final ad = _preloadedAppOpenPool.removeAt(0);

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onReward(); // ✅ يُستدعى عند إغلاق الإعلان
        _fillAppOpenPool();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _fillAppOpenPool();
        debugPrint('❌ Failed to show AppOpen: $e');
      },
    );

    ad.show();
    return true;
  }

  /// تشغيل حزمة 3 إعلانات AppOpen متتالية
  Future<bool> showRewardedAdBundle({
    required VoidCallback onSingleAdFinished,
    required VoidCallback onAllAdsCompleted,
    required VoidCallback onFailed,
  }) async {
    await init();

    if (_preloadedAppOpenPool.length < maxBundleSize) {
      debugPrint(
          '⚠️ Pool not ready: ${_preloadedAppOpenPool.length}/$maxBundleSize');
      _fillAppOpenPool();
      return false;
    }

    final List<AppOpenAd> bundle =
        List.from(_preloadedAppOpenPool.take(maxBundleSize));
    _preloadedAppOpenPool.removeRange(0, maxBundleSize);

    int index = 0;

    void showNext() {
      if (index >= bundle.length) {
        debugPrint('🎉 All 3 bundled AppOpen ads done!');
        _fillAppOpenPool();
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
          debugPrint('❌ Bundle AppOpen ad $index failed: $e');
          _fillAppOpenPool();
          onFailed();
        },
      );
      ad.show();
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

  Future<bool> showCreateGroupAd({required bool isPremium}) async {
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
      _loadInterstitial();
      debugPrint('📢 Create Group Ad: not ready');
      return false;
    }

    debugPrint('📢 Showing Create Group Interstitial...');
    return _showInterstitialNow();
  }

  Future<bool> showGroupEntryAd({required bool isPremium}) async {
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

    if (lastAdTime != null && TimeUtils.isNewDay(lastAdTime)) {
      _groupAdsShownToday = 0;
      await _localStorage.saveAdsCountToday(0);
    }

    final dailyCheck = AdDisplayLogic.checkDailyLimit(_groupAdsShownToday);
    if (!dailyCheck.shouldShow) {
      debugPrint('📢 Group Entry Ad: ${dailyCheck.reason}');
      return false;
    }

    final cooldownCheck = AdDisplayLogic.checkTenMinutesRule(lastAdTime);
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

  Future<bool> showGroupClickAd({required bool isPremium}) =>
      showGroupEntryAd(isPremium: isPremium);

  Future<void> _updateGroupAdStats() async {
    _groupAdsShownToday++;
    await _localStorage.saveLastAdTime(DateTime.now());
    await _localStorage.saveAdsCountToday(_groupAdsShownToday);
  }
}