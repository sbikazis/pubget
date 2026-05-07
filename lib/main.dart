import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pubget/services/monetization/ad_service.dart';
import 'package:pubget/core/utils/notification_service.dart';
import 'package:pubget/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // استخدام تهيئة سريعة ومختصرة للخلفية
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
      appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
      messagingSenderId: '193460577475',
      projectId: 'pubget-817cf',
    ),
  );
}

Future<void> main() async {
  // ضمان الربط أولاً
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Initialization (أساسي للتشغيل)
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
        appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
        messagingSenderId: '193460577475',
        projectId: 'pubget-817cf',
      ),
    );
    
    // تسجيل معالج الخلفية فوراً بعد التهيئة
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("🔥 Firebase init error: $e");
  }

  // 2. تهيئة الخدمات الأخرى (بشكل متوازي لا يمنع runApp)
  // لا نستخدم await هنا للخدمات التي قد تأخذ وقتاً طويلاً وتجمد السبلاش
  Future.wait([
    MobileAds.instance.initialize(),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    NotificationService.instance.initialize(), // تهيئة في الخلفية
  ]);

  // 3. Run App فوراً
  runApp(const PubgetApp());
}