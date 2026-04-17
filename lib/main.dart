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

  // 2. Google Mobile Ads Initialization (تعديل لضمان الجاهزية)
  try {
    final RequestConfiguration configuration = RequestConfiguration(
      testDeviceIds: [], // يمكنك إضافة ID جهازك هنا لاحقاً إذا احتجت
    );
    await MobileAds.instance.updateRequestConfiguration(configuration);
    
    // الانتظار الفعلي حتى تكتمل التهيئة قبل المتابعة
    await MobileAds.instance.initialize();
    debugPrint("✅ Ads initialized successfully");
  } catch (e) {
    debugPrint("🔥 Ads init error: $e");
  }

  // 3. Orientation Settings
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 4. Run App
  runApp(const PubgetApp());
}