// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
// ✅ استيراد Provider و AdService لتهيئة العدادات
import 'package:provider/provider.dart';
import 'package:pubget/services/monetization/ad_service.dart';

import 'package:pubget/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Initialization
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
        appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
        messagingSenderId: '193460577475',
        projectId: 'pubget-817cf',
      ),
    );
  } catch (e) {
    debugPrint("🔥 Firebase init error: $e");
  }

  // 2. AdMob Initialization
  await MobileAds.instance.initialize();

  // 3. Orientation Settings
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 4. Run App
  runApp(const PubgetApp());
}