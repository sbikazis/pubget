import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

enum MessageType { text, media, gameEvent, gameInvite, systemEvent } // ✅ إضافة systemEvent

enum MessageStatus { sending, sent, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final bool senderIsPremium;
  final Roles? senderRole;
  final String? text;
  final String? mediaUrl;
  final String? mediaType;
  final MessageType type;
  final String? gameId;
  final String? gameSlot;
  final String? gameAction;
  final String? systemEventType; // ✅ جديد: join / leave / kick / roleAssign
  final String? replyToId;
  final String? replyText;
  final String? replyToSenderName;
  final String? replyToMediaUrl;
  final Map<String, String>? reactions;
  final DateTime createdAt;
  final bool isRead;
  final bool isDelivered;
  final int? audioDuration;
  final String? editThumbnail;
  final String? editAnimeTitle;
  final String? editId;
  final bool isEdited; // ✅ جديد: تم تعديل الرسالة أم لا
  final MessageStatus status;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderIsPremium = false,
    this.senderRole,
    this.text,
    this.mediaUrl,
    this.mediaType,
    this.type = MessageType.text,
    this.gameId,
    this.gameSlot,
    this.gameAction,
    this.systemEventType, // ✅ جديد
    this.replyToId,
    this.replyText,
    this.replyToSenderName,
    this.replyToMediaUrl,
    this.reactions,
    required this.createdAt,
    this.isRead = false,
    this.isDelivered = false,
    this.audioDuration,
    this.editThumbnail,
    this.editAnimeTitle,
    this.editId,
    this.isEdited = false, // ✅ جديد
    this.status = MessageStatus.sent,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      senderIsPremium: map['senderIsPremium'] ?? false,
      senderRole: map['senderRole'] != null
          ? Roles.fromString(map['senderRole'])
          : null,
      text: map['text'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      type: map['type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => MessageType.text)
          : MessageType.text,
      gameId: map['gameId'],
      gameSlot: map['gameSlot'],
      gameAction: map['gameAction'],
      systemEventType: map['systemEventType'], // ✅ جديد
      replyToId: map['replyToId'],
      replyText: map['replyText'],
      replyToSenderName: map['replyToSenderName'],
      replyToMediaUrl: map['replyToMediaUrl'],
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'] as Map)
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      audioDuration: map['audioDuration'],
      editThumbnail: map['editThumbnail'],
      editAnimeTitle: map['editAnimeTitle'],
      editId: map['editId'],
      isEdited: map['isEdited'] ?? false, // ✅ جديد
      status: MessageStatus.sent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderIsPremium': senderIsPremium,
      'senderRole': senderRole?.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'type': type.name,
      'gameId': gameId,
      'gameSlot': gameSlot,
      'gameAction': gameAction,
      'systemEventType': systemEventType, // ✅ جديد
      'replyToId': replyToId,
      'replyText': replyText,
      'replyToSenderName': replyToSenderName,
      'replyToMediaUrl': replyToMediaUrl,
      'reactions': reactions,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'audioDuration': audioDuration,
      'editThumbnail': editThumbnail,
      'editAnimeTitle': editAnimeTitle,
      'editId': editId,
      'isEdited': isEdited, // ✅ جديد
      // status لا يُحفظ في Firestore عمداً
    };
  }

  MessageModel copyWith({
    String? senderName,
    String? senderAvatar,
    bool? senderIsPremium,
    Roles? senderRole,
    String? text,
    MessageType? type,
    String? gameId,
    String? gameSlot,
    String? gameAction,
    String? systemEventType, // ✅ جديد
    Map<String, String>? reactions,
    bool? isRead,
    bool? isDelivered,
    int? audioDuration,
    String? editThumbnail,
    String? editAnimeTitle,
    String? editId,
    bool? isEdited, // ✅ جديد
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderIsPremium: senderIsPremium ?? this.senderIsPremium,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      type: type ?? this.type,
      gameId: gameId ?? this.gameId,
      gameSlot: gameSlot ?? this.gameSlot,
      gameAction: gameAction ?? this.gameAction,
      systemEventType: systemEventType ?? this.systemEventType, // ✅ جديد
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      audioDuration: audioDuration ?? this.audioDuration,
      editThumbnail: editThumbnail ?? this.editThumbnail,
      editAnimeTitle: editAnimeTitle ?? this.editAnimeTitle,
      editId: editId ?? this.editId,
      isEdited: isEdited ?? this.isEdited, // ✅ جديد
      status: status ?? this.status,
    );
  }
}