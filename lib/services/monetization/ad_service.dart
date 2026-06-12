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
  static const String _rewardedId =
      'ca-app-pub-3303379299409244/3412540085';

  // ==========================================
  // 💾 State Management
  // ==========================================
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  int _groupAdsShownToday = 0;
  bool _isInitialized = false;

  static const Duration _adLoadTimeout = Duration(seconds: 15);

  // ==========================================
  // 🔧 التهيئة
  // ==========================================
  Future<void> init() async {
    if (_isInitialized) return;
    await _localStorage.init();
    _groupAdsShownToday = _localStorage.getAdsCountToday();
    _isInitialized = true;
    _loadInterstitial();
    _loadRewarded();
    debugPrint('✅ AdService Initialized.');
  }

  // =========================================================================
  // 🎁 Rewarded Ad
  // =========================================================================

  Future<void> _loadRewarded() async {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('🎁 RewardedAd loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('❌ RewardedAd failed: $error');
        },
      ),
    );
  }

  /// تشغيل إعلان مكافأة واحد — يُستخدم في EarnCoinsScreen
  Future<bool> showSingleRewardedAd({
    required VoidCallback onReward,
  }) async {
    await init();

    // إذا لم يكن محملاً، ابدأ التحميل وانتظر
    if (_rewardedAd == null) {
      _loadRewarded();
      debugPrint('⏳ RewardedAd not ready, waiting...');

      final completer = Completer<void>();
      int waited = 0;
      const checkInterval = Duration(milliseconds: 500);

      while (_rewardedAd == null && waited < _adLoadTimeout.inMilliseconds) {
        await Future.delayed(checkInterval);
        waited += checkInterval.inMilliseconds;
      }

      if (_rewardedAd == null) {
        debugPrint('⏰ RewardedAd timeout');
        return false;
      }
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded(); // preload next
        if (rewardEarned) {
          onReward(); // ✅ فقط إذا شاهد الإعلان كاملاً
        }
        debugPrint('📢 RewardedAd dismissed. Reward earned: $rewardEarned');
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        debugPrint('❌ RewardedAd show failed: $e');
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) {
        rewardEarned = true;
        debugPrint('✅ User earned reward: ${reward.amount} ${reward.type}');
      },
    );

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
      decision: const AdDisplayDecision(
          shouldShow: true, reason: 'create_group'),
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
      decision: const AdDisplayDecision(
          shouldShow: true, reason: 'group_entry'),
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