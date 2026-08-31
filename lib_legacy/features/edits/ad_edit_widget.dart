// lib/features/edits/ad_edit_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdEditWidget extends StatefulWidget {
  final VoidCallback onAdFinished;

  const AdEditWidget({super.key, required this.onAdFinished});

  @override
  State<AdEditWidget> createState() => _AdEditWidgetState();
}

class _AdEditWidgetState extends State<AdEditWidget> {
  NativeAd? _nativeAd;
  bool _adLoaded = false;
  int _secondsLeft = 5;
  int _retryCount = 0;
  Timer? _countdownTimer;

  // ✅ زيادة عدد المحاولات من 1 إلى 3 — مع Liftoff كمصدر إضافي الآن،
  // كل محاولة قد تصل لمصدر مختلف (AdMob أو Liftoff)، فيستحق وقتاً أطول
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadAd(); // فقط تحميل، لا نبدأ العداد هنا
  }

  void _loadAd() {
    _nativeAd?.dispose();

    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3303379299409244/3972031025', // ← تم التصحيح
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _adLoaded = true);
          _startCountdown(); // ← العداد يبدأ هنا فقط
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;

          if (_retryCount < _maxRetries) {
            // ✅ حتى 3 محاولات بدل محاولة واحدة فقط
            _retryCount++;
            // ✅ تأخير متصاعد بسيط بين المحاولات (1s, 2s, 3s) بدل ثابت
            Future.delayed(Duration(seconds: _retryCount), _loadAd);
          } else {
            // ✅ فشل نهائي → انتظر 8 ثوانٍ بدل 3 قبل الإنهاء
            // (وقت إضافي يعطي فرصة أكبر لمصدر Liftoff البديل)
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted) widget.onAdFinished();
            });
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    )..load();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 5);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        timer.cancel();
        widget.onAdFinished();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // خلفية سوداء مع الإعلان
        Container(
          color: Colors.black,
          child: _adLoaded
              ? AdWidget(ad: _nativeAd!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),

        // شارة "إعلان"
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'إعلان',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // عداد تنازلي
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_secondsLeft ث',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // منع التفاعل أثناء العد
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: _secondsLeft > 0 || !_adLoaded,
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
