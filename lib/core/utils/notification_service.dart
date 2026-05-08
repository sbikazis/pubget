import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const List<String> _sounds = [
    'an1', 'an2', 'an3', 'an4', 'an5',
    'an6', 'an7', 'an8', 'an9', 'an10',
    'an11', 'an12', 'an13', 'an14', 'an15',
    'an16', 'an17', 'an18', 'an19', 'an20',
    'an21',
  ];

  String _randomSound() {
    final index = Random().nextInt(_sounds.length);
    return _sounds[index];
  }

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ✅ السطرين اللي كانوا ناقصين
    await _fcm.setAutoInitEnabled(true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
    );

    // ✅ إنشاء القناة مرة واحدة
    const channel = AndroidNotificationChannel(
      'pubget_main_channel',
      'Pubget Notifications',
      description: 'إشعارات تطبيق Pubget',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
       .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
       ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage!= null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final sound = _randomSound();

    final androidDetails = AndroidNotificationDetails(
      'pubget_main_channel',
      'Pubget Notifications',
      channelDescription: 'إشعارات تطبيق Pubget',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(sound),
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: message.notification?.title?? 'Pubget',
      body: message.notification?.body?? '',
      notificationDetails: details,
    );
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
  }

  Future<String?> getToken() async {
    final token = await _fcm.getToken();
    debugPrint('🎯 FCM Token: $token');
    return token;
  }

  void listenToTokenRefresh(Function(String token) onRefresh) {
    _fcm.onTokenRefresh.listen(onRefresh);
  }
}