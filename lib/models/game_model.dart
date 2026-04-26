import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/game_status.dart';

class GameModel {
  final String id;
  final String groupId;

  // تمييز مكان اللعبة (game_1 أو game_2) لتمييز الألوان والرسائل
  final String gameSlot;

  final String playerOneId;
  final String? playerTwoId;

  // بيانات الشخصيات (الاسم والصورة من MAL)
  final String? playerOneCharacter;
  final String? playerOneImage;
  final String? playerTwoCharacter;
  final String? playerTwoImage;

  // نظام الجاهزية (للتأكد من ضغط زر "بدأ" من الطرفين)
  final bool isPlayerOneReady;
  final bool isPlayerTwoReady;

  final String? currentTurnUserId;
  final GameStatus status;
  final String? winnerUserId;

  // نظام العدادات الزمنية
  final DateTime createdAt; // وقت إنشاء الطلب
  final DateTime? setupStartedAt; // وقت بدء مرحلة الـ 60 ثانية
  final DateTime? lastActionAt; // وقت آخر سؤال/جواب لإدارة الـ 40 ثانية
  final DateTime? finishedAt;

  const GameModel({
    required this.id,
    required this.groupId,
    required this.gameSlot,
    required this.playerOneId,
    this.playerTwoId,
    this.playerOneCharacter,
    this.playerOneImage,
    this.playerTwoCharacter,
    this.playerTwoImage,
    this.isPlayerOneReady = false,
    this.isPlayerTwoReady = false,
    this.currentTurnUserId,
    required this.status,
    this.winnerUserId,
    required this.createdAt,
    this.setupStartedAt,
    this.lastActionAt,
    this.finishedAt,
  });

  /// Firestore → Model
  factory GameModel.fromMap(String id, Map<String, dynamic> map) {
    return GameModel(
      id: id,
      groupId: map['groupId'] ?? '',
      gameSlot: map['gameSlot'] ?? 'game_1',
      playerOneId: map['playerOneId'] ?? '',
      playerTwoId: map['playerTwoId'],
      playerOneCharacter: map['playerOneCharacter'],
      playerOneImage: map['playerOneImage'],
      playerTwoCharacter: map['playerTwoCharacter'],
      playerTwoImage: map['playerTwoImage'],
      isPlayerOneReady: map['isPlayerOneReady'] ?? false,
      isPlayerTwoReady: map['isPlayerTwoReady'] ?? false,
      currentTurnUserId: map['currentTurnUserId'],
      status: GameStatus.fromString(map['status'] ?? 'waitingForOpponent'),
      winnerUserId: map['winnerUserId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      setupStartedAt: map['setupStartedAt'] != null 
          ? (map['setupStartedAt'] as Timestamp).toDate() 
          : null,
      lastActionAt: map['lastActionAt'] != null 
          ? (map['lastActionAt'] as Timestamp).toDate() 
          : null,
      finishedAt: map['finishedAt'] != null
          ? (map['finishedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'gameSlot': gameSlot,
      'playerOneId': playerOneId,
      'playerTwoId': playerTwoId,
      'playerOneCharacter': playerOneCharacter,
      'playerOneImage': playerOneImage,
      'playerTwoCharacter': playerTwoCharacter,
      'playerTwoImage': playerTwoImage,
      'isPlayerOneReady': isPlayerOneReady,
      'isPlayerTwoReady': isPlayerTwoReady,
      'currentTurnUserId': currentTurnUserId,
      'status': status.name,
      'winnerUserId': winnerUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'setupStartedAt': setupStartedAt != null ? Timestamp.fromDate(setupStartedAt!) : null,
      'lastActionAt': lastActionAt != null ? Timestamp.fromDate(lastActionAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
    };
  }

  GameModel copyWith({
    String? playerTwoId,
    String? playerOneCharacter,
    String? playerOneImage,
    String? playerTwoCharacter,
    String? playerTwoImage,
    bool? isPlayerOneReady,
    bool? isPlayerTwoReady,
    String? currentTurnUserId,
    GameStatus? status,
    String? winnerUserId,
    DateTime? setupStartedAt,
    DateTime? lastActionAt,
    DateTime? finishedAt,
  }) {
    return GameModel(
      id: id,
      groupId: groupId,
      gameSlot: gameSlot,
      playerOneId: playerOneId,
      playerTwoId: playerTwoId ?? this.playerTwoId,
      playerOneCharacter: playerOneCharacter ?? this.playerOneCharacter,
      playerOneImage: playerOneImage ?? this.playerOneImage,
      playerTwoCharacter: playerTwoCharacter ?? this.playerTwoCharacter,
      playerTwoImage: playerTwoImage ?? this.playerTwoImage,
      isPlayerOneReady: isPlayerOneReady ?? this.isPlayerOneReady,
      isPlayerTwoReady: isPlayerTwoReady ?? this.isPlayerTwoReady,
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      status: status ?? this.status,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      createdAt: createdAt,
      setupStartedAt: setupStartedAt ?? this.setupStartedAt,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}