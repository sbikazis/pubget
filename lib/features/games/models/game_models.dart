import 'package:cloud_firestore/cloud_firestore.dart';

enum GameType { guessCharacter, animeChain, emojiAnimeGuess, mafia }

/// Master Spec 12.2: CREATED → WAITING → STARTING → IN_PROGRESS → COMPLETED /
/// CANCELLED. There is no paused state — a game cannot be suspended and picked
/// up later, so there is nothing to resume.
///
/// The wire names are uppercase and are parsed case-insensitively. The previous
/// lowercase names (`draft`, `active`, `paused`) matched no document the server
/// ever wrote, so every game parsed as `draft`: nothing was joinable, playable,
/// or terminal in the live app.
enum GameStatus { created, waiting, starting, inProgress, completed, cancelled }

extension GameStatusWire on GameStatus {
  String get wireName => switch (this) {
    GameStatus.created => 'CREATED',
    GameStatus.waiting => 'WAITING',
    GameStatus.starting => 'STARTING',
    GameStatus.inProgress => 'IN_PROGRESS',
    GameStatus.completed => 'COMPLETED',
    GameStatus.cancelled => 'CANCELLED',
  };

  static GameStatus parse(Object? raw) {
    if (raw is GameStatus) return raw;
    final key = raw is String ? raw.trim().toUpperCase() : '';
    for (final status in GameStatus.values) {
      if (status.wireName == key) return status;
    }
    return GameStatus.created;
  }
}

enum ParticipantStatus { active, left }

enum GameRoundStatus { pending, active, completed }

enum GameEventType {
  gameCreated,
  playerJoined,
  playerLeft,
  gameStarted,
  actionSubmitted,
  roundStarted,
  roundCompleted,
  gameCompleted,
  gameCancelled,
  mafiaGameStarted,
  mafiaNightStarted,
  mafiaNightResolved,
  mafiaDayStarted,
  mafiaVotingStarted,
  mafiaVoteResolved,
  mafiaPlayerEliminated,
  mafiaGameCompleted,
}

/// Generic action type names. Meaning belongs to the specific game.
abstract final class GameActionTypes {
  static const guess = 'guess';
  static const select = 'select';
  static const vote = 'vote';
  static const choose = 'choose';
  static const submit = 'submit';
  static const pass = 'pass';
  // Guess Character asks and answers in fixed turns rather than scoring a
  // prompt, so these two names are part of the engine contract.
  static const ask = 'ask';
  static const answer = 'answer';
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
      roundCount:
          (map['roundCount'] as num?)?.toInt() ??
          (extra['roundCount'] as num?)?.toInt() ??
          5,
      timerSeconds:
          (map['timerSeconds'] as num?)?.toInt() ??
          (extra['timerSeconds'] as num?)?.toInt() ??
          20,
      difficulty:
          map['difficulty'] as String? ??
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
  bool get isPlayable =>
      status == GameStatus.starting || status == GameStatus.inProgress;
  bool get isTerminal =>
      status == GameStatus.completed || status == GameStatus.cancelled;
  bool get isHistorical => isTerminal;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type.name,
    'title': title,
    'description': description,
    'version': version,
    'status': status.wireName,
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
      status: GameStatusWire.parse(map['status']),
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
    this.isAlive = true,
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
  final bool isAlive;

  bool get isActive => status == ParticipantStatus.active && leftAt == null;

  GameParticipant copyWith({
    ParticipantStatus? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    int? score,
    Map<String, dynamic>? metadata,
    bool? isAlive,
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
    isAlive: isAlive ?? this.isAlive,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'gameId': gameId,
    'userId': userId,
    'status': status.name,
    'displayName': displayName,
    'joinedAt': joinedAt?.toUtc().toIso8601String(),
    'leftAt': leftAt?.toUtc().toIso8601String(),
    if (score != null) 'score': score,
    'isAlive': isAlive,
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
      isAlive: map['isAlive'] != false,
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
    this.creationSource = 'unknown',
  });

  final String? gameId;
  final String? groupId;
  final GameType type;
  final String title;
  final String description;
  final bool asDraft;
  final GameConfiguration configuration;
  final String creationSource;

  GameDraft copyWith({
    String? gameId,
    String? groupId,
    GameType? type,
    String? title,
    String? description,
    bool? asDraft,
    GameConfiguration? configuration,
    String? creationSource,
  }) => GameDraft(
    gameId: gameId ?? this.gameId,
    groupId: groupId ?? this.groupId,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    asDraft: asDraft ?? this.asDraft,
    configuration: configuration ?? this.configuration,
    creationSource: creationSource ?? this.creationSource,
  );

  Map<String, dynamic> toCallableMap() => <String, dynamic>{
    if (gameId != null) 'gameId': gameId,
    if (groupId != null) 'groupId': groupId,
    'type': type.name,
    'title': title,
    'description': description,
    'asDraft': asDraft,
    'configuration': configuration.toMap(),
    'creationSource': creationSource,
  };
}

String _eventWireName(GameEventType type) {
  return switch (type) {
    GameEventType.gameCreated => 'game_created',
    GameEventType.playerJoined => 'player_joined',
    GameEventType.playerLeft => 'player_left',
    GameEventType.gameStarted => 'game_started',
    GameEventType.actionSubmitted => 'action_submitted',
    GameEventType.roundStarted => 'round_started',
    GameEventType.roundCompleted => 'round_completed',
    GameEventType.gameCompleted => 'game_completed',
    GameEventType.gameCancelled => 'game_cancelled',
    GameEventType.mafiaGameStarted => 'mafia_game_started',
    GameEventType.mafiaNightStarted => 'mafia_night_started',
    GameEventType.mafiaNightResolved => 'mafia_night_resolved',
    GameEventType.mafiaDayStarted => 'mafia_day_started',
    GameEventType.mafiaVotingStarted => 'mafia_voting_started',
    GameEventType.mafiaVoteResolved => 'mafia_vote_resolved',
    GameEventType.mafiaPlayerEliminated => 'mafia_player_eliminated',
    GameEventType.mafiaGameCompleted => 'mafia_game_completed',
  };
}

GameEventType parseGameEventType(String? raw) {
  return switch (raw) {
    'game_created' || 'gameCreated' => GameEventType.gameCreated,
    'player_joined' || 'playerJoined' => GameEventType.playerJoined,
    'player_left' || 'playerLeft' => GameEventType.playerLeft,
    'game_started' || 'gameStarted' => GameEventType.gameStarted,
    'action_submitted' || 'actionSubmitted' => GameEventType.actionSubmitted,
    'round_started' || 'roundStarted' => GameEventType.roundStarted,
    'round_completed' || 'roundCompleted' => GameEventType.roundCompleted,
    'game_completed' || 'gameCompleted' => GameEventType.gameCompleted,
    'game_cancelled' || 'gameCancelled' => GameEventType.gameCancelled,
    'mafia_game_started' => GameEventType.mafiaGameStarted,
    'mafia_night_started' => GameEventType.mafiaNightStarted,
    'mafia_night_resolved' => GameEventType.mafiaNightResolved,
    'mafia_day_started' => GameEventType.mafiaDayStarted,
    'mafia_voting_started' => GameEventType.mafiaVotingStarted,
    'mafia_vote_resolved' => GameEventType.mafiaVoteResolved,
    'mafia_player_eliminated' => GameEventType.mafiaPlayerEliminated,
    'mafia_game_completed' => GameEventType.mafiaGameCompleted,
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

/// A catalog search hit from `searchAnimeCatalog`. The server owns IDs, so the
/// client stores them verbatim and never invents its own.
final class AnimeSearchItem {
  const AnimeSearchItem({
    required this.id,
    required this.title,
    this.alternativeTitles = const <String>[],
    this.imageUrl = '',
    this.year,
    this.type,
    this.genres = const <String>[],
    this.studios = const <String>[],
  });

  final String id;
  final String title;
  final List<String> alternativeTitles;
  final String imageUrl;
  final int? year;
  final String? type;
  final List<String> genres;
  final List<String> studios;

  factory AnimeSearchItem.fromMap(Map<String, dynamic> map) => AnimeSearchItem(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    alternativeTitles:
        (map['alternativeTitles'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList(),
    imageUrl: map['imageUrl'] as String? ?? '',
    year: (map['year'] as num?)?.toInt(),
    type: map['type'] as String?,
    genres: (map['genres'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .toList(),
    studios: (map['studios'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .toList(),
  );
}

/// A catalog search hit from `searchCharacterCatalog`. Guess Character only
/// accepts these real IDs, never a typed name.
final class CharacterSearchItem {
  const CharacterSearchItem({
    required this.id,
    required this.name,
    this.animeIds = const <String>[],
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final List<String> animeIds;
  final String imageUrl;

  factory CharacterSearchItem.fromMap(Map<String, dynamic> map) =>
      CharacterSearchItem(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        animeIds: (map['animeIds'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList(),
        imageUrl: map['imageUrl'] as String? ?? '',
      );
}

/// A finished game from the server-written `game_history` collection, used by
/// the Game Center Recent and History sections.
final class GameHistoryEntry {
  const GameHistoryEntry({
    required this.gameId,
    required this.type,
    this.groupId,
    this.participants = const <String>[],
    this.result,
    this.endedAt,
  });

  final String gameId;
  final String type;
  final String? groupId;
  final List<String> participants;
  final GameResult? result;
  final DateTime? endedAt;

  factory GameHistoryEntry.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final raw = map['result'];
    return GameHistoryEntry(
      gameId: map['gameId'] as String? ?? id,
      type: map['type'] as String? ?? '',
      groupId: map['groupId'] as String?,
      participants: (map['participants'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(),
      result: raw is Map
          ? GameResult.fromMap(Map<String, dynamic>.from(raw))
          : null,
      endedAt: _date(map['endedAt']),
    );
  }
}
