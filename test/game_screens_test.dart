import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';
import 'package:pubget/features/games/providers/game_providers.dart';
import 'package:pubget/features/games/repositories/game_repository.dart';
import 'package:pubget/features/games/screens/game_details_screen.dart';
import 'package:pubget/features/games/screens/game_list_screen.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('game list shows empty copy when there are no games', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeGameRepository();
    final list = GameListProvider(repository: repository);
    addTearDown(list.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GameListProvider>.value(value: list),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: GameListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(GameStrings.noGamesTitle), findsWidgets);
  });

  testWidgets('game details shows a missing-game empty state', (tester) async {
    final auth = await _auth();
    final repository = _FakeGameRepository();
    final games = GameProvider(repository: repository);
    addTearDown(games.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GameProvider>.value(value: games),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: GameDetailsScreen(gameId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(GameStrings.missing), findsWidgets);
    expect(find.byType(PubgetEmptyState), findsOneWidget);
  });
}

Future<AuthProvider> _auth() async {
  final repository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: repository);
  await auth.initialize();
  return auth;
}

final class _FakeGameRepository implements GameRepository {
  @override
  Future<Result<void>> cancel(String gameId) async => const Success<void>(null);

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) async =>
      FailureResult(UnknownError('unused'));

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
  Future<Result<void>> join(String gameId) async => const Success<void>(null);

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
  }) async => const Success<void>(null);

  @override
  Stream<Result<PubgetGame>> watchGame(String gameId) =>
      Stream<Result<PubgetGame>>.value(
        const FailureResult(NotFoundError('This game no longer exists.')),
      );

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) =>
      Stream<Result<List<GameParticipant>>>.value(
        const Success(<GameParticipant>[]),
      );
}

final class _FakeGroupRepository implements GroupRepository {
  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async =>
      FailureResult(UnknownError('unused'));

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async =>
      FailureResult(UnknownError('unused'));

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => const Success<GroupMember?>(null);

  @override
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> leaveGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> requestToJoin({required String groupId}) async =>
      const Success<void>(null);

  @override
  Future<Result<List<Group>>> searchGroups(String query) async =>
      const Success(<Group>[]);
}
