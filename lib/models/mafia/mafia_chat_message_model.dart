import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaChatMessageModel {
  final String id;
  final String sender;
  final String text;
  final DateTime time;
  final String type;

  const MafiaChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.type = 'player',
  });

  factory MafiaChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaChatMessageModel(
      id: id,
      sender: map['sender'] ?? '',
      text: map['text'] ?? '',
      time: map['time'] != null ? _toDateTime(map['time']) : DateTime.now(),
      type: map['type'] ?? 'player',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
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
