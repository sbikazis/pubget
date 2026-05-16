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

  @override
  void initState() {
    super.initState();
    _loadAd();
    _startCountdown();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3303379299409244/9117104001', // ← ID الخاص بك
      listener: NativeAdListener(
        onAdLoaded: (_) => setState(() => _adLoaded = true),
        onAdFailedToLoad: (_, __) => widget.onAdFinished(),
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    )..load();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        widget.onAdFinished();
        return false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── خلفية سوداء مع الإعلان
        Container(
          color: Colors.black,
          child: _adLoaded
              ? AdWidget(ad: _nativeAd!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),

        // ── شارة "إعلان"
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

        // ── عداد تنازلي (لا يمكن تخطيه)
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

        // ── طبقة شفافة تمنع أي تفاعل أثناء الإعلان
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: _secondsLeft > 0,
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}