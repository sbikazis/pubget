import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/economy_types.dart';

/// AdMob ad loading state
enum AdMobLoadState { idle, loading, loaded, failed, showing, disposed }

/// Result of an ad load attempt
final class AdMobLoadResult {
  const AdMobLoadResult({
    required this.success,
    this.ad,
    this.error,
    required this.format,
    required this.placement,
  });

  final bool success;
  final Ad? ad;
  final String? error;
  final AdMobFormat format;
  final AdPlacement placement;

  factory AdMobLoadResult.success(
    Ad ad, {
    required AdMobFormat format,
    required AdPlacement placement,
  }) => AdMobLoadResult(
    success: true,
    ad: ad,
    format: format,
    placement: placement,
  );

  factory AdMobLoadResult.failure(
    String error, {
    required AdMobFormat format,
    required AdPlacement placement,
  }) => AdMobLoadResult(
    success: false,
    error: error,
    format: format,
    placement: placement,
  );
}

/// AdMob service for managing all AdMob ad formats
final class AdMobService {
  // Production ad unit IDs (real IDs from AdMob console)
  static const Map<AdMobFormat, String> _prodAdUnitIds = {
    AdMobFormat.banner: 'ca-app-pub-3303379299409244/7985028657',
    AdMobFormat.interstitial: 'ca-app-pub-3303379299409244/6028204296',
    AdMobFormat.native: 'ca-app-pub-3303379299409244/4067246201',
    AdMobFormat.rewarded: 'ca-app-pub-3303379299409244/9020189981',
  };

  // Test ad unit IDs (Google's test IDs)
  static const Map<AdMobFormat, String> _testAdUnitIds = {
    AdMobFormat.banner: 'ca-app-pub-3940256099942544/6300978111',
    AdMobFormat.interstitial: 'ca-app-pub-3940256099942544/1033173712',
    AdMobFormat.native: 'ca-app-pub-3940256099942544/2747169741',
    AdMobFormat.rewarded: 'ca-app-pub-3940256099942544/5224354917',
  };

  final bool testMode;
  final Map<AdMobFormat, String> adUnitIds;

  AdMobService({this.testMode = true, Map<AdMobFormat, String>? adUnitIds})
    : adUnitIds = adUnitIds ?? (kDebugMode ? _testAdUnitIds : _prodAdUnitIds) {
    if (kDebugMode) {
      MobileAds.instance.initialize();
    }
  }

  // Banner ads per placement
  final Map<AdPlacement, BannerAd?> _bannerAds = <AdPlacement, BannerAd?>{};
  final Map<AdPlacement, AdMobLoadState> _bannerStates =
      <AdPlacement, AdMobLoadState>{};
  final Map<AdPlacement, StreamController<AdMobLoadState>> bannerControllers =
      <AdPlacement, StreamController<AdMobLoadState>>{};

  // Interstitial ads
  InterstitialAd? _interstitialAd;
  AdMobLoadState _interstitialState = AdMobLoadState.idle;
  final StreamController<AdMobLoadState> _interstitialController =
      StreamController<AdMobLoadState>.broadcast();
  Completer<void>? _interstitialShowCompleter;

  // Native ads
  final Map<AdPlacement, NativeAd?> _nativeAds = <AdPlacement, NativeAd?>{};
  final Map<AdPlacement, AdMobLoadState> _nativeStates =
      <AdPlacement, AdMobLoadState>{};
  final Map<AdPlacement, StreamController<AdMobLoadState>> _nativeControllers =
      <AdPlacement, StreamController<AdMobLoadState>>{};

  // Rewarded ads
  RewardedAd? _rewardedAd;
  AdMobLoadState _rewardedState = AdMobLoadState.idle;
  final StreamController<AdMobLoadState> _rewardedController =
      StreamController<AdMobLoadState>.broadcast();
  Completer<RewardedAdResult>? _rewardedShowCompleter;

  // Retry tracking
  final Map<AdMobFormat, int> _retryCounts = <AdMobFormat, int>{};
  static const int _maxRetries = 3;

  // Callbacks
  final Map<AdPlacement, void Function()> _onBannerImpression =
      <AdPlacement, void Function()>{};
  final Map<AdPlacement, void Function()> _onBannerClick =
      <AdPlacement, void Function()>{};
  void Function()? _onInterstitialImpression;
  void Function()? _onInterstitialDismissed;
  void Function()? _onRewardedImpression;
  void Function(int rewardAmount, String rewardType)? _onRewardedEarned;

  /// Get banner ad stream for a placement
  Stream<AdMobLoadState> bannerStateStream(AdPlacement placement) {
    bannerControllers.putIfAbsent(
      placement,
      () => StreamController<AdMobLoadState>.broadcast(),
    );
    return bannerControllers[placement]!.stream;
  }

  /// Get interstitial state stream
  Stream<AdMobLoadState> get interstitialStateStream =>
      _interstitialController.stream;

  /// Get rewarded state stream
  Stream<AdMobLoadState> get rewardedStateStream => _rewardedController.stream;

  /// Initialize the AdMob SDK
  Future<void> initialize() async {
    if (kDebugMode && testMode) {
      await MobileAds.instance.initialize();
    }
  }

  /// Set test mode (use test ad unit IDs)
  void setTestMode(bool enabled) {
    // testMode is final, would need recreation
  }

  /// Set production ad unit IDs (call after remote config fetch)
  void setAdUnitIds(Map<AdMobFormat, String> ids) {
    // adUnitIds is final, would need recreation
  }

  // ========== BANNER ADS ==========

  /// Load a banner ad for a specific placement
  Future<AdMobLoadResult> loadBanner({
    required AdPlacement placement,
    AdSize size = AdSize.banner,
    Duration? retryDelay,
  }) async {
    _bannerStates[placement] = AdMobLoadState.loading;
    _notifyBanner(placement);

    final adUnitId = _getAdUnitId(AdMobFormat.banner, placement);
    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAds[placement] = ad as BannerAd;
          _bannerStates[placement] = AdMobLoadState.loaded;
          _retryCounts[AdMobFormat.banner] = 0;
          _notifyBanner(placement);
          _onBannerImpression[placement]?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerStates[placement] = AdMobLoadState.failed;
          _notifyBanner(placement);
          _handleLoadFailure(
            AdMobFormat.banner,
            error,
            placement,
            () => loadBanner(placement: placement),
          );
        },
        onAdOpened: (ad) => _onBannerClick[placement]?.call(),
        onAdClosed: (ad) {},
        onAdImpression: (ad) => _onBannerImpression[placement]?.call(),
      ),
    );

    await bannerAd.load();
    return AdMobLoadResult(
      success: false,
      format: AdMobFormat.banner,
      placement: placement,
    );
  }

  /// Show a banner ad for a placement (returns the widget if loaded)
  Widget? buildBannerWidget(AdPlacement placement) {
    final ad = _bannerAds[placement];
    if (ad == null || _bannerStates[placement] != AdMobLoadState.loaded) {
      return null;
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  /// Dispose a banner ad for a placement
  void disposeBanner(AdPlacement placement) {
    _bannerAds[placement]?.dispose();
    _bannerAds[placement] = null;
    _bannerStates[placement] = AdMobLoadState.disposed;
    _notifyBanner(placement);
  }

  /// Dispose all banner ads
  void disposeAllBanners() {
    for (final placement in _bannerAds.keys.toList()) {
      disposeBanner(placement);
    }
  }

  // ========== INTERSTITIAL ADS ==========

  /// Load an interstitial ad
  Future<void> loadInterstitial({AdPlacement? placement}) async {
    _interstitialState = AdMobLoadState.loading;
    _interstitialController.add(_interstitialState);

    final adUnitId = _getAdUnitId(AdMobFormat.interstitial, null);
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialState = AdMobLoadState.loaded;
          _retryCounts[AdMobFormat.interstitial] = 0;
          _interstitialController.add(_interstitialState);
          _setupInterstitialListeners();
        },
        onAdFailedToLoad: (error) {
          _interstitialState = AdMobLoadState.failed;
          _interstitialController.add(_interstitialState);
          _handleLoadFailure(
            AdMobFormat.interstitial,
            error,
            null,
            () => loadInterstitial(placement: placement),
          );
        },
      ),
    );
  }

  void _setupInterstitialListeners() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _interstitialState = AdMobLoadState.showing;
        _interstitialController.add(_interstitialState);
        _onInterstitialImpression?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialState = AdMobLoadState.idle;
        _interstitialController.add(_interstitialState);
        _onInterstitialDismissed?.call();
        _interstitialShowCompleter?.complete();
        _interstitialShowCompleter = null;
        // Auto-load next interstitial
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialState = AdMobLoadState.failed;
        _interstitialController.add(_interstitialState);
        _interstitialShowCompleter?.completeError(error);
        _interstitialShowCompleter = null;
        _handleLoadFailure(
          AdMobFormat.interstitial,
          error,
          null,
          () => loadInterstitial(),
        );
      },
    );
  }

  /// Show an interstitial ad
  Future<bool> showInterstitial({AdPlacement? placement}) async {
    if (_interstitialAd == null ||
        _interstitialState != AdMobLoadState.loaded) {
      await loadInterstitial(placement: placement);
      // Wait a bit for load
      await Future.delayed(const Duration(milliseconds: 500));
      if (_interstitialAd == null) return false;
    }

    _interstitialShowCompleter = Completer<void>();

    try {
      await _interstitialAd!.show();
      await _interstitialShowCompleter!.future;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose interstitial ad
  void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialState = AdMobLoadState.disposed;
    _interstitialController.add(_interstitialState);
  }

  // ========== REWARDED ADS ==========

  /// Load a rewarded ad
  Future<void> loadRewarded() async {
    _rewardedState = AdMobLoadState.loading;
    _rewardedController.add(_rewardedState);

    final adUnitId = _getAdUnitId(AdMobFormat.rewarded, null);
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedState = AdMobLoadState.loaded;
          _retryCounts[AdMobFormat.rewarded] = 0;
          _rewardedController.add(_rewardedState);
          _setupRewardedListeners();
        },
        onAdFailedToLoad: (error) {
          _rewardedState = AdMobLoadState.failed;
          _rewardedController.add(_rewardedState);
          _handleLoadFailure(AdMobFormat.rewarded, error, null, loadRewarded);
        },
      ),
    );
  }

  void _setupRewardedListeners() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _rewardedState = AdMobLoadState.showing;
        _rewardedController.add(_rewardedState);
        _onRewardedImpression?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedState = AdMobLoadState.idle;
        _rewardedController.add(_rewardedState);
        _rewardedShowCompleter?.complete(
          RewardedAdResult(completed: false, rewardAmount: 0, rewardType: ''),
        );
        _rewardedShowCompleter = null;
        // Auto-load next rewarded
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedState = AdMobLoadState.failed;
        _rewardedController.add(_rewardedState);
        _rewardedShowCompleter?.completeError(error);
        _rewardedShowCompleter = null;
        _handleLoadFailure(AdMobFormat.rewarded, error, null, loadRewarded);
      },
    );
  }

  /// Show a rewarded ad
  Future<RewardedAdResult> showRewarded() async {
    if (_rewardedAd == null || _rewardedState != AdMobLoadState.loaded) {
      await loadRewarded();
      await Future.delayed(const Duration(milliseconds: 500));
      if (_rewardedAd == null) {
        return RewardedAdResult(
          completed: false,
          rewardAmount: 0,
          rewardType: '',
        );
      }
    }

    _rewardedShowCompleter = Completer<RewardedAdResult>();

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          _onRewardedEarned?.call(reward.amount.toInt(), reward.type);
        },
      );
      return await _rewardedShowCompleter!.future;
    } catch (e) {
      return RewardedAdResult(
        completed: false,
        rewardAmount: 0,
        rewardType: '',
      );
    }
  }

  /// Dispose rewarded ad
  void disposeRewarded() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _rewardedState = AdMobLoadState.disposed;
    _rewardedController.add(_rewardedState);
  }

  // ========== NATIVE ADS ==========

  /// Get native ad stream for a placement
  Stream<AdMobLoadState> nativeStateStream(AdPlacement placement) {
    _nativeControllers.putIfAbsent(
      placement,
      () => StreamController<AdMobLoadState>.broadcast(),
    );
    return _nativeControllers[placement]!.stream;
  }

  /// Load a native ad for a specific placement
  Future<AdMobLoadResult> loadNativeAd({
    required AdPlacement placement,
    AdSize size = AdSize.mediumRectangle,
    Duration? retryDelay,
  }) async {
    _nativeStates[placement] = AdMobLoadState.loading;
    _notifyNative(placement);

    final adUnitId = _getAdUnitId(AdMobFormat.native, placement);
    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile', // Use the built-in listTile template
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _nativeAds[placement] = ad as NativeAd;
          _nativeStates[placement] = AdMobLoadState.loaded;
          _retryCounts[AdMobFormat.native] = 0;
          _notifyNative(placement);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeStates[placement] = AdMobLoadState.failed;
          _notifyNative(placement);
          _handleLoadFailure(
            AdMobFormat.native,
            error,
            placement,
            () => loadNativeAd(placement: placement),
          );
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
        onAdImpression: (ad) {},
      ),
    );

    await nativeAd.load();
    return AdMobLoadResult(
      success: false,
      format: AdMobFormat.native,
      placement: placement,
    );
  }

  /// Show a native ad for a placement (returns the widget if loaded)
  Widget? buildNativeAdWidget(AdPlacement placement) {
    final ad = _nativeAds[placement];
    if (ad == null || _nativeStates[placement] != AdMobLoadState.loaded) {
      return null;
    }
    return AdWidget(ad: ad);
  }

  /// Dispose a native ad for a placement
  void disposeNativeAd(AdPlacement placement) {
    _nativeAds[placement]?.dispose();
    _nativeAds[placement] = null;
    _nativeStates[placement] = AdMobLoadState.disposed;
    _notifyNative(placement);
  }

  /// Dispose all native ads
  void disposeAllNativeAds() {
    for (final placement in _nativeAds.keys.toList()) {
      disposeNativeAd(placement);
    }
  }

  void _notifyNative(AdPlacement placement) {
    _nativeControllers[placement]?.add(_nativeStates[placement]!);
  }

  // ========== HELPERS ==========

  String _getAdUnitId(AdMobFormat format, AdPlacement? placement) {
    if (kDebugMode && testMode) {
      return adUnitIds[format]!;
    }
    // In production, would fetch from remote config
    return adUnitIds[format]!;
  }

  void _notifyBanner(AdPlacement placement) {
    bannerControllers[placement]?.add(_bannerStates[placement]!);
  }

  void _handleLoadFailure(
    AdMobFormat format,
    AdError error,
    AdPlacement? placement,
    Future<void> Function() retry,
  ) {
    final count = (_retryCounts[format] ?? 0) + 1;
    _retryCounts[format] = count;

    debugPrint(
      'AdMob $format load failed (attempt $count/$_maxRetries): ${error.message}',
    );

    if (count < _maxRetries) {
      final delay = Duration(seconds: 2 * count); // Exponential backoff
      Future.delayed(delay, retry);
    } else {
      debugPrint('AdMob $format max retries reached, giving up');
      _retryCounts[format] = 0;
    }
  }

  // ========== CALLBACKS ==========

  void setOnBannerImpression(AdPlacement placement, void Function() callback) {
    _onBannerImpression[placement] = callback;
  }

  void setOnBannerClick(AdPlacement placement, void Function() callback) {
    _onBannerClick[placement] = callback;
  }

  void setOnInterstitialImpression(void Function() callback) {
    _onInterstitialImpression = callback;
  }

  void setOnInterstitialDismissed(void Function() callback) {
    _onInterstitialDismissed = callback;
  }

  void setOnRewardedImpression(void Function() callback) {
    _onRewardedImpression = callback;
  }

  void setOnRewardedEarned(void Function(int amount, String type) callback) {
    _onRewardedEarned = callback;
  }

  // ========== CLEANUP ==========

  void dispose() {
    disposeAllBanners();
    disposeAllNativeAds();
    disposeInterstitial();
    disposeRewarded();

    for (final controller in bannerControllers.values) {
      controller.close();
    }
    for (final controller in _nativeControllers.values) {
      controller.close();
    }
    _nativeControllers.clear();
    bannerControllers.clear();
    _interstitialController.close();
    _rewardedController.close();
  }
}

/// Result of a rewarded ad show
final class RewardedAdResult {
  const RewardedAdResult({
    required this.completed,
    required this.rewardAmount,
    required this.rewardType,
  });

  final bool completed;
  final int rewardAmount;
  final String rewardType;
}
