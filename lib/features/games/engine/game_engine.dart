import '../models/game_errors.dart';
import '../models/game_lifecycle.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import 'scoring.dart';

/// In-memory helpers for generic lifecycle, participants, actions, rounds,
/// and events. The Firebase Functions engine is authoritative for persisted
/// state; this class keeps client validation and unit tests aligned.
///
/// Game-specific rules (roles, voting, win conditions) must not live here.
abstract final class GameEngine {
  static GameStatus initialize(GameStatus status) {
    GameLifecycle.assertTransition(status, GameStatus.waiting);
    return GameStatus.waiting;
  }

  static GameStatus start({
    required GameStatus status,
    required int participantsCount,
    required GameConfiguration configuration,
  }) {
    if (status == GameStatus.active) {
      return GameStatus.active;
    }
    GameLifecycle.assertTransition(status, GameStatus.active);
    if (participantsCount < configuration.minPlayers) {
      throw const GameException(
        GameErrorCode.invalidTransition,
        'Not enough players to start.',
      );
    }
    return GameStatus.active;
  }

  static GameStatus pause(GameStatus status) {
    if (status == GameStatus.paused) return GameStatus.paused;
    GameLifecycle.assertTransition(status, GameStatus.paused);
    return GameStatus.paused;
  }

  static GameStatus resume(GameStatus status) {
    if (status == GameStatus.active) return GameStatus.active;
    GameLifecycle.assertTransition(status, GameStatus.active);
    return GameStatus.active;
  }

  static GameStatus end(GameStatus status) {
    if (status == GameStatus.completed) return GameStatus.completed;
    GameLifecycle.assertTransition(status, GameStatus.completed);
    return GameStatus.completed;
  }

  static GameStatus cancel(GameStatus status) {
    if (status == GameStatus.cancelled) return GameStatus.cancelled;
    GameLifecycle.assertTransition(status, GameStatus.cancelled);
    return GameStatus.cancelled;
  }

  static void assertCanCreate(GameType type) {
    final spec = GameTypeRegistry.tryOf(type);
    if (spec == null) {
      throw const GameException(
        GameErrorCode.unimplementedType,
        'Unknown game type.',
      );
    }
    if (!spec.implemented) {
      throw const GameException(
        GameErrorCode.unimplementedType,
        GameStrings.comingSoon,
      );
    }
  }

  static GameAction validateAction({
    required String id,
    required String gameId,
    required String playerId,
    required String actionType,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
    String? clientActionId,
  }) {
    final error = GameValidation.action(
      gameId: gameId,
      playerId: playerId,
      actionType: actionType,
      payload: payload,
      clientActionId: clientActionId,
    );
    if (error != null) {
      throw GameException(GameErrorCode.invalidAction, error);
    }
    return GameAction(
      id: id,
      gameId: gameId,
      playerId: playerId,
      actionType: actionType.trim(),
      payload: payload,
      createdAt: createdAt,
      clientActionId: clientActionId,
    );
  }

  static int scoreAction({
    required GameAction action,
    required PubgetGame game,
    ScoringStrategy? strategy,
  }) {
    final selected = strategy ?? ScoringStrategyRegistry.forType(game.type);
    return selected.scoreFor(action: action, game: game);
  }
}

final class ParticipantRoster {
  ParticipantRoster({
    required this.gameId,
    Map<String, GameParticipant>? participants,
  }) : _participants = Map<String, GameParticipant>.from(participants ?? {});

  final String gameId;
  final Map<String, GameParticipant> _participants;

  List<GameParticipant> get all =>
      _participants.values.toList(growable: false);
  List<GameParticipant> get active =>
      all.where((item) => item.isActive).toList(growable: false);
  int get activeCount => active.length;

  GameParticipant? operator [](String userId) => _participants[userId];

  /// Idempotent join: an already-active participant is returned unchanged.
  GameParticipant join({
    required String userId,
    required GameStatus gameStatus,
    String displayName = '',
    DateTime? at,
    int? maxPlayers,
  }) {
    if (gameStatus == GameStatus.active ||
        gameStatus == GameStatus.paused ||
        GameLifecycle.isTerminal(gameStatus)) {
      throw GameException(
        gameStatus == GameStatus.active || gameStatus == GameStatus.paused
            ? GameErrorCode.alreadyStarted
            : GameErrorCode.notJoinable,
        GameStrings.notJoinable,
      );
    }
    if (gameStatus != GameStatus.waiting && gameStatus != GameStatus.draft) {
      throw const GameException(
        GameErrorCode.notJoinable,
        GameStrings.notJoinable,
      );
    }
    final existing = _participants[userId];
    if (existing != null && existing.isActive) {
      return existing;
    }
    if (maxPlayers != null && activeCount >= maxPlayers && existing == null) {
      throw const GameException(
        GameErrorCode.notJoinable,
        'This game is full.',
      );
    }
    final joined = GameParticipant(
      gameId: gameId,
      userId: userId,
      status: ParticipantStatus.active,
      displayName: displayName.isEmpty ? userId : displayName,
      joinedAt: at ?? DateTime.now().toUtc(),
    );
    _participants[userId] = joined;
    return joined;
  }

  GameParticipant leave({
    required String userId,
    DateTime? at,
  }) {
    final existing = _participants[userId];
    if (existing == null) {
      throw const GameException(
        GameErrorCode.notParticipant,
        GameStrings.notParticipant,
      );
    }
    if (!existing.isActive) return existing;
    final left = existing.copyWith(
      status: ParticipantStatus.left,
      leftAt: at ?? DateTime.now().toUtc(),
    );
    _participants[userId] = left;
    return left;
  }

  void assertParticipant(String userId) {
    final existing = _participants[userId];
    if (existing == null || !existing.isActive) {
      throw const GameException(
        GameErrorCode.notParticipant,
        GameStrings.notParticipant,
      );
    }
  }
}

final class ActionLog {
  ActionLog({Map<String, GameAction>? actions})
    : _actions = Map<String, GameAction>.from(actions ?? {}),
      _byClientId = {
        for (final action in (actions ?? const <String, GameAction>{}).values)
          if (action.clientActionId != null) action.clientActionId!: action,
      };

  final Map<String, GameAction> _actions;
  final Map<String, GameAction> _byClientId;

  List<GameAction> get all => _actions.values.toList(growable: false);

  GameAction submit({
    required GameAction action,
    required GameStatus gameStatus,
    required ParticipantRoster roster,
  }) {
    if (gameStatus != GameStatus.active) {
      throw GameException(
        GameLifecycle.isTerminal(gameStatus)
            ? GameErrorCode.alreadyCompleted
            : GameErrorCode.invalidAction,
        'Actions can only be submitted while the game is active.',
      );
    }
    roster.assertParticipant(action.playerId);
    final clientId = action.clientActionId;
    if (clientId != null && _byClientId.containsKey(clientId)) {
      return _byClientId[clientId]!;
    }
    if (_actions.containsKey(action.id)) {
      throw GameException(
        GameErrorCode.duplicateAction,
        'Action ${action.id} was already submitted.',
      );
    }
    _actions[action.id] = action;
    if (clientId != null) _byClientId[clientId] = action;
    return action;
  }
}

final class RoundSequence {
  RoundSequence({List<GameRound>? rounds})
    : _rounds = [...?rounds]..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

  final List<GameRound> _rounds;

  List<GameRound> get ordered => List<GameRound>.unmodifiable(_rounds);

  GameRound create({
    required String gameId,
    required int roundNumber,
    Map<String, dynamic> configuration = const <String, dynamic>{},
  }) {
    if (roundNumber < 1) {
      throw const GameException(
        GameErrorCode.invalidAction,
        'roundNumber must be at least 1.',
      );
    }
    if (_rounds.any((round) => round.roundNumber == roundNumber)) {
      throw const GameException(
        GameErrorCode.duplicateAction,
        'That round already exists.',
      );
    }
    if (_rounds.isNotEmpty && roundNumber != _rounds.last.roundNumber + 1) {
      throw const GameException(
        GameErrorCode.invalidAction,
        'Rounds must be created in order.',
      );
    }
    final round = GameRound(
      id: 'round-$roundNumber',
      gameId: gameId,
      roundNumber: roundNumber,
      status: GameRoundStatus.pending,
      configuration: configuration,
    );
    _rounds.add(round);
    return round;
  }

  GameRound start(int roundNumber, {DateTime? at}) {
    final index = _indexOf(roundNumber);
    final current = _rounds[index];
    if (current.status == GameRoundStatus.active) return current;
    if (current.status != GameRoundStatus.pending) {
      throw const GameException(
        GameErrorCode.invalidTransition,
        'Only a pending round can start.',
      );
    }
    final next = current.copyWith(
      status: GameRoundStatus.active,
      startedAt: at ?? DateTime.now().toUtc(),
    );
    _rounds[index] = next;
    return next;
  }

  GameRound complete(
    int roundNumber, {
    DateTime? at,
    Map<String, dynamic> results = const <String, dynamic>{},
  }) {
    final index = _indexOf(roundNumber);
    final current = _rounds[index];
    if (current.status == GameRoundStatus.completed) return current;
    if (current.status != GameRoundStatus.active) {
      throw const GameException(
        GameErrorCode.invalidTransition,
        'Only an active round can complete.',
      );
    }
    final next = current.copyWith(
      status: GameRoundStatus.completed,
      endedAt: at ?? DateTime.now().toUtc(),
      results: results,
    );
    _rounds[index] = next;
    return next;
  }

  int _indexOf(int roundNumber) {
    final index = _rounds.indexWhere((round) => round.roundNumber == roundNumber);
    if (index < 0) {
      throw const GameException(GameErrorCode.notFound, 'Round not found.');
    }
    return index;
  }
}

abstract final class GameEventFactory {
  static const schemaVersion = 1;

  static GameEvent create({
    required String id,
    required String gameId,
    required GameEventType type,
    required String actorId,
    DateTime? createdAt,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return GameEvent(
      id: id,
      gameId: gameId,
      type: type,
      actorId: actorId,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      payload: payload,
      schemaVersion: schemaVersion,
    );
  }

  /// Unknown future fields are ignored; missing schemaVersion defaults to 1.
  static GameEvent decode(Map<String, dynamic> map, {required String id}) {
    return GameEvent.fromMap(map, id: id);
  }
}
