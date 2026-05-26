import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pubget/core/utils/notification_service.dart';
import 'package:pubget/app.dart';
import 'package:pubget/services/deep_link_service.dart';
import 'package:pubget/services/local/local_storage_service.dart';
import 'package:pubget/services/monetization/subscription_service.dart'; // ✅ أضف
import 'package:pubget/services/firebase/firestore_service.dart'; // ✅ أضف

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
}

// ✅ متغير عام للوصول للتجديد
late final SubscriptionService globalSubscriptionService;

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
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // ✅ تهيئة خدمة الاشتراك
    globalSubscriptionService = SubscriptionService(FirestoreService());
    
  } catch (e) {
    debugPrint("🔥 Firebase init error: $e");
  }

  try {
    await LocalStorageService.instance.init();
    final deepLinkService = DeepLinkService();
    final referrerId = await deepLinkService.getDeferredReferrerId();
    if (referrerId != null && referrerId.isNotEmpty) {
      await LocalStorageService.instance.saveString('pending_inviter', referrerId);
    }
  } catch (e) {
    debugPrint("⚠️ خطأ في التقاط الدعوة: $e");
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PubgetApp());

  NotificationService.instance.initialize().catchError((e) {});
  MobileAds.instance.initialize();
}