// lib/models/mafia/mafia_action_model.dart
//
// ✅ إضافتان جوهريتان عن النسخة السابقة:
// - nightNumber: يربط كل إجراء بليلة محددة، لأن night_actions تتراكم
//   طوال عمر المباراة، ونحتاج نميّز إجراءات كل ليلة عن الثانية.
// - processedAt: يُكتب من nightResolver.js بعد معالجة الإجراء، لمنع
//   احتساب نفس الإجراء مرتين لو أعيد تشغيل الدالة لأي سبب.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaActionModel {
  final String id;
  final String playerId;
  final String role;
  final String? targetId;
  final int nightNumber;
  final DateTime submittedAt;
  final bool isCompleted;
  final DateTime? processedAt;

  const MafiaActionModel({
    required this.id,
    required this.playerId,
    required this.role,
    this.targetId,
    required this.nightNumber,
    required this.submittedAt,
    this.isCompleted = false,
    this.processedAt,
  });

  factory MafiaActionModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaActionModel(
      id: id,
      playerId: map['playerId'] ?? '',
      role: map['role'] ?? '',
      targetId: map['targetId'],
      nightNumber: map['nightNumber'] ?? 0,
      submittedAt: map['submittedAt'] != null
          ? _toDateTime(map['submittedAt'])
          : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
      processedAt: map['processedAt'] != null
          ? _toDateTime(map['processedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'targetId': targetId,
      'nightNumber': nightNumber,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}