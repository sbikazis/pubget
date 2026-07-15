// lib/models/mafia/mafia_history_model.dart
//
// ✅ توسعة: إضافة playerDetails (دور/فريق/نتيجة كل لاعب) بجانب
// players (قائمة المعرّفات فقط، أُبقيت للتوافق البسيط). winner صار
// nullable لتغطية حالة التعادل النادرة من winConditionChecker.js.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaHistoryPlayerEntry {
  final String userId;
  final String username;
  final String role;
  final String team;
  final bool won;

  const MafiaHistoryPlayerEntry({
    required this.userId,
    required this.username,
    required this.role,
    required this.team,
    required this.won,
  });

  factory MafiaHistoryPlayerEntry.fromMap(Map<String, dynamic> map) {
    return MafiaHistoryPlayerEntry(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      role: map['role'] ?? '',
      team: map['team'] ?? '',
      won: map['won'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'role': role,
      'team': team,
      'won': won,
    };
  }
}

class MafiaHistoryModel {
  final String id;
  final String gameId;
  final String? winner;
  final int durationSeconds;
  final String version;
  final List<String> players;
  final List<MafiaHistoryPlayerEntry> playerDetails;
  final DateTime endedAt;

  const MafiaHistoryModel({
    required this.id,
    required this.gameId,
    this.winner,
    required this.durationSeconds,
    required this.version,
    required this.players,
    this.playerDetails = const [],
    required this.endedAt,
  });

  factory MafiaHistoryModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaHistoryModel(
      id: id,
      gameId: map['gameId'] ?? '',
      winner: map['winner'],
      durationSeconds: map['durationSeconds'] ?? 0,
      version: map['version'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      playerDetails: (map['playerDetails'] as List<dynamic>? ?? [])
          .map((e) => MafiaHistoryPlayerEntry.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      endedAt:
          map['endedAt'] != null ? _toDateTime(map['endedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'winner': winner,
      'durationSeconds': durationSeconds,
      'version': version,
      'players': players,
      'playerDetails': playerDetails.map((e) => e.toMap()).toList(),
      'endedAt': Timestamp.fromDate(endedAt),
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}