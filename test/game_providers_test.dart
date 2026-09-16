import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/games/providers/game_providers.dart';
import 'package:pubget/features/games/repositories/game_repository.dart';

void main() {
  test('duplicate submit is ignored while a request is in flight', () async {
    final repository = _FakeGameRepository();
    final provider = GameProvider(repository: repository);
    addTearDown(provider.dispose);

    final first = provider.submitAction(gameId: 'g1', actionType: 'guess');
    final second = await provider.submitAction(
      gameId: 'g1',
      actionType: 'guess',
    );
    expect(second, isA<FailureResult<void>>());
    repository.actionCompleter.complete(const Success<void>(null));
    expect((await first).isSuccess, isTrue);
    expect(repository.actionCalls, 1);
  });

  test('join failure is not treated as success', () async {
    final repository = _FakeGameRepository();
    final provider = GameProvider(repository: repository);
    addTearDown(provider.dispose);
    repository.joinResult = const FailureResult(PermissionError());
    final result = await provider.join('g1');
    expect(result, isA<FailureResult<void>>());
    expect(repository.joinCalls, 1);
  });

  test('create is blocked without a group and title', () async {
    final repository = _FakeGameRepository();
    final provider = GameCreateProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.start();
    final result = await provider.create();
    expect(result, isA<FailureResult<PubgetGame>>());
    expect(repository.createCalls, 0);
  });

  test('generic create rejects Mafia drafts', () async {
    final repository = _FakeGameRepository();
    final provider = GameCreateProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.start(groupId: 'g1');
    provider.selectType(GameType.mafia);
    provider.update(provider.draft.copyWith(title: 'Night in the village'));
    final result = await provider.create();
    expect(result, isA<FailureResult<PubgetGame>>());
    expect(repository.createCalls, 0);
  });

  test('bindUser clears private game state for the next account', () async {
    final repository = _FakeGameRepository();
    final provider = GameProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open('g1', userId: 'alice');
    provider.bindUser('bob');
    expect(provider.game, isNull);
    expect(provider.privateState, isEmpty);
  });

  test('list loadHome stays loaded when every bucket is empty', () async {
    final repository = _FakeGameRepository();
    final provider = GameListProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.loadHome();
    expect(provider.state, LoadingState.loaded);
    expect(provider.active, isEmpty);
  });
}

final class _FakeGameRepository implements GameRepository {
  final actionCompleter = Completer<Result<void>>();
  Result<void> joinResult = const Success<void>(null);
  int actionCalls = 0;
  int joinCalls = 0;
  int createCalls = 0;

  @override
  Future<Result<void>> cancel(String gameId) async => const Success<void>(null);

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) async {
    createCalls += 1;
    return FailureResult(ValidationError('unused'));
  }

  @override
  Future<Result<void>> end(String gameId) async => const Success<void>(null);

  @override
  Future<Result<List<PubgetGame>>> getActiveGames({int limit = 20}) async =>
      const Success(<PubgetGame>[]);

  @override
  Future<Result<List<PubgetGame>>> getGroupGames({
    required String groupId,
    int limit = 20,
  }) async => const Success(<PubgetGame>[]);

  @override
  Future<Result<List<PubgetGame>>> getMyGames({
    required String userId,
    int limit = 20,
  }) async => const Success(<PubgetGame>[]);

  @override
  Future<Result<List<GameParticipant>>> getParticipants(String gameId) async =>
      const Success(<GameParticipant>[]);

  @override
  Future<Result<List<PubgetGame>>> getWaitingGames({int limit = 20}) async =>
      const Success(<PubgetGame>[]);

  @override
  Future<Result<void>> initialize(String gameId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> join(String gameId) async {
    joinCalls += 1;
    return joinResult;
  }

  @override
  Future<Result<void>> leave(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> pause(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> resume(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> start(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? clientActionId,
  }) {
    actionCalls += 1;
    return actionCompleter.future;
  }

  @override
  Stream<Result<PubgetGame>> watchGame(String gameId) =>
      const Stream<Result<PubgetGame>>.empty();

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) =>
      const Stream<Result<List<GameParticipant>>>.empty();

  @override
  Stream<Result<Map<String, dynamic>>> watchPrivate({
    required String gameId,
    required String userId,
  }) => const Stream<Result<Map<String, dynamic>>>.empty();
}
