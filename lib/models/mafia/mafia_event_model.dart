import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaEventModel {
  final String id;
  final String type;
  final String message;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const MafiaEventModel({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.payload = const {},
  });

  factory MafiaEventModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaEventModel(
      id: id,
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] != null
          ? _toDateTime(map['createdAt'])
          : DateTime.now(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'payload': payload,
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
