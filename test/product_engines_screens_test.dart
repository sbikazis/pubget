import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/analytics/analytics.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/achievements/data/achievement_catalog.dart';
import 'package:pubget/features/achievements/models/achievement_models.dart';
import 'package:pubget/features/achievements/providers/achievement_provider.dart';
import 'package:pubget/features/achievements/repositories/achievement_repository.dart';
import 'package:pubget/features/achievements/screens/achievements_page.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/models/event_type_registry.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';
import 'package:pubget/features/events/screens/event_details_screen.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';
import 'package:pubget/features/games/providers/game_providers.dart';
import 'package:pubget/features/games/repositories/game_repository.dart';
import 'package:pubget/features/games/screens/game_create_page.dart';
import 'package:pubget/features/games/screens/game_details_screen.dart';
import 'package:pubget/features/games/widgets/game_play_panels.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/mafia/models/mafia_leave_copy.dart';
import 'package:pubget/features/mafia/models/mafia_models.dart';
import 'package:pubget/features/mafia/providers/mafia_provider.dart';
import 'package:pubget/features/mafia/repositories/mafia_repository.dart';
import 'package:pubget/features/mafia/screens/mafia_game_screen.dart';

import 'authentication_test_support.dart';

void main() {
  test('mafia leave copy matches server-supported statuses only', () {
    expect(MafiaLeaveCopy.canLeave('waiting'), isFalse);
    expect(MafiaLeaveCopy.canLeave('starting'), isTrue);
    expect(MafiaLeaveCopy.canLeave('night'), isTrue);
    expect(MafiaLeaveCopy.canLeave('execution'), isFalse);
    expect(MafiaLeaveCopy.bodyFor('night'), contains('eliminated'));
    expect(MafiaLeaveCopy.bodyFor('starting'), contains('cancelled'));
  });

  testWidgets('achievements page shows locked and unlocked items', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final auth = await _auth();
    final provider = AchievementProvider(repository: _FakeAchievementRepository());
    addTearDown(provider.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AchievementProvider>.value(value: provider),
          ],
          child: const MaterialApp(home: AchievementsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('The Threshold'), findsWidgets);
    await tester.tap(find.byKey(const Key('achievements-progress-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Keeper of Time'), findsOneWidget);
  });

  testWidgets('mafia lobby hides a start button that would fail', (
    tester,
  ) async {
    final auth = await _auth();
    final mafia = MafiaProvider(repository: _FakeMafiaRepository());
    addTearDown(mafia.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<MafiaProvider>.value(value: mafia),
        ],
        child: const MaterialApp(home: MafiaGameScreen(gameId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تحتاج اللعبة إلى 4 لاعبين. المنضم الآن: 1.'), findsOneWidget);
    final start = tester.widget<PubgetPrimaryButton>(
      find.byType(PubgetPrimaryButton).last,
    );
    expect(start.onPressed, isNull);
    expect(find.textContaining('دورك:'), findsNothing);
    expect(find.text(MafiaLeaveCopy.leave), findsNothing);
    mafia.dispose();
  });

  testWidgets('mafia leave confirms mid-game elimination without role reassignment', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeMafiaRepository(status: 'night', phase: 'night');
    final mafia = MafiaProvider(repository: repository);
    addTearDown(mafia.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<MafiaProvider>.value(value: mafia),
        ],
        child: const MaterialApp(home: MafiaGameScreen(gameId: 'm1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(MafiaLeaveCopy.leave), findsOneWidget);
    await tester.tap(find.text(MafiaLeaveCopy.leave));
    await tester.pump();
    expect(find.text(MafiaLeaveCopy.title), findsOneWidget);
    expect(find.text(MafiaLeaveCopy.bodyFor('night')), findsOneWidget);
    await tester.tap(find.text(MafiaLeaveCopy.confirm));
    await tester.pump();
    expect(repository.leaveCalls, 1);
    mafia.dispose();
  });

  testWidgets('guess character play locks a submitted answer', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: _LiveGameRepository()),
        child: MaterialApp(
          home: Scaffold(
            body: GuessCharacterPlay(
              game: _guessGame(),
              userId: 'alice',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Who is this character?'), findsOneWidget);
    expect(find.text('Luffy'), findsOneWidget);
    expect(find.text('Original Pubget silhouette'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      find.text('Answer locked in. Waiting for the round to resolve.'),
      findsOneWidget,
    );
  });

  testWidgets('guess character artwork falls back to the clue', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterArtworkView(
            artwork: <String, dynamic>{'assetId': 'bad'},
            fallbackClue: 'Use the written clue instead.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use the written clue instead.'), findsOneWidget);
    expect(find.text('Original Pubget silhouette'), findsNothing);
  });

  testWidgets('guess character artwork paints a licensed silhouette', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterArtworkView(
            artwork: <String, dynamic>{
              'assetId': 'pgart_3f8c1a92b4e0',
              'license': 'pubget-original',
              'attribution': 'Original Pubget silhouette',
              'source': 'pubget',
              'portrait': <String, dynamic>{
                'background': '#4C1D95',
                'shapes': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'rect',
                    'x': 8,
                    'y': 8,
                    'w': 84,
                    'h': 84,
                    'r': 18,
                    'color': '#F5D76E',
                  },
                ],
              },
            },
            fallbackClue: 'A straw hat pirate.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Original Pubget silhouette'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('A straw hat pirate.'), findsOneWidget);
  });

  testWidgets('game create exposes the current Phase games without Mafia', (
    tester,
  ) async {
    final creator = GameCreateProvider(repository: _LiveGameRepository());
    addTearDown(creator.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameCreateProvider>.value(value: creator),
          ChangeNotifierProvider<MafiaProvider>(
            create: (_) => MafiaProvider(repository: _FakeMafiaRepository()),
          ),
          Provider<Analytics>.value(value: const _NoOpAnalytics()),
        ],
        child: const MaterialApp(home: GameCreatePage(groupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guess the Character'), findsOneWidget);
    expect(find.text('Mafia'), findsNothing);
    expect(find.text('Rules', skipOffstage: false), findsOneWidget);
  });

  testWidgets('expired events hide the submit control', (tester) async {
    final auth = await _auth();
    final events = EventProvider(repository: _ExpiredEventRepository());
    addTearDown(events.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: EventDetailsScreen(eventId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ended poll'), findsWidgets);
    expect(find.text(EventStrings.submit), findsNothing);
  });

  testWidgets('completed game result offers a next action', (tester) async {
    final auth = await _auth();
    final games = GameProvider(repository: _LiveGameRepository(completed: true));
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
        child: const MaterialApp(home: GameDetailsScreen(gameId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You won'), findsOneWidget);
    expect(find.text(GameStrings.playAgain), findsOneWidget);
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

PubgetGame _guessGame({bool completed = false}) {
  return PubgetGame(
    id: 'g1',
    type: GameType.guessCharacter,
    title: 'Guess',
    description: '',
    version: 1,
    status: completed ? GameStatus.completed : GameStatus.active,
    creatorId: 'alice',
    groupId: 'group-1',
    configuration: const GameConfiguration(
      minPlayers: 2,
      maxPlayers: 2,
      usesRounds: true,
      roundCount: 5,
      timerSeconds: 20,
    ),
    participantsCount: 2,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    result: completed
        ? const GameResult(kind: 'win', winnerIds: <String>['alice'])
        : null,
    publicState: <String, dynamic>{
      'engine': 'guessCharacter',
      'roundNumber': 1,
      'totalRounds': 5,
      'answeredPlayerIds': <String>['alice'],
      'scores': <String, int>{'alice': 1, 'bob': 0},
      'prompt': <String, dynamic>{
        'question': 'Who is this character?',
        'clue': 'Straw hat pirate',
        'artwork': <String, dynamic>{
          'assetId': 'pgart_3f8c1a92b4e0',
          'license': 'pubget-original',
          'attribution': 'Original Pubget silhouette',
          'source': 'pubget',
          'version': 1,
          'portrait': <String, dynamic>{
            'background': '#4C1D95',
            'shapes': <Map<String, Object>>[
              <String, Object>{
                'type': 'rect',
                'x': 8,
                'y': 8,
                'w': 84,
                'h': 84,
                'r': 18,
                'color': '#4C1D95',
              },
            ],
          },
        },
        'choices': <Map<String, String>>[
          <String, String>{'id': 'a', 'name': 'Luffy'},
          <String, String>{'id': 'b', 'name': 'Zoro'},
        ],
      },
    },
  );
}

final class _NoOpAnalytics implements Analytics {
  const _NoOpAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}

final class _FakeAchievementRepository implements AchievementRepository {
  @override
  Future<Result<List<AchievementItem>>> list({String? userId}) async =>
      Success(AchievementCatalog.lockedItems());

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) {
    expect(userId, 'alice');
    final threshold = AchievementCatalog.byId('the_threshold')!;
    final keeper = AchievementCatalog.byId('keeper_of_time')!;
    return Stream<Result<List<AchievementItem>>>.value(
      Success(<AchievementItem>[
        AchievementItem(
          definition: threshold,
          unlocked: true,
          unlockedAt: DateTime.utc(2026, 1, 1),
        ),
        AchievementItem(definition: keeper, unlocked: false),
      ]),
    );
  }
}

final class _FakeMafiaRepository implements MafiaRepository {
  _FakeMafiaRepository({
    this.status = 'waiting',
    this.phase = 'waiting',
  });

  final String status;
  final String phase;
  var leaveCalls = 0;

  @override
  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 4,
    int maxPlayers = 8,
  }) async => const Success('m1');

  @override
  Future<Result<void>> join(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> start(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> leave(String gameId) async {
    leaveCalls += 1;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> submitNightAction({
    required String gameId,
    required String targetId,
    required int nightNumber,
    String? actionId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> submitVote({
    required String gameId,
    required String targetId,
    required int dayNumber,
    String? actionId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> endTurn(String gameId, {String? actionId}) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> submitLastWords(
    String gameId,
    String text, {
    String? actionId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> sendMafiaMessage(
    String gameId,
    String text, {
    String? actionId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> sendChat({
    required String gameId,
    required String text,
    required MafiaPlayer self,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> heartbeat(String gameId) async =>
      const Success<void>(null);

  @override
  Stream<Result<MafiaGame>> watchGame(String gameId) =>
      Stream<Result<MafiaGame>>.value(
        Success(
          MafiaGame(
            id: 'm1',
            groupId: 'g1',
            createdBy: 'alice',
            status: status,
            currentPhase: phase,
            playersCount: status == 'waiting' ? 1 : 5,
            minPlayers: 4,
            maxPlayers: 8,
          ),
        ),
      );

  @override
  Stream<Result<List<MafiaPlayer>>> watchPlayers(String gameId) =>
      Stream<Result<List<MafiaPlayer>>>.value(
        const Success(<MafiaPlayer>[
          MafiaPlayer(userId: 'alice', username: 'Alice'),
        ]),
      );

  @override
  Stream<Result<MafiaPrivateState>> watchPrivate({
    required String gameId,
    required String userId,
  }) => Stream<Result<MafiaPrivateState>>.value(
    const Success(MafiaPrivateState()),
  );

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchEvents(String gameId) =>
      Stream<Result<List<Map<String, dynamic>>>>.value(
        const Success(<Map<String, dynamic>>[]),
      );

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchChat(String gameId) =>
      Stream<Result<List<Map<String, dynamic>>>>.value(
        const Success(<Map<String, dynamic>>[]),
      );

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchMafiaMessages(String gameId) =>
      Stream<Result<List<Map<String, dynamic>>>>.value(
        const Success(<Map<String, dynamic>>[]),
      );
}

final class _LiveGameRepository implements GameRepository {
  _LiveGameRepository({this.completed = false});

  final bool completed;

  @override
  Future<Result<void>> cancel(String gameId) async => const Success<void>(null);

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) async =>
      Success(_guessGame());

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
      Stream<Result<PubgetGame>>.value(Success(_guessGame(completed: completed)));

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) =>
      Stream<Result<List<GameParticipant>>>.value(
        const Success(<GameParticipant>[
          GameParticipant(
            gameId: 'g1',
            userId: 'alice',
            status: ParticipantStatus.active,
            displayName: 'Alice',
          ),
          GameParticipant(
            gameId: 'g1',
            userId: 'bob',
            status: ParticipantStatus.active,
            displayName: 'Bob',
          ),
        ]),
      );

  @override
  Stream<Result<Map<String, dynamic>>> watchPrivate({
    required String gameId,
    required String userId,
  }) => Stream<Result<Map<String, dynamic>>>.value(
    const Success(<String, dynamic>{}),
  );
}

final class _ExpiredEventRepository implements EventRepository {
  PubgetEvent get _event => PubgetEvent(
    id: 'e1',
    type: EventType.poll,
    creatorId: 'alice',
    groupId: 'g1',
    title: 'Ended poll',
    description: 'Closed',
    configuration: const EventConfiguration(
      question: 'Best?',
      options: <EventOption>[
        EventOption(id: 'opt-1', label: 'One'),
        EventOption(id: 'opt-2', label: 'Two'),
      ],
    ),
    status: EventStatus.active,
    startAt: DateTime.utc(2000, 1, 1),
    endAt: DateTime.utc(2000, 1, 2),
    participantsCount: 1,
    responsesCount: 1,
    tally: const EventTally(),
    result: const EventResult(
      kind: 'poll',
      submissions: 1,
      winnerIds: <String>['opt-1'],
    ),
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );

  @override
  Future<Result<void>> archive(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> cancel(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteDraft(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> end(String eventId) async => const Success<void>(null);

  @override
  Future<Result<List<PubgetEvent>>> getActiveEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getGroupEvents({
    required String groupId,
    int limit = 20,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getMyDrafts({
    required String userId,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getMyEvents({
    required String userId,
    int limit = 20,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  }) async => const Success<EventResponse?>(null);

  @override
  Future<Result<List<PubgetEvent>>> getRecentEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<void>> join(String eventId) async => const Success<void>(null);

  @override
  Future<Result<void>> leave(String eventId) async => const Success<void>(null);

  @override
  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  }) async => FailureResult(UnknownError('unused'));

  @override
  Future<Result<String>> saveDraft(EventDraft draft) async =>
      const Success('draft-1');

  @override
  Future<Result<List<PubgetEvent>>> search(String query) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  }) async => const Success<void>(null);

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) =>
      Stream<Result<PubgetEvent>>.value(Success(_event));
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
    GroupJoinPayload? join,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> leaveGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> requestToJoin({required String groupId, GroupJoinPayload? join}) async =>
      const Success<void>(null);

  @override
  Future<Result<List<Group>>> searchGroups(String query) async =>
      const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      const Success(<Group>[]);

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) =>
      Stream.fromFuture(listJoinedGroups(userId));

  @override
  Future<Result<void>> updateGroupSettings({
    required String groupId,
    required GroupSettingsUpdate settings,
  }) async => const Success<void>(null);

  @override
  Future<Result<bool>> isBanned({
    required String groupId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<bool>> hasPendingRequest({
    required String groupId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(String groupId) async =>
      const Success(<RoleplayCharacter>[]);

  @override
  Future<Result<void>> promoteGroup(String groupId) async =>
      const Success<void>(null);
}

