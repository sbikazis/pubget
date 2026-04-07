// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

class MessageModel {
  final String id;

  final String senderId;
  final String senderName;
  final String senderAvatar;
  final Roles senderRole;

  final String? text;

  final String? mediaUrl;
  final String? mediaType; // image | video | audio

  final String? gameId;

  // الحقول الجديدة للرد والتفاعلات
  final String? replyToId;     // معرف الرسالة التي يتم الرد عليها
  final String? replyText;     // نص الرسالة المردود عليها (للعرض السريع)
  final Map<String, String>? reactions; // خريطة: {userId: emoji}

  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderRole,
    this.text,
    this.mediaUrl,
    this.mediaType,
    this.gameId,
    this.replyToId,
    this.replyText,
    this.reactions,
    required this.createdAt,
  });

  /// Firestore → Model
  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      senderRole: Roles.fromString(map['senderRole'] ?? 'member'),
      text: map['text'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      gameId: map['gameId'],
      replyToId: map['replyToId'],
      replyText: map['replyText'],
      // تحويل خريطة التفاعلات من Firestore بأمان
      reactions: map['reactions'] != null 
          ? Map<String, String>.from(map['reactions'] as Map) 
          : null,
      // تأمين تحويل التاريخ لتجنب الأخطاء البرمجية
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderRole': senderRole.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'gameId': gameId,
      'replyToId': replyToId,
      'replyText': replyText,
      'reactions': reactions,
      'createdAt': Timestamp.fromDate(createdAt), // التأكد من إرسالها كـ Timestamp
    };
  }
}