import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// ✅ معالجة الإشعارات في الخلفية — يجب أن تكون Top-Level Function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance._showLocalNotification(message);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ قائمة الـ 21 صوت الموجودة في android/app/src/main/res/raw/
  // تأكد أن الأسماء تطابق أسماء الملفات بالضبط بدون امتداد
  static const List<String> _sounds = [
    'an1', 'an2', 'an3', 'an4', 'an5',
    'an6', 'an7', 'an8', 'an9', 'sound_10',
    'an11', 'an12', 'an13', 'an14', 'an15',
    'an16', 'an17', 'an18', 'an19', 'an20',
    'an21',
  ];

  // ✅ اختيار صوت عشوائي
  String _randomSound() {
    final index = Random().nextInt(_sounds.length);
    return _sounds[index];
  }

  // =========================================================
  // التهيئة الكاملة — تُستدعى من main.dart
  // =========================================================
  Future<void> initialize() async {
    // 1. طلب إذن الإشعارات
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. تهيئة flutter_local_notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // 3. استقبال الإشعارات وهو التطبيق مفتوح (Foreground)
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // 4. عند الضغط على الإشعار وهو في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message);
    });

    // 5. التحقق من إشعار فتح التطبيق من Terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // =========================================================
  // عرض الإشعار المحلي بصوت عشوائي
  // =========================================================
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final sound = _randomSound();

    final androidDetails = AndroidNotificationDetails(
      'pubget_channel_$sound', // channel id فريد لكل صوت
      'Pubget Notifications',
      channelDescription: 'إشعارات تطبيق Pubget',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(sound),
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // id فريد
      message.notification?.title ?? 'Pubget',
      message.notification?.body ?? '',
      details,
    );
  }

  // =========================================================
  // معالجة الضغط على الإشعار
  // =========================================================
  void _handleNotificationTap(RemoteMessage message) {
    // يمكن لاحقاً إضافة Navigation هنا بناءً على message.data
    debugPrint('🔔 Notification tapped: ${message.data}');
  }

  // =========================================================
  // جلب FCM Token للمستخدم الحالي
  // =========================================================
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // =========================================================
  // مراقبة تجديد الـ Token
  // =========================================================
  void listenToTokenRefresh(Function(String token) onRefresh) {
    _fcm.onTokenRefresh.listen(onRefresh);
  }
}