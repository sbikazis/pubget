import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/games/models/game_errors.dart';
import 'package:pubget/features/games/models/games_schema_v2.dart';
import 'package:pubget/features/games/models/games_state_machine_v2.dart';
import 'package:pubget/features/games/providers/games_session_provider_v2.dart';
import 'package:pubget/features/games/repositories/games_repository_v2.dart';

void main() {
  test('decodes schema v2 session and snake-case status', () {
    final session = GameSessionV2.fromMap({
      'groupId': 'group-1',
      'type': 'emoji_anime_guess',
      'status': 'in_progress',
      'creatorId': 'u1',
      'version': 4,
      'players': [
        {'userId': 'u1', 'score': 2, 'connected': true},
      ],
    }, id: 'game-1');
    expect(session.type, GameTypeV2.emojiAnimeGuess);
    expect(session.status, GameLifecycleStatusV2.inProgress);
    expect(session.players.single.score, 2);
  });

  test('state machine rejects terminal and skips waiting to in-progress', () {
    expect(
      GamesStateMachineV2.canTransition(
        GameLifecycleStatusV2.completed,
        GameLifecycleStatusV2.waiting,
      ),
      isFalse,
    );
    expect(
      () => GamesStateMachineV2.assertTransition(
        GameLifecycleStatusV2.waiting,
        GameLifecycleStatusV2.inProgress,
      ),
      throwsA(isA<GameException>()),
    );
  });

  test(
    'session provider ignores late emissions from replaced session',
    () async {
      final repository = _FakeV2Repository();
      final provider = GamesSessionProviderV2(repository);
      addTearDown(provider.dispose);
      await provider.open('one');
      final first = repository.controllers['one']!;
      await provider.open('two');
      first.add(Success(_session('one')));
      repository.controllers['two']!.add(Success(_session('two')));
      await Future<void>.delayed(Duration.zero);
      expect(provider.session?.id, 'two');
      expect(provider.reconnectRoute, GameReconnectRoute.waitingRoom);
    },
  );

  test('reconnect route follows server lifecycle', () {
    expect(
      routeForSession(_session('x', GameLifecycleStatusV2.inProgress)),
      GameReconnectRoute.gameRoom,
    );
    expect(
      routeForSession(_session('x', GameLifecycleStatusV2.completed)),
      GameReconnectRoute.result,
    );
  });

  test('history page exposes cursor for pagination', () {
    const page = GameHistoryPage(games: [], nextCursor: 'next');
    expect(page.hasMore, isTrue);
  });

  test('debounced search canonicalizes and only calls latest query', () async {
    final queries = <String>[];
    final search = DebouncedCanonicalSearch<String>(
      delay: const Duration(milliseconds: 10),
      lookup: (query) async {
        queries.add(query);
        return [query];
      },
    );
    addTearDown(search.dispose);
    search.search('  Naruto   Shippuden ');
    final current = search.search(' One   Piece ');
    expect(await current, ['one piece']);
    expect(queries, ['one piece']);
    // Cancelled timers must not invoke the stale lookup.
  });
}

GameSessionV2 _session(
  String id, [
  GameLifecycleStatusV2 status = GameLifecycleStatusV2.waiting,
]) => GameSessionV2(
  id: id,
  groupId: 'group',
  type: GameTypeV2.animeChain,
  status: status,
  creatorId: 'creator',
  version: 1,
  players: const [],
);

final class _FakeV2Repository implements GamesRepositoryV2 {
  final controllers = <String, StreamController<Result<GameSessionV2>>>{};

  @override
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> command(GameCommandRequest request) =>
      Future.value(const Success<void>(null));

  @override
  Future<Result<GameHistoryPage>> groupHistory({
    required String groupId,
    String? cursor,
    int limit = 20,
  }) => Future.value(const Success(GameHistoryPage(games: [])));

  @override
  Stream<Result<GameSessionV2>> watchSession(String gameId) {
    final controller = StreamController<Result<GameSessionV2>>();
    controllers[gameId] = controller;
    return controller.stream;
  }

  @override
  Stream<Result<Map<String, dynamic>>> watchPrivateState({
    required String gameId,
    required String userId,
  }) => const Stream.empty();
}
