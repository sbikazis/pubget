import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pubget/services/monetization/ad_service.dart';
import 'package:pubget/core/utils/notification_service.dart';
import 'package:pubget/app.dart';

// ✅ معالجة الإشعارات في الخلفية — يجب أن تكون هنا في main.dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
      appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
      messagingSenderId: '193460577475',
      projectId: 'pubget-817cf',
    ),
  );
  await NotificationService.instance.handleBackgroundMessage(message);
}

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

  // 2. تسجيل معالج الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. تهيئة نظام الإشعارات
  await NotificationService.instance.initialize();

  // 4. AdMob Initialization
  await MobileAds.instance.initialize();

  // 5. Orientation Settings
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 6. Run App
  runApp(const PubgetApp());
}