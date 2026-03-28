// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';

// Google Mobile Ads
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:pubget/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("🔥 Ads init error: $e");
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const PubgetApp());
}