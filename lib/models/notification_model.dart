// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTypes {
  static const String joinRequest      = 'join_request';
  static const String requestAccepted  = 'request_accepted';
  static const String requestRejected  = 'request_rejected';
  static const String groupDisbanded   = 'group_disbanded';
  static const String comment          = 'comment';
  static const String generic          = 'generic';
  static const String editLike         = 'edit_like';         // ✅ جديد
  static const String respectReceived  = 'respect_received';  // ✅ جديد
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? refId;
  final String? senderId;
  final String? commentId;
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
      commentId: map['commentId'],
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
      'commentId': commentId,
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