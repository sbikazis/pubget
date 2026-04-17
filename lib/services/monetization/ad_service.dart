// lib/services/monetization/ad_service.dart
import 'dart:async'; // تم استدعاء هذا للتحكم في انتظار التحميل
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

    // الآن يمكن عرض الإعلان بأمان
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

  Future<void> _showAppOpenAd() async {
    // التعديل: إذا لم يكن محملاً، انتظر تحميله ثم اعرضه فوراً
    if (_appOpenAd == null) {
      await _loadAppOpenAd();
    }

    if (_appOpenAd == null) return; // فشل التحميل حتى بعد الانتظار

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd(); // تحميل الإعلان القادم في الخلفية
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
    final completer = Completer<void>(); // لإيقاف الدالة حتى يكتمل التحميل

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoading = false;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
          completer.complete();
        },
      ),
    );

    return completer.future;
  }

  Future<void> _showInterstitialAd() async {
    // التعديل: إذا لم يكن محملاً، انتظر تحميله ثم اعرضه فوراً
    if (_interstitialAd == null) {
      await _loadInterstitialAd();
    }

    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
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
    final completer = Completer<void>();

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          completer.complete();
        },
      ),
    );

    return completer.future;
  }
}