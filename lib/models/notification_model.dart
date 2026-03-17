// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// NotificationModel
/// الحقول الأساسية المتوقعة في مستند الإشعار داخل Firestore:
/// - id: معرف المستند
/// - title: عنوان الإشعار
/// - body: نص الإشعار
/// - type: نوع الإشعار (e.g., "group", "private_message", "profile", "promotion")
/// - refId: مرجع الكيان المرتبط (groupId, chatId, userId, ...)
/// - createdAt: تاريخ الإنشاء
/// - isRead: هل قُرئ الإشعار
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? refId;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'generic',
      refId: map['refId'],
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
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({
    String? title,
    String? body,
    String? type,
    String? refId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      refId: refId ?? this.refId,
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