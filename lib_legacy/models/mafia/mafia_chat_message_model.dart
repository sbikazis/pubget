// lib/models/mafia/mafia_chat_message_model.dart
//
// ✅ إضافتان: senderId (لتحديد isMe بدقة بدل مقارنة الاسم)،
// senderAvatar (لعرض الصورة الرمزية في MafiaChatBubble).

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaChatMessageModel {
  final String id;
  final String senderId;
  final String sender;
  final String senderAvatar;
  final String text;
  final DateTime time;
  final String type;

  const MafiaChatMessageModel({
    required this.id,
    this.senderId = '',
    required this.sender,
    this.senderAvatar = '',
    required this.text,
    required this.time,
    this.type = 'player',
  });

  factory MafiaChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaChatMessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      sender: map['sender'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      text: map['text'] ?? '',
      time: map['time'] != null ? _toDateTime(map['time']) : DateTime.now(),
      type: map['type'] ?? 'player',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'sender': sender,
      'senderAvatar': senderAvatar,
      'text': text,
      'time': Timestamp.fromDate(time),
      'type': type,
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}