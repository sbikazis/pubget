import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/game_status.dart';

class GameModel {
  final String id;
  final String groupId;

  final String playerOneId;
  final String? playerTwoId;

  final String? playerOneCharacter;
  final String? playerTwoCharacter;

  final String? currentTurnUserId;

  final GameStatus status;

  final String? winnerUserId;

  final DateTime createdAt;
  final DateTime? finishedAt;

  const GameModel({
    required this.id,
    required this.groupId,
    required this.playerOneId,
    this.playerTwoId,
    this.playerOneCharacter,
    this.playerTwoCharacter,
    this.currentTurnUserId,
    required this.status,
    this.winnerUserId,
    required this.createdAt,
    this.finishedAt,
  });

  /// Firestore → Model
  factory GameModel.fromMap(String id, Map<String, dynamic> map) {
    return GameModel(
      id: id,
      groupId: map['groupId'] ?? '',
      playerOneId: map['playerOneId'] ?? '',
      playerTwoId: map['playerTwoId'],
      playerOneCharacter: map['playerOneCharacter'],
      playerTwoCharacter: map['playerTwoCharacter'],
      currentTurnUserId: map['currentTurnUserId'],
      status: GameStatus.fromString(map['status'] ?? 'waiting'),
      winnerUserId: map['winnerUserId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      finishedAt: map['finishedAt'] != null
          ? (map['finishedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'playerOneId': playerOneId,
      'playerTwoId': playerTwoId,
      'playerOneCharacter': playerOneCharacter,
      'playerTwoCharacter': playerTwoCharacter,
      'currentTurnUserId': currentTurnUserId,
      'status': status.name,
      'winnerUserId': winnerUserId,
      'createdAt': createdAt,
      'finishedAt': finishedAt,
    };
  }

  GameModel copyWith({
    String? playerTwoId,
    String? playerOneCharacter,
    String? playerTwoCharacter,
    String? currentTurnUserId,
    GameStatus? status,
    String? winnerUserId,
    DateTime? finishedAt,
  }) {
    return GameModel(
      id: id,
      groupId: groupId,
      playerOneId: playerOneId,
      playerTwoId: playerTwoId ?? this.playerTwoId,
      playerOneCharacter:
          playerOneCharacter ?? this.playerOneCharacter,
      playerTwoCharacter:
          playerTwoCharacter ?? this.playerTwoCharacter,
      currentTurnUserId:
          currentTurnUserId ?? this.currentTurnUserId,
      status: status ?? this.status,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      createdAt: createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}