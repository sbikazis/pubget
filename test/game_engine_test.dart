import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/games/engine/game_engine.dart';
import 'package:pubget/features/games/engine/scoring.dart';
import 'package:pubget/features/games/models/game_errors.dart';
import 'package:pubget/features/games/models/game_lifecycle.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';

void main() {
  group('Game status machine', () {
    test('allows the documented transitions', () {
      expect(
        GameLifecycle.canTransition(GameStatus.draft, GameStatus.waiting),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.waiting, GameStatus.active),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.active, GameStatus.paused),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.paused, GameStatus.active),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.active, GameStatus.completed),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.waiting, GameStatus.cancelled),
        isTrue,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.active, GameStatus.cancelled),
        isTrue,
      );
    });

    test('rejects invalid and terminal-state transitions', () {
      expect(
        GameLifecycle.canTransition(GameStatus.draft, GameStatus.active),
        isFalse,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.completed, GameStatus.active),
        isFalse,
      );
      expect(
        GameLifecycle.canTransition(GameStatus.cancelled, GameStatus.waiting),
        isFalse,
      );
      expect(GameLifecycle.isTerminal(GameStatus.completed), isTrue);
      expect(GameLifecycle.isTerminal(GameStatus.cancelled), isTrue);
      expect(GameLifecycle.isTerminal(GameStatus.active), isFalse);
      expect(
        () => GameLifecycle.assertTransition(
          GameStatus.completed,
          GameStatus.active,
        ),
        throwsA(
          isA<GameException>().having(
            (error) => error.code,
            'code',
            GameErrorCode.alreadyCompleted,
          ),
        ),
      );
    });
  });

  group('Game registry', () {
    test('registers known types and looks them up', () {
      expect(GameTypeRegistry.isRegistered(GameType.guessCharacter), isTrue);
      expect(GameTypeRegistry.of(GameType.mafia).implemented, isTrue);
      expect(GameTypeRegistry.of(GameType.animeChain).name, 'Anime Chain');
      expect(GameTypeRegistry.implemented, hasLength(4));
      expect(
        GameTypeRegistry.configurationFor(GameType.guessCharacter).minPlayers,
        2,
      );
      expect(
        GameTypeRegistry.configurationFor(GameType.mafia).minPlayers,
        4,
      );
    });

    test('unknown game type lookup returns null', () {
      expect(GameTypeRegistry.byName('unknownGame'), isNull);
      expect(GameTypeRegistry.byName('mafia')?.implemented, isTrue);
      expect(() => GameEngine.assertCanCreate(GameType.mafia), returnsNormally);
    });
  });

  group('Participants', () {
    test('join, duplicate join, and leave', () {
      final roster = ParticipantRoster(gameId: 'g1');
      final first = roster.join(userId: 'alice', gameStatus: GameStatus.waiting);
      final again = roster.join(userId: 'alice', gameStatus: GameStatus.waiting);
      expect(identical(first, again) || first.userId == again.userId, isTrue);
      expect(roster.activeCount, 1);
      roster.leave(userId: 'alice');
      expect(roster.activeCount, 0);
      expect(roster['alice']!.isActive, isFalse);
    });

    test('rejects join after start and leave of a missing player', () {
      final roster = ParticipantRoster(gameId: 'g1');
      expect(
        () => roster.join(userId: 'bob', gameStatus: GameStatus.active),
        throwsA(
          isA<GameException>().having(
            (error) => error.code,
            'code',
            GameErrorCode.alreadyStarted,
          ),
        ),
      );
      expect(
        () => roster.leave(userId: 'bob'),
        throwsA(
          isA<GameException>().having(
            (error) => error.code,
            'code',
            GameErrorCode.notParticipant,
          ),
        ),
      );
    });
  });

  group('Actions', () {
    test('valid action structure is accepted', () {
      final action = GameEngine.validateAction(
        id: 'a1',
        gameId: 'g1',
        playerId: 'alice',
        actionType: GameActionTypes.guess,
        payload: const <String, dynamic>{'value': 'Luffy'},
        clientActionId: 'client-1',
      );
      expect(action.actionType, 'guess');
      expect(action.payload['value'], 'Luffy');
    });

    test('invalid action is rejected', () {
      expect(
        () => GameEngine.validateAction(
          id: 'a1',
          gameId: '',
          playerId: 'alice',
          actionType: 'guess',
          payload: const <String, dynamic>{},
        ),
        throwsA(
          isA<GameException>().having(
            (error) => error.code,
            'code',
            GameErrorCode.invalidAction,
          ),
        ),
      );
    });

    test('idempotent clientActionId returns the original action', () {
      final roster = ParticipantRoster(gameId: 'g1');
      roster.join(userId: 'alice', gameStatus: GameStatus.waiting);
      final log = ActionLog();
      final first = GameEngine.validateAction(
        id: 'a1',
        gameId: 'g1',
        playerId: 'alice',
        actionType: 'submit',
        payload: const <String, dynamic>{'n': 1},
        clientActionId: 'idem-1',
      );
      final second = GameEngine.validateAction(
        id: 'a2',
        gameId: 'g1',
        playerId: 'alice',
        actionType: 'submit',
        payload: const <String, dynamic>{'n': 2},
        clientActionId: 'idem-1',
      );
      expect(
        log.submit(
          action: first,
          gameStatus: GameStatus.active,
          roster: roster,
        ).id,
        'a1',
      );
      expect(
        log.submit(
          action: second,
          gameStatus: GameStatus.active,
          roster: roster,
        ).id,
        'a1',
      );
      expect(log.all, hasLength(1));
    });
  });

  group('Rounds', () {
    test('creates rounds in order and runs the lifecycle', () {
      final rounds = RoundSequence();
      final first = rounds.create(gameId: 'g1', roundNumber: 1);
      expect(first.status, GameRoundStatus.pending);
      expect(
        () => rounds.create(gameId: 'g1', roundNumber: 3),
        throwsA(isA<GameException>()),
      );
      rounds.create(gameId: 'g1', roundNumber: 2);
      expect(rounds.ordered.map((round) => round.roundNumber), [1, 2]);
      rounds.start(1);
      expect(rounds.ordered.first.status, GameRoundStatus.active);
      rounds.complete(1, results: const <String, dynamic>{'winner': 'alice'});
      expect(rounds.ordered.first.status, GameRoundStatus.completed);
      expect(rounds.ordered.first.results['winner'], 'alice');
    });
  });

  group('Scoring', () {
    test('generic contract uses the no-op strategy by default', () {
      final game = PubgetGame(
        id: 'g1',
        type: GameType.guessCharacter,
        title: 'Guess',
        description: '',
        version: 1,
        status: GameStatus.active,
        creatorId: 'alice',
        configuration: const GameConfiguration(),
        participantsCount: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );
      final action = GameEngine.validateAction(
        id: 'a1',
        gameId: 'g1',
        playerId: 'alice',
        actionType: 'guess',
        payload: const <String, dynamic>{},
      );
      expect(ScoringStrategyRegistry.forType(game.type), isA<NoOpScoringStrategy>());
      expect(GameEngine.scoreAction(action: action, game: game), 0);
    });
  });

  group('Game events', () {
    test('create, serialize, and decode with version defaults', () {
      final event = GameEventFactory.create(
        id: 'e1',
        gameId: 'g1',
        type: GameEventType.playerJoined,
        actorId: 'alice',
        createdAt: DateTime.utc(2026, 9, 1),
        payload: const <String, dynamic>{'seat': 1},
      );
      final map = event.toMap();
      expect(map['type'], 'player_joined');
      expect(map['schemaVersion'], 1);
      final restored = GameEventFactory.decode(map, id: 'e1');
      expect(restored.type, GameEventType.playerJoined);
      expect(restored.payload['seat'], 1);
      final legacy = GameEventFactory.decode(const <String, dynamic>{
        'gameId': 'g1',
        'type': 'game_started',
        'actorId': 'alice',
        'futureField': 'ignored',
      }, id: 'legacy');
      expect(legacy.schemaVersion, 1);
      expect(legacy.type, GameEventType.gameStarted);
      final activity = GameActivity.fromEvent(
        event: restored,
        gameType: GameType.guessCharacter,
        groupId: 'group-1',
      );
      expect(activity.toMap()['eventType'], 'player_joined');
      expect(activity.toMap()['groupId'], 'group-1');
    });
  });
}
