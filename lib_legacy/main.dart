// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pubget/core/utils/notification_service.dart';
import 'package:pubget/core/constants/notification_channels.dart';
import 'package:pubget/app.dart';
import 'package:pubget/services/deep_link_service.dart';
import 'package:pubget/services/local/local_storage_service.dart';
import 'package:pubget/services/monetization/subscription_service.dart';
import 'package:pubget/services/firebase/firestore_service.dart';
import 'dart:math';

// ══════════════════════════════════════════════════════════════
// ✅ Background handler — يعمل في isolate منفصل
// يجب أن يكون top-level function وأن يكون خفيفاً
// ══════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 1. تهيئة Firebase في الـ isolate المنفصل
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
      appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
      messagingSenderId: '193460577475',
      projectId: 'pubget-817cf',
    ),
  );

  // 2. عرض إشعار محلي في الـ background
  // لا يمكن استخدام NotificationService.instance هنا لأنه isolate منفصل
  // لذا نعرض الإشعار مباشرة
  await _showBackgroundNotification(message);
}

// ══════════════════════════════════════════════════════════════
// ✅ عرض إشعار محلي في الـ background بدون singleton
// ══════════════════════════════════════════════════════════════
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await plugin.initialize(settings: initSettings);

    // اختيار صوت عشوائي
    final sounds = [
      'an1',  'an2',  'an3',  'an4',  'an5',
      'an6',  'an7',  'an8',  'an9',  'an10',
      'an11', 'an12', 'an13', 'an14', 'an15',
      'an16', 'an17', 'an18', 'an19', 'an20',
      'an21',
    ];
    final sound = sounds[Random().nextInt(sounds.length)];

    final data       = message.data;
    final type       = data[NotificationPayloadKeys.type] ?? '';
    final refId      = data[NotificationPayloadKeys.refId] ?? '';
    final senderId   = data[NotificationPayloadKeys.senderId] ?? '';
    final commentId  = data[NotificationPayloadKeys.commentId] ?? '';
    final payload    = '$type${NotificationPayloadKeys.separator}'
        '$refId${NotificationPayloadKeys.separator}'
        '$senderId${NotificationPayloadKeys.separator}'
        '$commentId';

    final bool isGroupChat   = type == AppNotificationTypes.groupChat;
    final bool isPrivateChat = type == AppNotificationTypes.privateChat;

    AndroidNotificationDetails androidDetails;

    if (isGroupChat || isPrivateChat) {
      // ── إشعار مع زر Reply ──────────────────────────────
      final channelId = isGroupChat
          ? NotificationChannels.groupChat
          : NotificationChannels.privateChat;
      final channelName = isGroupChat
          ? NotificationChannels.groupChatName
          : NotificationChannels.privateChatName;
      final actionId = isGroupChat
          ? NotificationActions.replyGroup
          : NotificationActions.replyPrivate;

      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        actions: [
          AndroidNotificationAction(
            actionId,
            NotificationActions.replyLabel,
            inputs: [
              AndroidNotificationActionInput(
                label: NotificationActions.replyHint,
                allowFreeFormInput: true,
                choices: [],
              ),
            ],
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );
    } else {
      // ── إشعار عادي ─────────────────────────────────────
      androidDetails = AndroidNotificationDetails(
        '${NotificationChannels.generalPrefix}$sound',
        NotificationChannels.generalName,
        channelDescription: NotificationChannels.generalDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      );
    }

    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: message.notification?.title ?? 'Pubget',
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  } catch (e) {
    debugPrint('⚠️ Background notification error: $e');
  }
}

// ══════════════════════════════════════════════════════════════
// Global service
// ══════════════════════════════════════════════════════════════
late final SubscriptionService globalSubscriptionService;

// ══════════════════════════════════════════════════════════════
// main
// ══════════════════════════════════════════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase ─────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDPgjnaviwqxz8lGK_o9pjg4zuoB7RrVBw',
        appId: '1:193460577475:android:2ddc9727c0ca84dbb86e76',
        messagingSenderId: '193460577475',
        projectId: 'pubget-817cf',
      ),
    );

    // ✅ تسجيل background handler قبل أي شيء آخر
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    globalSubscriptionService = SubscriptionService(FirestoreService());
  } catch (e) {
    debugPrint('🔥 Firebase init error: $e');
  }

  // ── 2. Local storage + deep link ────────────────────────────
  try {
    await LocalStorageService.instance.init();
    final deepLinkService = DeepLinkService();
    final referrerId = await deepLinkService.getDeferredReferrerId();
    if (referrerId != null && referrerId.isNotEmpty) {
      await LocalStorageService.instance
          .saveString('pending_inviter', referrerId);
    }
  } catch (e) {
    debugPrint('⚠️ خطأ في التقاط الدعوة: $e');
  }

  // ── 3. AdMob ─────────────────────────────────────────────────
  try {
    await MobileAds.instance.initialize();
    debugPrint('✅ MobileAds initialized');
  } catch (e) {
    debugPrint('⚠️ MobileAds init error: $e');
  }

  // ── 4. اتجاه الشاشة ─────────────────────────────────────────
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  // ── 5. ✅ تهيئة NotificationService قبل runApp ───────────────
  // السبب: getInitialMessage يجب أن يُستدعى قبل بناء الـ widget tree
  // حتى لا يُفوَّت الإشعار الذي فتح التطبيق من حالة terminated
  try {
    await NotificationService.instance.initialize();
    debugPrint('✅ NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ NotificationService init error: $e');
  }

  // ── 6. تشغيل التطبيق ─────────────────────────────────────────
  runApp(const PubgetApp());
}
