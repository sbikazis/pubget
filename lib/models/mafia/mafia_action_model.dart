import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaActionModel {
  final String id;
  final String playerId;
  final String role;
  final String? targetId;
  final DateTime submittedAt;
  final bool isCompleted;

  const MafiaActionModel({
    required this.id,
    required this.playerId,
    required this.role,
    this.targetId,
    required this.submittedAt,
    this.isCompleted = false,
  });

  factory MafiaActionModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaActionModel(
      id: id,
      playerId: map['playerId'] ?? '',
      role: map['role'] ?? '',
      targetId: map['targetId'],
      submittedAt: map['submittedAt'] != null
          ? _toDateTime(map['submittedAt'])
          : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'role': role,
      'targetId': targetId,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'isCompleted': isCompleted,
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
