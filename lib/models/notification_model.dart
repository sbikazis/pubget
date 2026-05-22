// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// أنواع الإشعارات التي يدعمها النظام
class NotificationTypes {
  static const String joinRequest = 'join_request'; // طلب انضمام جديد (يصل للشوغو)
  static const String requestAccepted = 'request_accepted'; // تم قبولك (يصل للمستخدم)
  static const String requestRejected = 'request_rejected'; // تم رفضك (يصل للمستخدم)
  static const String groupDisbanded = 'group_disbanded'; // تفكيك المجموعة من قبل المؤسس
  static const String comment = 'comment'; // تعليق جديد على إيديت
  static const String generic = 'generic'; // إشعار عام
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // استخدم NotificationTypes
  final String? refId; // غالباً سيكون الـ groupId أو editId
  final String? senderId; // من أرسل الطلب أو من قام بالرد
  final String? commentId; // ← جديد: ID التعليق للسكرول المباشر
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    this.senderId,
    this.commentId,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? NotificationTypes.generic,
      refId: map['refId'],
      senderId: map['senderId'],
      commentId: map['commentId'], // ← جديد
      createdAt: _toDateTime(map['createdAt']),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'refId': refId,
      'senderId': senderId,
      'commentId': commentId, // ← جديد
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({
    String? title,
    String? body,
    String? type,
    String? refId,
    String? senderId,
    String? commentId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      refId: refId ?? this.refId,
      senderId: senderId ?? this.senderId,
      commentId: commentId ?? this.commentId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}