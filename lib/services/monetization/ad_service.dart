import '../../core/logic/ad_display_logic.dart';
import '../local/local_storage_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdService
class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ===============================
  // AdMob Unit IDs (Test IDs)
  // ===============================
  final String appOpenAdUnitId =
      'ca-app-pub-3940256099942544/3419835294';

  final String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // ===============================
  // Google Ads Instances
  // ===============================
  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;

  bool _isAppOpenAdLoading = false;
  bool _isInterstitialAdLoading = false;

  // ===============================
  // Morning App Open Ad
  // ===============================
  Future<bool> tryShowMorningAd({
    required bool isPremium,
  }) async {
    await _localStorage.init();
    final lastAdTime = _localStorage.getLastAdTime();

    var decision = AdDisplayLogic.checkMorningAd(lastAdTime);

    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    if (!decision.shouldShow) return false;

    await _showAppOpenAd();

    await _localStorage.saveLastAdTime(DateTime.now());

    return true;
  }

  // ===============================
  // Group Enter/Exit Ad
  // ===============================
  Future<bool> tryShowGroupAd({
    required bool isPremium,
  }) async {
    await _localStorage.init();
    final lastAdTime = _localStorage.getLastAdTime();

    var decision = AdDisplayLogic.checkFiveMinutesRule(lastAdTime);

    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    if (!decision.shouldShow) return false;

    await _showInterstitialAd();

    await _localStorage.saveLastAdTime(DateTime.now());

    return true;
  }

  // ===============================
  // PRIVATE METHODS
  // ===============================

  // -------------------------------
  // App Open Ad
  // -------------------------------
  Future<void> _showAppOpenAd() async {
    if (_appOpenAd == null) {
      await _loadAppOpenAd();
      return; // ❗ لا تعرض مباشرة بعد التحميل
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd(); // إعادة التحميل
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
    _appOpenAd = null;
  }

  Future<void> _loadAppOpenAd() async {
    if (_isAppOpenAdLoading) return;

    _isAppOpenAdLoading = true;

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  // -------------------------------
  // Interstitial Ad
  // -------------------------------
  Future<void> _showInterstitialAd() async {
    if (_interstitialAd == null) {
      await _loadInterstitialAd();
      return; // ❗ لا تعرض مباشرة
    }

    _interstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd(); // إعادة التحميل
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  Future<void> _loadInterstitialAd() async {
    if (_isInterstitialAdLoading) return;

    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }
}