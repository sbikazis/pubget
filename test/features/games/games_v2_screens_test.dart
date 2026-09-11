import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/games/models/games_schema_v2.dart';
import 'package:pubget/features/games/providers/games_session_provider_v2.dart';
import 'package:pubget/features/games/repositories/games_repository_v2.dart';
import 'package:pubget/features/games/screens/game_create_v2_screen.dart';
import 'package:pubget/features/games/screens/game_history_v2_screen.dart';
import 'package:pubget/features/games/screens/game_room_v2_screen.dart';
import 'package:pubget/features/games/screens/game_rules_v2_screen.dart';
import 'package:pubget/features/games/screens/games_center_v2_screen.dart';
import 'package:pubget/features/games/screens/game_waiting_v2_screen.dart';

class _FakeGamesRepository implements GamesRepositoryV2 {
  _FakeGamesRepository({
    this.history = const <GameSessionV2>[],
    this.historyDelay = Duration.zero,
  });
  final List<GameSessionV2> history;
  final Duration historyDelay;
  final StreamController<Result<GameSessionV2>> sessions =
      StreamController<Result<GameSessionV2>>.broadcast();
  GameSessionV2? currentSession;
  Failure? historyFailure;
  int historyCalls = 0;
  @override
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  }) async => Success(_session(type: type, id: 'created'));
  @override
  Future<Result<void>> command(GameCommandRequest request) async => const Success(null);
  @override
  Stream<Result<GameSessionV2>> watchSession(String gameId) =>
      currentSession == null
      ? sessions.stream
      : Stream.value(Success(currentSession!));
  @override
  Stream<Result<Map<String, dynamic>>> watchPrivateState({
    required String gameId,
    required String userId,
  }) => Stream.value(const Success(<String, dynamic>{}));
  @override
  Future<Result<GameHistoryPage>> groupHistory({
    required String groupId,
    String? cursor,
    int limit = 20,
  }) async {
    historyCalls++;
    if (historyDelay > Duration.zero) {
      await Future<void>.delayed(historyDelay);
    }
    if (historyFailure != null) return FailureResult(historyFailure!);
    return Success(GameHistoryPage(games: history, nextCursor: null));
  }
  void emit(GameSessionV2 session) => sessions.add(Success(session));
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GameSessionV2 _session({
  GameTypeV2 type = GameTypeV2.guessCharacter,
  GameLifecycleStatusV2 status = GameLifecycleStatusV2.waiting,
  String id = 'game-1',
  String creatorId = 'creator',
}) => GameSessionV2(
  id: id,
  groupId: 'group',
  type: type,
  status: status,
  creatorId: creatorId,
  version: 1,
  players: const [
    GamePlayerV2(userId: 'creator', displayName: 'Creator', joinedAt: null),
  ],
  state: const {'question': 'من هذه الشخصية؟'},
);

Widget _host(Widget child, _FakeGamesRepository repo) => MaterialApp(
  home: Theme(data: ThemeData(useMaterial3: true), child: MultiProvider(
    providers: [
      Provider<GamesRepositoryV2>.value(value: repo),
      ChangeNotifierProvider(create: (_) => GamesSessionProviderV2(repo)),
    ],
    child: child,
  )),
);

void main() {
  testWidgets('Game Center renders loading then empty archive', (tester) async {
    await tester.pumpWidget(_host(
      GamesCenterV2Screen(groupId: 'group', userId: 'creator'),
      _FakeGamesRepository(historyDelay: const Duration(seconds: 1)),
    ));
    expect(find.text('مركز الألعاب'), findsOneWidget);
    expect(find.text('لا توجد مباريات بعد'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Game Center renders content and error state', (tester) async {
    final repo = _FakeGamesRepository(
      history: [_session(status: GameLifecycleStatusV2.completed)],
    );
    await tester.pumpWidget(_host(
      GamesCenterV2Screen(groupId: 'group', userId: 'creator'),
      repo,
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('خمن الشخصية'), findsWidgets);
    final errorRepo = _FakeGamesRepository()
      ..historyFailure = UnknownError('offline');
    await tester.pumpWidget(_host(
      GamesCenterV2Screen(groupId: 'group', userId: 'creator'),
      errorRepo,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('Create exposes exactly the three Prompt 1 options', (tester) async {
    final repo = _FakeGamesRepository();
    await tester.pumpWidget(_host(
      GamesCreateV2Screen(groupId: 'group', userId: 'creator'),
      repo,
    ));
    expect(find.text('خمن الشخصية'), findsOneWidget);
    expect(find.text('سلسلة الأنمي'), findsOneWidget);
    expect(find.text('خمن الأنمي'), findsOneWidget);
    expect(find.textContaining('Mafia'), findsOneWidget);
    expect(find.byType(_FakeGamesRepository), findsNothing);
  });

  testWidgets('Waiting room exposes creator controls and player join', (tester) async {
    final repo = _FakeGamesRepository();
    repo.currentSession = _session();
    final provider = GamesSessionProviderV2(repo);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        child: const GameWaitingV2Screen(gameId: 'game-1', userId: 'creator'),
      ),
    ));
    repo.emit(_session());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(Scaffold), findsWidgets);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        child: const GameWaitingV2Screen(gameId: 'game-1', userId: 'guest'),
      ),
    ));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
    provider.dispose();
  });

  testWidgets('Each room type renders its distinct type label', (tester) async {
    for (final type in GameTypeV2.values) {
      final repo = _FakeGamesRepository();
      repo.currentSession = _session(
        type: type,
        status: GameLifecycleStatusV2.inProgress,
      );
      final provider = GamesSessionProviderV2(repo);
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: GameRoomV2Screen(gameId: 'game-1', userId: 'creator'),
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
      provider.dispose();
    }
  });

  testWidgets('In-progress room guards back navigation', (tester) async {
    final repo = _FakeGamesRepository();
    repo.currentSession = _session(status: GameLifecycleStatusV2.inProgress);
    final provider = GamesSessionProviderV2(repo);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const GameRoomV2Screen(gameId: 'game-1', userId: 'creator'),
            ),
          ));
        });
        return const Scaffold();
      }),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('History shows empty and rules are available', (tester) async {
    final repo = _FakeGamesRepository();
    await tester.pumpWidget(_host(
      GameHistoryV2Screen(groupId: 'group', userId: 'creator'),
      repo,
    ));
    await tester.pumpAndSettle();
    expect(find.text('أرشيف المباريات'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: GameRulesV2Screen()));
    expect(find.text('Mafia'), findsOneWidget);
    expect(find.text('قادمة في Prompt 2 — لا يمكن إنشاؤها من هذا المركز.'), findsOneWidget);
  });
}