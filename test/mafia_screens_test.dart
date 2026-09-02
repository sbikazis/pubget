import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/games/mafia/mafia_game_screen.dart';
import 'package:pubget/features/games/mafia/mafia_models.dart';
import 'package:pubget/features/games/mafia/mafia_provider.dart';
import 'package:pubget/features/games/mafia/mafia_repository.dart';
import 'package:pubget/features/games/mafia/mafia_roles.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';
import 'package:pubget/features/games/providers/game_providers.dart';
import 'package:pubget/features/games/repositories/game_repository.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('mafia lobby shows participants without a public role map', (
    tester,
  ) async {
    final auth = await _auth();
    final gamesRepo = _FakeGameRepository(
      game: _mafiaGame(status: GameStatus.waiting),
      participants: const [
        GameParticipant(
          gameId: 'm1',
          userId: 'alice',
          status: ParticipantStatus.active,
          displayName: 'Alice',
        ),
        GameParticipant(
          gameId: 'm1',
          userId: 'bob',
          status: ParticipantStatus.active,
          displayName: 'Bob',
        ),
      ],
    );
    final mafiaRepo = _FakeMafiaRepository();
    final games = GameProvider(repository: gamesRepo);
    final mafia = MafiaProvider(repository: mafiaRepo);
    final network = NetworkService(probe: () async => true);
    await network.refresh();
    addTearDown(games.dispose);
    addTearDown(mafia.dispose);
    addTearDown(auth.dispose);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GameProvider>.value(value: games),
          ChangeNotifierProvider<MafiaProvider>.value(value: mafia),
          ChangeNotifierProvider<NetworkService>.value(value: network),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: MafiaGameScreen(gameId: 'm1')),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Nightfall'), findsWidgets);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('mafia'), findsNothing);
    expect(find.text(GameStrings.start), findsOneWidget);
  });

  testWidgets('night UI shows the current user role and hides others', (
    tester,
  ) async {
    final auth = await _auth();
    final gamesRepo = _FakeGameRepository(
      game: _mafiaGame(
        status: GameStatus.active,
        mafia: const {
          'phase': 'night',
          'roundNumber': 1,
          'deadUserIds': <String>[],
        },
      ),
      participants: const [
        GameParticipant(
          gameId: 'm1',
          userId: 'alice',
          status: ParticipantStatus.active,
          displayName: 'Alice',
        ),
        GameParticipant(
          gameId: 'm1',
          userId: 'bob',
          status: ParticipantStatus.active,
          displayName: 'Bob',
        ),
      ],
    );
    final mafiaRepo = _FakeMafiaRepository(
      privateState: const MafiaPrivateState(
        role: MafiaRole.detective,
        investigation: {'roundNumber': 1, 'targetId': 'bob', 'isMafia': false},
      ),
    );
    final games = GameProvider(repository: gamesRepo);
    final mafia = MafiaProvider(repository: mafiaRepo);
    final network = NetworkService(probe: () async => true);
    await network.refresh();
    addTearDown(games.dispose);
    addTearDown(mafia.dispose);
    addTearDown(auth.dispose);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GameProvider>.value(value: games),
          ChangeNotifierProvider<MafiaProvider>.value(value: mafia),
          ChangeNotifierProvider<NetworkService>.value(value: network),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: MafiaGameScreen(gameId: 'm1')),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('detective'), findsOneWidget);
    expect(find.text('Investigation: that player is not Mafia.'), findsOneWidget);
    expect(find.text('doctor'), findsNothing);
    expect(find.text(GameStrings.investigate), findsWidgets);
  });
}

PubgetGame _mafiaGame({
  required GameStatus status,
  Map<String, dynamic>? mafia,
}) {
  return PubgetGame(
    id: 'm1',
    type: GameType.mafia,
    title: 'Nightfall',
    description: '',
    version: 1,
    status: status,
    creatorId: 'alice',
    groupId: 'g1',
    configuration: const GameConfiguration(minPlayers: 4, maxPlayers: 16),
    participantsCount: 2,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    mafia: mafia ??
        const {
          'phase': 'setup',
          'roundNumber': 0,
          'deadUserIds': <String>[],
        },
  );
}

Future<AuthProvider> _auth() async {
  final repository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: repository);
  await auth.initialize();
  return auth;
}

final class _FakeMafiaRepository implements MafiaRepository {
  _FakeMafiaRepository({this.privateState});

  final MafiaPrivateState? privateState;

  @override
  GameRepository get games => throw UnimplementedError();

  @override
  Future<Result<void>> advancePhase(String gameId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> submitMafiaAction({
    required String gameId,
    required String type,
    String? targetId,
    String? clientRequestId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> vote({
    required String gameId,
    required String targetId,
    String? clientRequestId,
  }) async => const Success<void>(null);

  @override
  Stream<Result<MafiaPrivateState?>> watchPrivateState({
    required String gameId,
    required String userId,
  }) {
    return Stream<Result<MafiaPrivateState?>>.value(Success(privateState));
  }
}

final class _FakeGameRepository implements GameRepository {
  _FakeGameRepository({required this.game, required this.participants});

  final PubgetGame game;
  final List<GameParticipant> participants;

  @override
  Future<Result<void>> cancel(String gameId) async => const Success<void>(null);

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) async => Success(game);

  @override
  Future<Result<void>> end(String gameId) async => const Success<void>(null);

  @override
  Future<Result<List<PubgetGame>>> getActiveGames({int limit = 20}) async =>
      Success([game]);

  @override
  Future<Result<List<PubgetGame>>> getGroupGames({
    required String groupId,
    int limit = 20,
  }) async => Success([game]);

  @override
  Future<Result<List<PubgetGame>>> getMyGames({
    required String userId,
    int limit = 20,
  }) async => Success([game]);

  @override
  Future<Result<List<GameParticipant>>> getParticipants(String gameId) async =>
      Success(participants);

  @override
  Future<Result<List<PubgetGame>>> getWaitingGames({int limit = 20}) async =>
      Success([game]);

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
      Stream<Result<PubgetGame>>.value(Success(game));

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) =>
      Stream<Result<List<GameParticipant>>>.value(Success(participants));
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
