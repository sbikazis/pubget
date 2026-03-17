import '../../core/logic/ad_display_logic.dart';
import '../local/local_storage_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdService
class AdService {
  final LocalStorageService _localStorage;

  AdService(this._localStorage);

  // ===============================
  // AdMob Unit IDs (استبدلها لاحقاً بالـ IDs الحقيقية)
  // ===============================
  final String appOpenAdUnitId = 'ca-app-pub-3940256099942544/3419835294'; // Test ID
  final String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID

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

    // قرار الصباح
    var decision = AdDisplayLogic.checkMorningAd(lastAdTime);

    // منع للمشتركين
    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    if (!decision.shouldShow) return false;

    // عرض الإعلان
    await _showAppOpenAd();

    // حفظ وقت العرض
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

    // قرار الخمس دقائق
    var decision = AdDisplayLogic.checkFiveMinutesRule(lastAdTime);

    // منع للمشتركين
    decision = AdDisplayLogic.checkIfPremium(
      isPremium: isPremium,
      decision: decision,
    );

    if (!decision.shouldShow) return false;

    // عرض الإعلان
    await _showInterstitialAd();

    // حفظ وقت العرض
    await _localStorage.saveLastAdTime(DateTime.now());

    return true;
  }

  // ===============================
  // PRIVATE METHODS
  // ===============================

  // App Open Ad
  Future<void> _showAppOpenAd() async {
    if (_appOpenAd == null) {
      await _loadAppOpenAd();
    }

    if (_appOpenAd != null) {
      _appOpenAd!.show();
      _appOpenAd = null; // تفريغ الإعلان بعد العرض
      await _loadAppOpenAd(); // إعادة التحميل للمرات القادمة
    }
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

  // Interstitial Ad
  Future<void> _showInterstitialAd() async {
    if (_interstitialAd == null) {
      await _loadInterstitialAd();
    }

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null; // تفريغ الإعلان بعد العرض
      await _loadInterstitialAd(); // إعادة التحميل
    }
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