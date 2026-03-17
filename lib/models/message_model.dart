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
      createdAt: (map['createdAt'] as Timestamp).toDate(),
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
      'createdAt': createdAt,
    };
  }
}