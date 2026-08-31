// lib/core/utils/notification_service.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

enum NotificationNavType {
  groupChat,
  privateChat,
  joinRequest,
  requestAccepted,
  comment,
  editLike,        // ✅ جديد
  respectReceived, // ✅ جديد
  other,
}

class NotificationNavData {
  final NotificationNavType type;
  final String? refId;
  final String? senderId;
  final String? commentId;
  final String? messageId;

  const NotificationNavData({
    required this.type,
    this.refId,
    this.senderId,
    this.commentId,
    this.messageId,
  });
}

typedef NotificationTapCallback = void Function(NotificationNavData data);

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

  NotificationTapCallback? _onTap;
  NotificationReplyCallback? _onReply;
  NotificationNavData? _pendingNavData;

  static const List<String> _sounds = [
    'an1',  'an2',  'an3',  'an4',  'an5',
    'an6',  'an7',  'an8',  'an9',  'an10',
    'an11', 'an12', 'an13', 'an14', 'an15',
    'an16', 'an17', 'an18', 'an19', 'an20',
    'an21',
  ];

  String _randomSound() => _sounds[Random().nextInt(_sounds.length)];

  static const String _groupChannelId     = 'pubget_reply_group';
  static const String _privateChannelId   = 'pubget_reply_private';
  static const String _replyGroupAction   = 'REPLY_GROUP';
  static const String _replyPrivateAction = 'REPLY_PRIVATE';

  void registerCallbacks({
    required NotificationTapCallback onTap,
    required NotificationReplyCallback onReply,
  }) {
    _onTap   = onTap;
    _onReply = onReply;
    if (_pendingNavData != null) {
      _onTap?.call(_pendingNavData!);
      _pendingNavData = null;
    }
  }

  Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setAutoInitEnabled(true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationResponse,
    );

    await _createReplyChannels();
    await _createSoundChannels();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      _handleRemoteMessageTap(initialMessage);
    }
  }

  Future<void> _createReplyChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _groupChannelId,
        'رسائل المجموعات',
        description: 'رسائل دردشة المجموعات مع إمكانية الرد المباشر',
        importance: Importance.max,
        playSound: true,
      ),
    );

    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _privateChannelId,
        'الرسائل الخاصة',
        description: 'الرسائل الخاصة مع إمكانية الرد المباشر',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  Future<void> _createSoundChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    for (final sound in _sounds) {
      await plugin.createNotificationChannel(
        AndroidNotificationChannel(
          'pubget_channel_$sound',
          'Pubget Notifications',
          description: 'إشعارات تطبيق Pubget',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
        ),
      );
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    showLocalNotification(message);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleRemoteMessageTap(message);
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final data    = message.data;
    final type    = data['type'] ?? '';
    final title   = message.notification?.title ?? 'Pubget';
    final body    = message.notification?.body ?? '';
    final sound   = _randomSound();
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = _buildPayload(data);

    final bool isGroupChat   = type == 'group_chat';
    final bool isPrivateChat = type == 'private_chat';

    AndroidNotificationDetails androidDetails;

    if (isGroupChat || isPrivateChat) {
      final channelId   = isGroupChat ? _groupChannelId   : _privateChannelId;
      final actionId    = isGroupChat ? _replyGroupAction : _replyPrivateAction;
      final channelName = isGroupChat ? 'رسائل المجموعات' : 'الرسائل الخاصة';

      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        styleInformation: BigTextStyleInformation(body),
        actions: [
          AndroidNotificationAction(
            actionId,
            'رد',
            inputs: [
              const AndroidNotificationActionInput(
                label: 'اكتب ردك...',
                allowFreeFormInput: true,
                choices: [],
              ),
            ],
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
        additionalFlags: Int32List.fromList([4]),
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'pubget_channel_$sound',
        'Pubget Notifications',
        channelDescription: 'إشعارات تطبيق Pubget',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        styleInformation: BigTextStyleInformation(body),
      );
    }

    await _localNotifications.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  String _buildPayload(Map<String, dynamic> data) {
    final type      = data['type']      ?? '';
    final refId     = data['refId']     ?? '';
    final senderId  = data['senderId']  ?? '';
    final commentId = data['commentId'] ?? '';
    final messageId = data['messageId'] ?? '';
    return '$type|$refId|$senderId|$commentId|$messageId';
  }

  NotificationNavData _parsePayload(String payload) {
    final parts     = payload.split('|');
    final type      = parts.isNotEmpty ? parts[0] : '';
    final refId     = parts.length > 1 ? parts[1] : null;
    final senderId  = parts.length > 2 ? parts[2] : null;
    final commentId = parts.length > 3 ? parts[3] : null;
    final messageId = parts.length > 4 ? parts[4] : null;

    return NotificationNavData(
      type:      _navTypeFromString(type),
      refId:     (refId?.isEmpty == true)     ? null : refId,
      senderId:  (senderId?.isEmpty == true)  ? null : senderId,
      commentId: (commentId?.isEmpty == true) ? null : commentId,
      messageId: (messageId?.isEmpty == true) ? null : messageId,
    );
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload  = response.payload ?? '';
    final actionId = response.actionId ?? '';
    final input    = response.input ?? '';

    if (payload.isEmpty) return;

    final navData = _parsePayload(payload);

    if (actionId.isEmpty) {
      _navigate(navData);
      return;
    }

    final isReplyAction = actionId == _replyGroupAction ||
                          actionId == _replyPrivateAction;

    if (isReplyAction && input.trim().isNotEmpty && navData.refId != null) {
      _onReply?.call(
        type:      navData.type,
        refId:     navData.refId!,
        replyText: input.trim(),
      );
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundLocalNotificationResponse(
      NotificationResponse response) {
    debugPrint('🔔 Background notification response: ${response.actionId}');
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    final navData = NotificationNavData(
      type:      _navTypeFromString(message.data['type'] ?? ''),
      refId:     message.data['refId'],
      senderId:  message.data['senderId'],
      commentId: message.data['commentId'],
      messageId: message.data['messageId'],
    );
    _navigate(navData);
  }

  void _navigate(NotificationNavData data) {
    if (_onTap != null) {
      _onTap!(data);
    } else {
      _pendingNavData = data;
    }
  }

  // ✅ إضافة edit_like و respect_received
  NotificationNavType _navTypeFromString(String type) {
    switch (type) {
      case 'group_chat':       return NotificationNavType.groupChat;
      case 'private_chat':     return NotificationNavType.privateChat;
      case 'join_request':     return NotificationNavType.joinRequest;
      case 'request_accepted': return NotificationNavType.requestAccepted;
      case 'comment':          return NotificationNavType.comment;
      case 'edit_like':        return NotificationNavType.editLike;
      case 'respect_received': return NotificationNavType.respectReceived;
      default:                 return NotificationNavType.other;
    }
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await showLocalNotification(message);
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