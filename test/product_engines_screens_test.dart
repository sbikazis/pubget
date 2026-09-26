import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/analytics/analytics.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/l10n/app_strings.dart';
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
import 'package:pubget/features/games/providers/game_catalog_provider.dart';
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
    // Master Spec 13.7: a player may leave the waiting room, the lobby in
    // STARTING, and any live phase. A finished game cannot be left.
    for (final status in <String>[
      'WAITING',
      'STARTING',
      'ROLE_REVEAL',
      'NIGHT',
      'DAY',
      'DISCUSSION',
      'VOTING',
      'VOTE_RESULT',
      'RESOLUTION',
    ]) {
      expect(
        MafiaGame.fromMap(<String, dynamic>{
          'status': status,
        }, id: 'g1').canLeaveViaServer,
        isTrue,
        reason: '$status must be leaveable',
      );
    }
    for (final status in <String>['GAME_OVER', 'CANCELLED']) {
      expect(
        MafiaGame.fromMap(<String, dynamic>{
          'status': status,
        }, id: 'g1').canLeaveViaServer,
        isFalse,
        reason: '$status must not be leaveable',
      );
    }

    final copy = AppStrings.forLocale(const Locale('en'));
    expect(copy.mafiaLeaveBodyFor('NIGHT'), contains('eliminated'));
    expect(copy.mafiaLeaveBodyFor('STARTING'), contains('cancelled'));
    expect(copy.mafiaLeaveBodyFor('WAITING'), contains('free'));
    expect(copy.mafiaLeaveBodyFor('GAME_OVER'), contains('cannot be left'));
    // Both official locales are real copy, not one with empty strings.
    final arabic = AppStrings.arabic;
    for (final body in <String>[
      arabic.mafiaLeaveWaitingBody,
      arabic.mafiaLeaveStartingBody,
      arabic.mafiaLeaveActiveBody,
    ]) {
      expect(body, isNotEmpty);
      expect(body, isNot(equals(copy.mafiaLeaveActiveBody)));
    }
  });

  test('a mafia game parses the server status vocabulary', () {
    // The server writes uppercase lifecycle states. The client used to compare
    // them against lowercase Dart names, so every game parsed as a draft and
    // nothing was ever joinable, playable, or terminal.
    for (final entry in <String, bool>{
      'WAITING': true,
      'STARTING': true,
      'IN_PROGRESS': false,
      'COMPLETED': false,
      'CANCELLED': false,
      'CREATED': false,
    }.entries) {
      final game = MafiaGame.fromMap(<String, dynamic>{
        'status': entry.key,
        'currentPhase': entry.key,
      }, id: 'g1');
      expect(game.status, entry.key);
      expect(game.isLobby, entry.value, reason: entry.key);
    }
    // The specified 7-15 range is also the client's default when a field is
    // missing, instead of the old 4-8.
    final bare = MafiaGame.fromMap(const <String, dynamic>{}, id: 'g1');
    expect(bare.minPlayers, 7);
    expect(bare.maxPlayers, 15);
  });

  testWidgets('achievements page shows locked and unlocked items', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final auth = await _auth();
    final provider = AchievementProvider(
      repository: _FakeAchievementRepository(),
    );
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
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: <Locale>[Locale('en'), Locale('ar')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MafiaGameScreen(gameId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final arabic = AppStrings.of(tester.element(find.byType(MafiaGameScreen)));
    expect(arabic.isArabic, isTrue, reason: 'the app must render Arabic here');
    expect(find.text(arabic.mafiaNeedMorePlayers(7, 1)), findsOneWidget);
    final start = tester.widget<PubgetPrimaryButton>(
      find.byType(PubgetPrimaryButton).last,
    );
    expect(start.onPressed, isNull);
    expect(find.textContaining(arabic.mafiaYourRole('')), findsNothing);
    // The waiting room is leaveable now, and the button says so honestly
    // rather than pretending the player is stuck.
    expect(find.text(arabic.mafiaLeave), findsOneWidget);
    mafia.dispose();
  });

  testWidgets(
    'mafia leave confirms mid-game elimination without role reassignment',
    (tester) async {
      final auth = await _auth();
      final repository = _FakeMafiaRepository(status: 'NIGHT', phase: 'NIGHT');
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

      final copy = AppStrings.forLocale(const Locale('en'));
      expect(find.text(copy.mafiaLeave), findsOneWidget);
      await tester.tap(find.text(copy.mafiaLeave));
      await tester.pump();
      expect(find.text(copy.mafiaLeaveTitle), findsOneWidget);
      expect(find.text(copy.mafiaLeaveBodyFor('NIGHT')), findsOneWidget);
      // The app bar and the dialog both read "Leave"; only the dialog confirms.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(copy.mafiaLeaveConfirm),
        ),
      );
      await tester.pump();
      expect(repository.leaveCalls, 1);
      mafia.dispose();
    },
  );

  testWidgets('guess character selection offers the catalog, not free text', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: ChangeNotifierProvider<GameCatalogProvider>(
          create: (_) => GameCatalogProvider(repository: repository),
          child: MaterialApp(
            home: Scaffold(
              body: GuessCharacterPlay(game: _guessGame(), userId: 'alice'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your secret character'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'luffy');
    // The catalog answer is debounced, so settle past the debounce window.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Monkey D. Luffy'), findsOneWidget);

    await tester.tap(find.text('Monkey D. Luffy'));
    await tester.pumpAndSettle();
    // Only a real catalog ID may become game state.
    expect(repository.actions.single.actionType, GameActionTypes.select);
    expect(
      repository.actions.single.payload['characterId'],
      'chr_onepiece_luffy',
    );
  });

  testWidgets('guess character locks a player who already chose', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: ChangeNotifierProvider<GameCatalogProvider>(
          create: (_) => GameCatalogProvider(repository: repository),
          child: MaterialApp(
            home: Scaffold(
              body: GuessCharacterPlay(
                game: _guessGame(phase: 'selection', selected: true),
                userId: 'alice',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Secret locked in. Waiting for the other player.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(repository.actions, isEmpty);
  });

  testWidgets('guess character lets the current player ask or guess', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: ChangeNotifierProvider<GameCatalogProvider>(
          create: (_) => GameCatalogProvider(repository: repository),
          child: MaterialApp(
            home: Scaffold(
              body: GuessCharacterPlay(
                game: _guessGame(phase: 'ask', currentPlayerId: 'alice'),
                userId: 'alice',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your turn'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Is he a pirate?');
    await tester.tap(find.widgetWithText(PubgetPrimaryButton, 'Ask'));
    await tester.pumpAndSettle();
    expect(repository.actions.single.actionType, GameActionTypes.ask);
    expect(repository.actions.single.payload['question'], 'Is he a pirate?');

    await tester.enterText(find.byType(TextField).last, 'luffy');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monkey D. Luffy'));
    await tester.pumpAndSettle();
    expect(repository.actions.last.actionType, GameActionTypes.guess);
    expect(
      repository.actions.last.payload['characterId'],
      'chr_onepiece_luffy',
    );
  });

  testWidgets('guess character holds the waiting player out of the turn', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: ChangeNotifierProvider<GameCatalogProvider>(
          create: (_) => GameCatalogProvider(repository: repository),
          child: MaterialApp(
            home: Scaffold(
              body: GuessCharacterPlay(
                game: _guessGame(
                  phase: 'ask',
                  currentPlayerId: 'alice',
                  question: 'Is he a pirate?',
                ),
                userId: 'bob',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for the other players'), findsOneWidget);
    expect(find.text('Is he a pirate?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repository.actions, isEmpty);
  });

  testWidgets('guess character answers yes or no for the answerer only', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: ChangeNotifierProvider<GameCatalogProvider>(
          create: (_) => GameCatalogProvider(repository: repository),
          child: MaterialApp(
            home: Scaffold(
              body: GuessCharacterPlay(
                game: _guessGame(
                  phase: 'answer',
                  currentPlayerId: 'alice',
                  answeringPlayerId: 'bob',
                  question: 'Is he a pirate?',
                ),
                userId: 'bob',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PubgetPrimaryButton, 'Yes'));
    await tester.pumpAndSettle();
    expect(repository.actions.single.actionType, GameActionTypes.answer);
    expect(repository.actions.single.payload['answer'], 'yes');
  });

  testWidgets('emoji clue owner cannot guess its own clue', (tester) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: MaterialApp(
          home: Scaffold(
            body: EmojiGuessPlay(
              game: _emojiGame(currentPlayerId: 'alice'),
              userId: 'alice',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You own this clue. Wait for a guess.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repository.actions, isEmpty);
  });

  testWidgets('emoji guesser is locked out after answering the round', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: MaterialApp(
          home: Scaffold(
            body: EmojiGuessPlay(
              game: _emojiGame(
                currentPlayerId: 'alice',
                answered: <String>['bob'],
              ),
              userId: 'bob',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You already guessed this round.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repository.actions, isEmpty);
  });

  testWidgets('emoji guesser submits a real catalog title once', (
    tester,
  ) async {
    final repository = _LiveGameRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<GameProvider>(
        create: (_) => GameProvider(repository: repository),
        child: MaterialApp(
          home: Scaffold(
            body: EmojiGuessPlay(
              game: _emojiGame(currentPlayerId: 'alice'),
              userId: 'bob',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'One Piece');
    await tester.tap(find.widgetWithText(PubgetPrimaryButton, 'Submit guess'));
    await tester.pumpAndSettle();
    expect(repository.actions.single.actionType, GameActionTypes.guess);
    expect(repository.actions.single.payload['title'], 'One Piece');
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

  testWidgets('guess character artwork paints a licensed silhouette', (
    tester,
  ) async {
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
    final games = GameProvider(
      repository: _LiveGameRepository(completed: true),
    );
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

PubgetGame _guessGame({
  bool completed = false,
  String phase = 'selection',
  bool selected = false,
  String? currentPlayerId,
  String? answeringPlayerId,
  String? question,
}) {
  return PubgetGame(
    id: 'g1',
    type: GameType.guessCharacter,
    title: 'Guess',
    description: '',
    version: 1,
    status: completed ? GameStatus.completed : GameStatus.inProgress,
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
      'phase': phase,
      'players': <String, dynamic>{
        'alice': <String, dynamic>{'selected': selected},
        'bob': <String, dynamic>{'selected': selected},
      },
      'currentPlayerId': currentPlayerId,
      'answeringPlayerId': answeringPlayerId,
      'question': question,
      'answerOptions': question == null ? null : <String>['yes', 'no'],
      'lastAction': null,
      'result': null,
    },
  );
}

PubgetGame _emojiGame({
  required String currentPlayerId,
  List<String> answered = const <String>[],
}) {
  return PubgetGame(
    id: 'g2',
    type: GameType.emojiAnimeGuess,
    title: 'Emoji',
    description: '',
    version: 1,
    status: GameStatus.inProgress,
    creatorId: 'alice',
    groupId: 'group-1',
    configuration: const GameConfiguration(
      minPlayers: 2,
      maxPlayers: 4,
      usesRounds: true,
      roundCount: 1,
      timerSeconds: 25,
    ),
    participantsCount: 2,
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
    publicState: <String, dynamic>{
      'engine': 'emojiAnimeGuess',
      'phase': 'guess',
      'emojis': <String>['🏴‍☠️', '🍖'],
      'currentPlayerId': currentPlayerId,
      'turnIndex': 0,
      'totalTurns': 2,
      'scores': <String, int>{'alice': 0, 'bob': 0},
      'answeredPlayerIds': answered,
      'lastReveal': null,
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
  _FakeMafiaRepository({this.status = 'WAITING', this.phase = 'WAITING'});

  final String status;
  final String phase;
  var leaveCalls = 0;

  @override
  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 7,
    int maxPlayers = 15,
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
            playersCount: status == 'WAITING' ? 1 : 5,
            minPlayers: 7,
            maxPlayers: 15,
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
  Stream<Result<List<Map<String, dynamic>>>> watchMafiaMessages(
    String gameId,
  ) => Stream<Result<List<Map<String, dynamic>>>>.value(
    const Success(<Map<String, dynamic>>[]),
  );
}

final class _SubmittedAction {
  const _SubmittedAction(this.actionType, this.payload);

  final String actionType;
  final Map<String, dynamic> payload;
}

final class _LiveGameRepository implements GameRepository {
  _LiveGameRepository({this.completed = false});

  final bool completed;
  final List<_SubmittedAction> actions = <_SubmittedAction>[];

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
  Future<Result<List<AnimeSearchItem>>> searchAnime(
    String query, {
    int limit = 20,
  }) async => const Success(<AnimeSearchItem>[]);

  @override
  Future<Result<List<CharacterSearchItem>>> searchCharacters(
    String query, {
    String? animeId,
    int limit = 20,
  }) async => const Success(<CharacterSearchItem>[
    CharacterSearchItem(
      id: 'chr_onepiece_luffy',
      name: 'Monkey D. Luffy',
      animeIds: <String>['mal_onepiece'],
    ),
  ]);

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
  Future<Result<void>> start(String gameId) async => const Success<void>(null);

  @override
  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? clientActionId,
  }) async {
    actions.add(_SubmittedAction(actionType, payload));
    return const Success<void>(null);
  }

  @override
  Future<Result<List<GameHistoryEntry>>> getHistory({
    required String userId,
    int limit = 20,
  }) async => const Success(<GameHistoryEntry>[]);

  @override
  Stream<Result<PubgetGame>> watchGame(String gameId) =>
      Stream<Result<PubgetGame>>.value(
        Success(_guessGame(completed: completed)),
      );

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
  Future<Result<List<PubgetEvent>>> getActiveEvents({
    int limit = 20,
    PubgetEvent? after,
  }) async => const Success(<PubgetEvent>[]);

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
  Future<Result<List<PubgetEvent>>> getRecentEvents({
    int limit = 20,
    PubgetEvent? after,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getEventsByAnime({
    required String animeId,
    int limit = 20,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<EventPreview>> preview({required String eventId}) async =>
      const FailureResult(ValidationError('unused'));

  @override
  Future<Result<EventResult>> resolve({
    required String eventId,
    String? winnerOptionId,
    List<String>? winnerIds,
  }) async => const FailureResult(ValidationError('unused'));

  @override
  Future<Result<EventAnalytics>> getAnalytics(String eventId) async =>
      const FailureResult(ValidationError('unused'));

  @override
  Future<Result<String>> addComment({
    required String eventId,
    required String text,
  }) async => const Success('comment-1');

  @override
  Future<Result<void>> react({
    required String eventId,
    required String reaction,
  }) async => const Success<void>(null);

  @override
  Stream<Result<List<EventComment>>> watchComments(String eventId) =>
      const Stream<Result<List<EventComment>>>.empty();

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
  Future<Result<void>> requestToJoin({
    required String groupId,
    GroupJoinPayload? join,
  }) async => const Success<void>(null);

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
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(
    String groupId,
  ) async => const Success(<RoleplayCharacter>[]);

  @override
  Future<Result<void>> promoteGroup(String groupId) async =>
      const Success<void>(null);
}
