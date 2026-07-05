import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaHistoryModel {
  final String id;
  final String gameId;
  final String winner;
  final int durationSeconds;
  final String version;
  final List<String> players;
  final DateTime endedAt;

  const MafiaHistoryModel({
    required this.id,
    required this.gameId,
    required this.winner,
    required this.durationSeconds,
    required this.version,
    required this.players,
    required this.endedAt,
  });

  factory MafiaHistoryModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaHistoryModel(
      id: id,
      gameId: map['gameId'] ?? '',
      winner: map['winner'] ?? '',
      durationSeconds: map['durationSeconds'] ?? 0,
      version: map['version'] ?? '',
      players: List<String>.from(map['players'] ?? []),
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
      'endedAt': Timestamp.fromDate(endedAt),
    };
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
