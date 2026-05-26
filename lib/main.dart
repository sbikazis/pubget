import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pubget/core/utils/notification_service.dart';
import 'package:pubget/app.dart';
import 'package:pubget/services/deep_link_service.dart'; // <-- جديد
import 'package:pubget/services/local/local_storage_service.dart'; // <-- جديد

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
  } catch (e) {
    debugPrint("🔥 Firebase init error: $e");
  }

  // ✅ التقاط الدعوة قبل تشغيل التطبيق
  try {
    await LocalStorageService.instance.init();
    final deepLinkService = DeepLinkService();
    final referrerId = await deepLinkService.getDeferredReferrerId();
    if (referrerId != null && referrerId.isNotEmpty) {
      await LocalStorageService.instance.saveString('pending_inviter', referrerId);
      debugPrint("✅ تم حفظ الداعي: $referrerId");
    }
  } catch (e) {
    debugPrint("⚠️ خطأ في التقاط الدعوة: $e");
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // ✅ شغّل الواجهة أولاً
  runApp(const PubgetApp());

  // ✅ بعدها هيئ الإشعارات والإعلانات في الخلفية
  NotificationService.instance.initialize().catchError((e) {
    debugPrint("⚠️ Notification init error: $e");
  });
  
  MobileAds.instance.initialize();
}
