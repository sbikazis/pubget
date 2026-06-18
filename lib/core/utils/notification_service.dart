// lib/core/utils/notification_service.dart

import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// نوع الإشعار — يُستخدم للتنقل والـ Reply
// ══════════════════════════════════════════════════════════════
enum NotificationNavType {
  groupChat,
  privateChat,
  joinRequest,
  requestAccepted,
  comment,
  other,
}

// ══════════════════════════════════════════════════════════════
// بيانات التنقل المستخرجة من payload الإشعار
// ══════════════════════════════════════════════════════════════
class NotificationNavData {
  final NotificationNavType type;
  final String? refId;       // groupId أو chatId أو editId
  final String? senderId;
  final String? commentId;

  const NotificationNavData({
    required this.type,
    this.refId,
    this.senderId,
    this.commentId,
  });
}

// ══════════════════════════════════════════════════════════════
// Callback للتنقل — يُسجَّل من app.dart
// ══════════════════════════════════════════════════════════════
typedef NotificationTapCallback = void Function(NotificationNavData data);

// ══════════════════════════════════════════════════════════════
// Callback للـ Reply المباشر من الإشعار
// ══════════════════════════════════════════════════════════════
typedef NotificationReplyCallback = void Function({
  required NotificationNavType type,
  required String refId,
  required String replyText,
});

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ── Callbacks مسجَّلة من app.dart ────────────────────────
  NotificationTapCallback? _onTap;
  NotificationReplyCallback? _onReply;

  // ── pending navigation إذا جاء الإشعار قبل تسجيل الـ callback ──
  NotificationNavData? _pendingNavData;

  // ══════════════════════════════════════════════════════════
  // أصوات عشوائية
  // ══════════════════════════════════════════════════════════
  static const List<String> _sounds = [
    'an1',  'an2',  'an3',  'an4',  'an5',
    'an6',  'an7',  'an8',  'an9',  'an10',
    'an11', 'an12', 'an13', 'an14', 'an15',
    'an16', 'an17', 'an18', 'an19', 'an20',
    'an21',
  ];

  String _randomSound() => _sounds[Random().nextInt(_sounds.length)];

  // ── معرّفات قنوات Reply ───────────────────────────────────
  static const String _replyGroupChannelId   = 'pubget_reply_group';
  static const String _replyPrivateChannelId = 'pubget_reply_private';
  static const String _replyGroupActionId    = 'REPLY_GROUP';
  static const String _replyPrivateActionId  = 'REPLY_PRIVATE';
  static const String _replyInputKey         = 'reply_text';

  // ══════════════════════════════════════════════════════════
  // تسجيل الـ Callbacks من app.dart
  // ══════════════════════════════════════════════════════════
  void registerCallbacks({
    required NotificationTapCallback onTap,
    required NotificationReplyCallback onReply,
  }) {
    _onTap   = onTap;
    _onReply = onReply;

    // ✅ إذا كان هناك تنقل معلّق قبل تسجيل الـ callback
    if (_pendingNavData != null) {
      _onTap?.call(_pendingNavData!);
      _pendingNavData = null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // تهيئة الخدمة
  // ══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    // 1. طلب الإذن
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _fcm.setAutoInitEnabled(true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false, // ✅ نعرض نحن الإشعار المحلي يدوياً بصوت عشوائي
      badge: true,
      sound: false,
    );

    // 2. إعداد flutter_local_notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationResponse,
    );

    // 3. إنشاء قنوات الأصوات العشوائية
    await _createSoundChannels();

    // 4. إنشاء قنوات الـ Reply
    await _createReplyChannels();

    // 5. الاستماع للرسائل
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 6. التطبيق فُتح من إشعار وهو مغلق كلياً
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // تأخير بسيط حتى يكتمل بناء الـ widget tree
      await Future.delayed(const Duration(milliseconds: 800));
      _handleRemoteMessageTap(initialMessage);
    }
  }

  // ══════════════════════════════════════════════════════════
  // إنشاء قنوات الأصوات
  // ══════════════════════════════════════════════════════════
  Future<void> _createSoundChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    for (final sound in _sounds) {
      final channel = AndroidNotificationChannel(
        'pubget_channel_$sound',
        'Pubget Notifications',
        description: 'إشعارات تطبيق Pubget',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      );
      await plugin.createNotificationChannel(channel);
    }
  }

  // ══════════════════════════════════════════════════════════
  // إنشاء قنوات الـ Reply (دردشة جماعية + خاصة)
  // ══════════════════════════════════════════════════════════
  Future<void> _createReplyChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    final sound = _randomSound();

    // قناة الدردشة الجماعية
    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        _replyGroupChannelId,
        'رسائل المجموعات',
        description: 'رسائل دردشة المجموعات مع إمكانية الرد المباشر',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      ),
    );

    // قناة الدردشة الخاصة
    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        _replyPrivateChannelId,
        'الرسائل الخاصة',
        description: 'الرسائل الخاصة مع إمكانية الرد المباشر',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // الرسائل الواردة والتطبيق مفتوح
  // ══════════════════════════════════════════════════════════
  void _onForegroundMessage(RemoteMessage message) {
    showLocalNotification(message);
  }

  // ══════════════════════════════════════════════════════════
  // المستخدم ضغط على الإشعار والتطبيق في الـ background
  // ══════════════════════════════════════════════════════════
  void _onMessageOpenedApp(RemoteMessage message) {
    _handleRemoteMessageTap(message);
  }

  // ══════════════════════════════════════════════════════════
  // عرض الإشعار المحلي
  // ══════════════════════════════════════════════════════════
  Future<void> showLocalNotification(RemoteMessage message) async {
    final data       = message.data;
    final type       = data['type'] ?? '';
    final refId      = data['refId'] ?? '';
    final title      = message.notification?.title ?? 'Pubget';
    final body       = message.notification?.body ?? '';
    final sound      = _randomSound();
    final notifId    = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final bool isGroupChat   = type == 'group_chat';
    final bool isPrivateChat = type == 'private_chat';

    if (isGroupChat || isPrivateChat) {
      // ── إشعار مع زر Reply ────────────────────────────────
      final String channelId  = isGroupChat
          ? _replyGroupChannelId
          : _replyPrivateChannelId;
      final String actionId   = isGroupChat
          ? _replyGroupActionId
          : _replyPrivateActionId;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        isGroupChat ? 'رسائل المجموعات' : 'الرسائل الخاصة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        // ✅ زر الرد المباشر
        actions: [
          AndroidNotificationAction(
            actionId,
            'رد',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_reply'),
            inputs: [
              AndroidNotificationActionInput(
                label: 'اكتب ردك...',
                allowFreeFormInput: true,
                choices: [],
                allowGeneratedReplies: false,
              ),
            ],
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
        // ✅ payload يحمل بيانات التنقل
        additionalFlags: Int32List.fromList([4]), // FLAG_AUTO_CANCEL
      );

      await _localNotifications.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: _buildPayload(data),
      );
    } else {
      // ── إشعار عادي بدون Reply ────────────────────────────
      final androidDetails = AndroidNotificationDetails(
        'pubget_channel_$sound',
        'Pubget Notifications',
        channelDescription: 'إشعارات تطبيق Pubget',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      );

      await _localNotifications.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: _buildPayload(data),
      );
    }
  }

  // ══════════════════════════════════════════════════════════
  // بناء الـ payload كـ String مضغوط
  // ══════════════════════════════════════════════════════════
  String _buildPayload(Map<String, dynamic> data) {
    final type      = data['type']      ?? '';
    final refId     = data['refId']     ?? '';
    final senderId  = data['senderId']  ?? '';
    final commentId = data['commentId'] ?? '';
    return '$type|$refId|$senderId|$commentId';
  }

  NotificationNavData _parsePayload(String payload) {
    final parts     = payload.split('|');
    final type      = parts.isNotEmpty ? parts[0] : '';
    final refId     = parts.length > 1 ? parts[1] : null;
    final senderId  = parts.length > 2 ? parts[2] : null;
    final commentId = parts.length > 3 ? parts[3] : null;

    return NotificationNavData(
      type:      _navTypeFromString(type),
      refId:     refId?.isEmpty == true ? null : refId,
      senderId:  senderId?.isEmpty == true ? null : senderId,
      commentId: commentId?.isEmpty == true ? null : commentId,
    );
  }

  // ══════════════════════════════════════════════════════════
  // استجابة الإشعار المحلي (ضغط أو Reply)
  // ══════════════════════════════════════════════════════════
  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload  = response.payload ?? '';
    final actionId = response.actionId ?? '';
    final input    = response.input ?? '';

    if (payload.isEmpty) return;

    final navData = _parsePayload(payload);

    // ── ضغط عادي على الإشعار ────────────────────────────────
    if (actionId.isEmpty) {
      _navigate(navData);
      return;
    }

    // ── Reply مباشر ─────────────────────────────────────────
    if ((actionId == _replyGroupActionId ||
            actionId == _replyPrivateActionId) &&
        input.trim().isNotEmpty &&
        navData.refId != null) {
      _onReply?.call(
        type:      navData.type,
        refId:     navData.refId!,
        replyText: input.trim(),
      );
    }
  }

  // ══════════════════════════════════════════════════════════
  // استجابة الإشعار المحلي في الـ background (static)
  // ══════════════════════════════════════════════════════════
  @pragma('vm:entry-point')
  static void _onBackgroundLocalNotificationResponse(
      NotificationResponse response) {
    // في الـ background لا يمكننا الوصول للـ instance
    // الـ Reply سيُعالَج عند فتح التطبيق عبر pendingNavData
    debugPrint(
        '🔔 Background local notification response: ${response.actionId}');
  }

  // ══════════════════════════════════════════════════════════
  // معالجة الضغط على إشعار FCM
  // ══════════════════════════════════════════════════════════
  void _handleRemoteMessageTap(RemoteMessage message) {
    final navData = NotificationNavData(
      type:      _navTypeFromString(message.data['type'] ?? ''),
      refId:     message.data['refId'],
      senderId:  message.data['senderId'],
      commentId: message.data['commentId'],
    );
    _navigate(navData);
  }

  // ══════════════════════════════════════════════════════════
  // التنقل — يستدعي الـ callback أو يحفظ كـ pending
  // ══════════════════════════════════════════════════════════
  void _navigate(NotificationNavData data) {
    if (_onTap != null) {
      _onTap!(data);
    } else {
      // حفظ مؤقت حتى يُسجَّل الـ callback
      _pendingNavData = data;
    }
  }

  // ══════════════════════════════════════════════════════════
  // تحويل String إلى NotificationNavType
  // ══════════════════════════════════════════════════════════
  NotificationNavType _navTypeFromString(String type) {
    switch (type) {
      case 'group_chat':
        return NotificationNavType.groupChat;
      case 'private_chat':
        return NotificationNavType.privateChat;
      case 'join_request':
        return NotificationNavType.joinRequest;
      case 'request_accepted':
        return NotificationNavType.requestAccepted;
      case 'comment':
        return NotificationNavType.comment;
      default:
        return NotificationNavType.other;
    }
  }

  // ══════════════════════════════════════════════════════════
  // background handler — يُستدعى من main.dart
  // ══════════════════════════════════════════════════════════
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await showLocalNotification(message);
  }

  // ══════════════════════════════════════════════════════════
  // FCM Token
  // ══════════════════════════════════════════════════════════
  Future<String?> getToken() async {
    final token = await _fcm.getToken();
    debugPrint('🎯 FCM Token: $token');
    return token;
  }

  void listenToTokenRefresh(Function(String token) onRefresh) {
    _fcm.onTokenRefresh.listen(onRefresh);
  }
}