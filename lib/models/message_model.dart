import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

enum MessageType { text, media, gameEvent }

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
  final String? replyToId;
  final String? replyText;
  final Map<String, String>? reactions;
  final DateTime createdAt;
  final bool isRead;
  final int? audioDuration;
  final String? editThumbnail;
  final String? editAnimeTitle;
  final String? editId; // ← جديد

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
    this.replyToId,
    this.replyText,
    this.reactions,
    required this.createdAt,
    this.isRead = false,
    this.audioDuration,
    this.editThumbnail,
    this.editAnimeTitle,
    this.editId, // ← جديد
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
      replyToId: map['replyToId'],
      replyText: map['replyText'],
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'] as Map)
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      audioDuration: map['audioDuration'],
      editThumbnail: map['editThumbnail'],
      editAnimeTitle: map['editAnimeTitle'],
      editId: map['editId'], // ← جديد
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
      'replyToId': replyToId,
      'replyText': replyText,
      'reactions': reactions,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'audioDuration': audioDuration,
      'editThumbnail': editThumbnail,
      'editAnimeTitle': editAnimeTitle,
      'editId': editId, // ← جديد
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
    Map<String, String>? reactions,
    bool? isRead,
    int? audioDuration,
    String? editThumbnail,
    String? editAnimeTitle,
    String? editId, // ← جديد
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
      replyToId: replyToId,
      replyText: replyText,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      audioDuration: audioDuration ?? this.audioDuration,
      editThumbnail: editThumbnail ?? this.editThumbnail,
      editAnimeTitle: editAnimeTitle ?? this.editAnimeTitle,
      editId: editId ?? this.editId, // ← جديد
    );
  }
}