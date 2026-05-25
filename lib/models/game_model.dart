import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/game_status.dart';

class GameModel {
  final String id;
  final String groupId;
  final String gameSlot;

  // نوع اللعبة
  final String gameType; // 'guess' أو 'anime_chain'

  // --- حقول أسماء اللاعبين ---
  final String? playerOneName;
  final String? playerTwoName;

  // --- حقول لعبة التخمين ---
  final String playerOneId;
  final String? playerTwoId;
  final String? playerOneCharacter;
  final String? playerOneImage;
  final String? playerTwoCharacter;
  final String? playerTwoImage;
  final bool isPlayerOneReady;
  final bool isPlayerTwoReady;

  // --- حقول سلسلة الأنمي ---
  final String? currentWord;
  final String? lastLetter;
  final List<String> usedWords;
  final List<String> players;
  final String? pendingStartWord; // ← جديد

  // --- حقول مشتركة ---
  final String? currentTurnUserId;
  final GameStatus status;
  final String? winnerUserId;
  final DateTime createdAt;
  final DateTime? setupStartedAt;
  final DateTime? lastActionAt;
  final String? lastActionType;
  final DateTime? finishedAt;
  final String? endReason;

  const GameModel({
    required this.id,
    required this.groupId,
    required this.gameSlot,
    this.gameType = 'guess',
    this.playerOneName,
    this.playerTwoName,
    required this.playerOneId,
    this.playerTwoId,
    this.playerOneCharacter,
    this.playerOneImage,
    this.playerTwoCharacter,
    this.playerTwoImage,
    this.isPlayerOneReady = false,
    this.isPlayerTwoReady = false,
    this.currentWord,
    this.lastLetter,
    this.usedWords = const [],
    this.players = const [],
    this.pendingStartWord, // ← جديد
    this.currentTurnUserId,
    required this.status,
    this.winnerUserId,
    required this.createdAt,
    this.setupStartedAt,
    this.lastActionAt,
    this.lastActionType,
    this.finishedAt,
    this.endReason,
  });

  factory GameModel.fromMap(String id, Map<String, dynamic> map) {
    GameStatus gameStatus = GameStatus.waitingForOpponent;
    if (map['status'] != null) {
      try {
        gameStatus = GameStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => GameStatus.waitingForOpponent,
        );
      } catch (_) {
        gameStatus = GameStatus.waitingForOpponent;
      }
    }

    return GameModel(
      id: id,
      groupId: map['groupId'] ?? '',
      gameSlot: map['gameSlot'] ?? 'game_1',
      gameType: map['gameType'] ?? 'guess',
      playerOneName: map['playerOneName'],
      playerTwoName: map['playerTwoName'],
      playerOneId: map['playerOneId'] ?? '',
      playerTwoId: map['playerTwoId'],
      playerOneCharacter: map['playerOneCharacter'],
      playerOneImage: map['playerOneImage'],
      playerTwoCharacter: map['playerTwoCharacter'],
      playerTwoImage: map['playerTwoImage'],
      isPlayerOneReady: map['isPlayerOneReady'] ?? false,
      isPlayerTwoReady: map['isPlayerTwoReady'] ?? false,
      currentWord: map['currentWord'],
      lastLetter: map['lastLetter'],
      usedWords: List<String>.from(map['usedWords'] ?? []),
      players: List<String>.from(map['players'] ?? []),
      pendingStartWord: map['pendingStartWord'], // ← جديد
      currentTurnUserId: map['currentTurnUserId'],
      status: gameStatus,
      winnerUserId: map['winnerUserId'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      setupStartedAt: map['setupStartedAt'] != null 
          ? (map['setupStartedAt'] as Timestamp).toDate() 
          : null,
      lastActionAt: map['lastActionAt'] != null 
          ? (map['lastActionAt'] as Timestamp).toDate() 
          : null,
      lastActionType: map['lastActionType'],
      finishedAt: map['finishedAt'] != null 
          ? (map['finishedAt'] as Timestamp).toDate() 
          : null,
      endReason: map['endReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'gameSlot': gameSlot,
      'gameType': gameType,
      'playerOneName': playerOneName,
      'playerTwoName': playerTwoName,
      'playerOneId': playerOneId,
      'playerTwoId': playerTwoId,
      'playerOneCharacter': playerOneCharacter,
      'playerOneImage': playerOneImage,
      'playerTwoCharacter': playerTwoCharacter,
      'playerTwoImage': playerTwoImage,
      'isPlayerOneReady': isPlayerOneReady,
      'isPlayerTwoReady': isPlayerTwoReady,
      'currentWord': currentWord,
      'lastLetter': lastLetter,
      'usedWords': usedWords,
      'players': players,
      'pendingStartWord': pendingStartWord, // ← جديد
      'currentTurnUserId': currentTurnUserId,
      'status': status.name,
      'winnerUserId': winnerUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'setupStartedAt': setupStartedAt != null ? Timestamp.fromDate(setupStartedAt!) : null,
      'lastActionAt': lastActionAt != null ? Timestamp.fromDate(lastActionAt!) : null,
      'lastActionType': lastActionType,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'endReason': endReason,
    };
  }

  GameModel copyWith({
    String? gameType,
    String? playerOneName,
    String? playerTwoName,
    String? playerTwoId,
    String? playerOneCharacter,
    String? playerOneImage,
    String? playerTwoCharacter,
    String? playerTwoImage,
    bool? isPlayerOneReady,
    bool? isPlayerTwoReady,
    String? currentWord,
    String? lastLetter,
    List<String>? usedWords,
    List<String>? players,
    String? pendingStartWord, // ← جديد
    String? currentTurnUserId,
    GameStatus? status,
    String? winnerUserId,
    DateTime? setupStartedAt,
    DateTime? lastActionAt,
    String? lastActionType,
    DateTime? finishedAt,
    String? endReason,
  }) {
    return GameModel(
      id: id,
      groupId: groupId,
      gameSlot: gameSlot,
      gameType: gameType ?? this.gameType,
      playerOneName: playerOneName ?? this.playerOneName,
      playerTwoName: playerTwoName ?? this.playerTwoName,
      playerOneId: playerOneId,
      playerTwoId: playerTwoId ?? this.playerTwoId,
      playerOneCharacter: playerOneCharacter ?? this.playerOneCharacter,
      playerOneImage: playerOneImage ?? this.playerOneImage,
      playerTwoCharacter: playerTwoCharacter ?? this.playerTwoCharacter,
      playerTwoImage: playerTwoImage ?? this.playerTwoImage,
      isPlayerOneReady: isPlayerOneReady ?? this.isPlayerOneReady,
      isPlayerTwoReady: isPlayerTwoReady ?? this.isPlayerTwoReady,
      currentWord: currentWord ?? this.currentWord,
      lastLetter: lastLetter ?? this.lastLetter,
      usedWords: usedWords ?? this.usedWords,
      players: players ?? this.players,
      pendingStartWord: pendingStartWord ?? this.pendingStartWord, // ← جديد
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      status: status ?? this.status,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      createdAt: createdAt,
      setupStartedAt: setupStartedAt ?? this.setupStartedAt,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      lastActionType: lastActionType ?? this.lastActionType,
      finishedAt: finishedAt ?? this.finishedAt,
      endReason: endReason ?? this.endReason,
    );
  }
}
