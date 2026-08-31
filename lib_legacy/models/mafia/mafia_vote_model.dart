// lib/models/mafia/mafia_vote_model.dart
//
// ✅ إضافة dayNumber: يربط كل صوت بيوم تصويت محدد، بنفس منطق
// nightNumber في MafiaActionModel — ضروري لأن votes تتراكم طوال
// عمر المباراة، ولازم نميّز تصويت كل يوم عن الثاني.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaVoteModel {
  final String id;
  final String voterId;
  final String targetId;
  final int dayNumber;
  final DateTime time;

  const MafiaVoteModel({
    required this.id,
    required this.voterId,
    required this.targetId,
    required this.dayNumber,
    required this.time,
  });

  factory MafiaVoteModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaVoteModel(
      id: id,
      voterId: map['voterId'] ?? '',
      targetId: map['targetId'] ?? '',
      dayNumber: map['dayNumber'] ?? 0,
      time: map['time'] != null ? _toDateTime(map['time']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'voterId': voterId,
      'targetId': targetId,
      'dayNumber': dayNumber,
      'time': Timestamp.fromDate(time),
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
