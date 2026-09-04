import 'package:cloud_firestore/cloud_firestore.dart';

enum GameType { guessCharacter, animeChain, emojiAnimeGuess, mafia }

enum GameStatus { draft, waiting, active, paused, completed, cancelled }

enum ParticipantStatus { active, left }

enum GameRoundStatus { pending, active, completed }

enum GameEventType {
  gameCreated,
  playerJoined,
  playerLeft,
  gameStarted,
  gamePaused,
  gameResumed,
  actionSubmitted,
  roundStarted,
  roundCompleted,
  gameCompleted,
  gameCancelled,
}

/// Generic action type names. Meaning belongs to the specific game.
abstract final class GameActionTypes {
  static const guess = 'guess';
  static const select = 'select';
  static const vote = 'vote';
  static const choose = 'choose';
  static const submit = 'submit';
  static const pass = 'pass';
}

final class GameConfiguration {
  const GameConfiguration({
    this.minPlayers = 1,
    this.maxPlayers = 16,
    this.usesRounds = false,
    this.roundCount = 5,
    this.timerSeconds = 20,
    this.difficulty = 'normal',
    this.extra = const <String, dynamic>{},
  });

  final int minPlayers;
  final int maxPlayers;
  final bool usesRounds;
  final int roundCount;
  final int timerSeconds;
  final String difficulty;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'minPlayers': minPlayers,
    'maxPlayers': maxPlayers,
    'usesRounds': usesRounds,
    'roundCount': roundCount,
    'timerSeconds': timerSeconds,
    'difficulty': difficulty,
    'extra': extra,
  };

  factory GameConfiguration.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const GameConfiguration();
    final extra = map['extra'] is Map
        ? Map<String, dynamic>.from(map['extra'] as Map)
        : const <String, dynamic>{};
    return GameConfiguration(
      minPlayers: (map['minPlayers'] as num?)?.toInt() ?? 1,
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 16,
      usesRounds: map['usesRounds'] == true,
      roundCount: (map['roundCount'] as num?)?.toInt() ??
          (extra['roundCount'] as num?)?.toInt() ??
          5,
      timerSeconds: (map['timerSeconds'] as num?)?.toInt() ??
          (extra['timerSeconds'] as num?)?.toInt() ??
          20,
      difficulty: map['difficulty'] as String? ??
          extra['difficulty'] as String? ??
          'normal',
      extra: extra,
    );
  }
}

final class GameResult {
  const GameResult({
    required this.kind,
    this.winnerIds = const <String>[],
    this.scores = const <String, int>{},
    this.summary = const <String, dynamic>{},
  });

  final String kind;
  final List<String> winnerIds;
  final Map<String, int> scores;
  final Map<String, dynamic> summary;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'kind': kind,
    'winnerIds': winnerIds,
    'scores': scores,
    'summary': summary,
  };

  factory GameResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const GameResult(kind: '');
    }
    return GameResult(
      kind: map['kind'] as String? ?? '',
      winnerIds:
          (map['winnerIds'] as List<Object?>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      scores: _intMap(map['scores']),
      summary: map['summary'] is Map
          ? Map<String, dynamic>.from(map['summary'] as Map)
          : const <String, dynamic>{},
    );
  }
}

final class PubgetGame {
  const PubgetGame({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.version,
    required this.status,
    required this.creatorId,
    required this.configuration,
    required this.participantsCount,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.startedAt,
    this.endedAt,
    this.result,
    this.currentRoundNumber,
    this.publicState = const <String, dynamic>{},
    this.currentPhase,
    this.stateVersion = 0,
    this.deadlineAt,
  });

  final String id;
  final GameType type;
  final String title;
  final String description;
  final int version;
  final GameStatus status;
  final String creatorId;
  final String? groupId;
  final GameConfiguration configuration;
  final int participantsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final GameResult? result;
  final int? currentRoundNumber;
  final Map<String, dynamic> publicState;
  final String? currentPhase;
  final int stateVersion;
  final DateTime? deadlineAt;

  bool get isJoinable => status == GameStatus.waiting;
  bool get isPlayable => status == GameStatus.active;
  bool get isTerminal =>
      status == GameStatus.completed || status == GameStatus.cancelled;
  bool get isHistorical => isTerminal;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type.name,
    'title': title,
    'description': description,
    'version': version,
    'status': status.name,
    'creatorId': creatorId,
    'groupId': groupId,
    'configuration': configuration.toMap(),
    'participantsCount': participantsCount,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'result': result?.toMap(),
    'currentRoundNumber': currentRoundNumber,
    'publicState': publicState,
    'currentPhase': currentPhase,
    'stateVersion': stateVersion,
    'deadlineAt': deadlineAt?.toUtc().toIso8601String(),
    'searchName': title.trim().toLowerCase(),
  };

  factory PubgetGame.fromMap(Map<String, dynamic> map, {required String id}) {
    return PubgetGame(
      id: id,
      type: GameType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => GameType.guessCharacter,
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      status: GameStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => GameStatus.draft,
      ),
      creatorId: map['creatorId'] as String? ?? '',
      groupId: map['groupId'] as String?,
      configuration: GameConfiguration.fromMap(
        map['configuration'] is Map
            ? Map<String, dynamic>.from(map['configuration'] as Map)
            : null,
      ),
      participantsCount: (map['participantsCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      startedAt: _date(map['startedAt']),
      endedAt: _date(map['endedAt']),
      result: map['result'] is Map
          ? GameResult.fromMap(Map<String, dynamic>.from(map['result'] as Map))
          : null,
      currentRoundNumber: (map['currentRoundNumber'] as num?)?.toInt(),
      publicState: map['publicState'] is Map
          ? Map<String, dynamic>.from(map['publicState'] as Map)
          : const <String, dynamic>{},
      currentPhase: map['currentPhase'] as String?,
      stateVersion: (map['stateVersion'] as num?)?.toInt() ?? 0,
      deadlineAt: _date(map['deadlineAt']),
    );
  }
}

final class GameParticipant {
  const GameParticipant({
    required this.gameId,
    required this.userId,
    required this.status,
    this.displayName = '',
    this.joinedAt,
    this.leftAt,
    this.score,
    this.metadata = const <String, dynamic>{},
  });

  final String gameId;
  final String userId;
  final ParticipantStatus status;
  final String displayName;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  /// Optional numeric score. Interpretation is owned by a [ScoringStrategy],
  /// not by this generic model (no coins/XP/wins assumed).
  final int? score;
  final Map<String, dynamic> metadata;

  bool get isActive => status == ParticipantStatus.active && leftAt == null;

  GameParticipant copyWith({
    ParticipantStatus? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    int? score,
    Map<String, dynamic>? metadata,
    bool clearScore = false,
  }) => GameParticipant(
    gameId: gameId,
    userId: userId,
    status: status ?? this.status,
    displayName: displayName,
    joinedAt: joinedAt ?? this.joinedAt,
    leftAt: leftAt ?? this.leftAt,
    score: clearScore ? null : score ?? this.score,
    metadata: metadata ?? this.metadata,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'gameId': gameId,
    'userId': userId,
    'status': status.name,
    'displayName': displayName,
    'joinedAt': joinedAt?.toUtc().toIso8601String(),
    'leftAt': leftAt?.toUtc().toIso8601String(),
    if (score != null) 'score': score,
    'metadata': metadata,
  };

  factory GameParticipant.fromMap(
    Map<String, dynamic> map, {
    required String userId,
  }) {
    return GameParticipant(
      gameId: map['gameId'] as String? ?? '',
      userId: userId,
      status: ParticipantStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => map['leftAt'] == null
            ? ParticipantStatus.active
            : ParticipantStatus.left,
      ),
      displayName: map['displayName'] as String? ?? userId,
      joinedAt: _date(map['joinedAt']),
      leftAt: _date(map['leftAt']),
      score: (map['score'] as num?)?.toInt(),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}

final class GameAction {
  const GameAction({
    required this.id,
    required this.gameId,
    required this.playerId,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.clientActionId,
    this.schemaVersion = 1,
  });

  final String id;
  final String gameId;
  final String playerId;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final String? clientActionId;
  final int schemaVersion;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'actionId': id,
    'gameId': gameId,
    'playerId': playerId,
    'actionType': actionType,
    'payload': payload,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'clientActionId': clientActionId,
    'schemaVersion': schemaVersion,
  };

  factory GameAction.fromMap(Map<String, dynamic> map, {required String id}) {
    return GameAction(
      id: map['actionId'] as String? ?? id,
      gameId: map['gameId'] as String? ?? '',
      playerId: map['playerId'] as String? ?? '',
      actionType: map['actionType'] as String? ?? '',
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : const <String, dynamic>{},
      createdAt: _date(map['createdAt']),
      clientActionId: map['clientActionId'] as String?,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

final class GameEvent {
  const GameEvent({
    required this.id,
    required this.gameId,
    required this.type,
    required this.actorId,
    required this.createdAt,
    this.payload = const <String, dynamic>{},
    this.schemaVersion = 1,
  });

  final String id;
  final String gameId;
  final GameEventType type;
  final String actorId;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;
  final int schemaVersion;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'eventId': id,
    'gameId': gameId,
    'type': _eventWireName(type),
    'actorId': actorId,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'payload': payload,
    'schemaVersion': schemaVersion,
  };

  factory GameEvent.fromMap(Map<String, dynamic> map, {required String id}) {
    return GameEvent(
      id: map['eventId'] as String? ?? id,
      gameId: map['gameId'] as String? ?? '',
      type: parseGameEventType(map['type'] as String?),
      actorId: map['actorId'] as String? ?? '',
      createdAt: _date(map['createdAt']),
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : const <String, dynamic>{},
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Contract Chat may consume later. Games never write chat messages from this.
final class GameActivity {
  const GameActivity({
    required this.gameId,
    required this.gameType,
    required this.eventType,
    required this.actorId,
    required this.createdAt,
    this.groupId,
    this.metadata = const <String, dynamic>{},
  });

  final String gameId;
  final GameType gameType;
  final String? groupId;
  final GameEventType eventType;
  final String actorId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'gameId': gameId,
    'gameType': gameType.name,
    'groupId': groupId,
    'eventType': _eventWireName(eventType),
    'actor': actorId,
    'metadata': metadata,
    'timestamp': createdAt?.toUtc().toIso8601String(),
  };

  factory GameActivity.fromEvent({
    required GameEvent event,
    required GameType gameType,
    String? groupId,
  }) {
    return GameActivity(
      gameId: event.gameId,
      gameType: gameType,
      groupId: groupId,
      eventType: event.type,
      actorId: event.actorId,
      metadata: event.payload,
      createdAt: event.createdAt,
    );
  }
}

final class GameRound {
  const GameRound({
    required this.id,
    required this.gameId,
    required this.roundNumber,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.configuration = const <String, dynamic>{},
    this.results = const <String, dynamic>{},
  });

  final String id;
  final String gameId;
  final int roundNumber;
  final GameRoundStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic> configuration;
  final Map<String, dynamic> results;

  GameRound copyWith({
    GameRoundStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    Map<String, dynamic>? results,
  }) => GameRound(
    id: id,
    gameId: gameId,
    roundNumber: roundNumber,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    configuration: configuration,
    results: results ?? this.results,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'roundId': id,
    'gameId': gameId,
    'roundNumber': roundNumber,
    'status': status.name,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'configuration': configuration,
    'results': results,
  };

  factory GameRound.fromMap(Map<String, dynamic> map, {required String id}) {
    return GameRound(
      id: map['roundId'] as String? ?? id,
      gameId: map['gameId'] as String? ?? '',
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 0,
      status: GameRoundStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => GameRoundStatus.pending,
      ),
      startedAt: _date(map['startedAt']),
      endedAt: _date(map['endedAt']),
      configuration: map['configuration'] is Map
          ? Map<String, dynamic>.from(map['configuration'] as Map)
          : const <String, dynamic>{},
      results: map['results'] is Map
          ? Map<String, dynamic>.from(map['results'] as Map)
          : const <String, dynamic>{},
    );
  }
}

final class GameDraft {
  const GameDraft({
    this.gameId,
    this.groupId,
    this.type = GameType.guessCharacter,
    this.title = '',
    this.description = '',
    this.asDraft = false,
    this.configuration = const GameConfiguration(),
  });

  final String? gameId;
  final String? groupId;
  final GameType type;
  final String title;
  final String description;
  final bool asDraft;
  final GameConfiguration configuration;

  GameDraft copyWith({
    String? gameId,
    String? groupId,
    GameType? type,
    String? title,
    String? description,
    bool? asDraft,
    GameConfiguration? configuration,
  }) => GameDraft(
    gameId: gameId ?? this.gameId,
    groupId: groupId ?? this.groupId,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    asDraft: asDraft ?? this.asDraft,
    configuration: configuration ?? this.configuration,
  );

  Map<String, dynamic> toCallableMap() => <String, dynamic>{
    if (gameId != null) 'gameId': gameId,
    if (groupId != null) 'groupId': groupId,
    'type': type.name,
    'title': title,
    'description': description,
    'asDraft': asDraft,
    'configuration': configuration.toMap(),
  };
}

String _eventWireName(GameEventType type) {
  return switch (type) {
    GameEventType.gameCreated => 'game_created',
    GameEventType.playerJoined => 'player_joined',
    GameEventType.playerLeft => 'player_left',
    GameEventType.gameStarted => 'game_started',
    GameEventType.gamePaused => 'game_paused',
    GameEventType.gameResumed => 'game_resumed',
    GameEventType.actionSubmitted => 'action_submitted',
    GameEventType.roundStarted => 'round_started',
    GameEventType.roundCompleted => 'round_completed',
    GameEventType.gameCompleted => 'game_completed',
    GameEventType.gameCancelled => 'game_cancelled',
  };
}

GameEventType parseGameEventType(String? raw) {
  return switch (raw) {
    'game_created' || 'gameCreated' => GameEventType.gameCreated,
    'player_joined' || 'playerJoined' => GameEventType.playerJoined,
    'player_left' || 'playerLeft' => GameEventType.playerLeft,
    'game_started' || 'gameStarted' => GameEventType.gameStarted,
    'game_paused' || 'gamePaused' => GameEventType.gamePaused,
    'game_resumed' || 'gameResumed' => GameEventType.gameResumed,
    'action_submitted' || 'actionSubmitted' => GameEventType.actionSubmitted,
    'round_started' || 'roundStarted' => GameEventType.roundStarted,
    'round_completed' || 'roundCompleted' => GameEventType.roundCompleted,
    'game_completed' || 'gameCompleted' => GameEventType.gameCompleted,
    'game_cancelled' || 'gameCancelled' => GameEventType.gameCancelled,
    _ => GameEventType.gameCreated,
  };
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const <String, int>{};
  final result = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.key is String && entry.value is num) {
      result[entry.key as String] = (entry.value as num).toInt();
    }
  }
  return result;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
