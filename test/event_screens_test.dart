import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/models/event_type_registry.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';
import 'package:pubget/features/events/screens/event_details_screen.dart';
import 'package:pubget/features/events/screens/event_list_screen.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('event list shows empty copy when there are no events', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeEventRepository();
    final list = EventListProvider(repository: repository);
    addTearDown(list.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EventListProvider>.value(value: list),
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(repository: _FakeGroupRepository()),
          ),
        ],
        child: const MaterialApp(home: EventListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(EventStrings.noEventsTitle), findsWidgets);
  });

  testWidgets('event details shows a missing-event empty state', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeEventRepository();
    final events = EventProvider(repository: repository);
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
        child: const MaterialApp(home: EventDetailsScreen(eventId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(EventStrings.missing), findsWidgets);
    expect(find.byType(PubgetEmptyState), findsOneWidget);
  });

  testWidgets('ranking copy follows the app locale', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = await _auth();
    final repository = _FakeEventRepository()..event = _rankingEvent();
    final events = EventProvider(repository: repository);
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
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: <Locale>[Locale('en'), Locale('ar')],
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: EventDetailsScreen(eventId: 'ranking-1'),
        ),
      ),
    );
    for (
      var attempt = 0;
      attempt < 20 &&
          find.byKey(const Key('event-ranking-options')).evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('اسحب الخيارات إلى الترتيب الذي تفضّله.'), findsOneWidget);
    expect(find.text('إعادة ضبط الترتيب'), findsOneWidget);
  });

  testWidgets('quiz questions lock when the per-question timer expires', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = await _auth();
    final repository = _FakeEventRepository()..event = _quizEvent();
    final events = EventProvider(repository: repository);
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
        child: const MaterialApp(home: EventDetailsScreen(eventId: 'quiz-1')),
      ),
    );
    for (
      var attempt = 0;
      attempt < 20 && find.text('Who wins?').evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('00:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Time up'), findsOneWidget);
    expect(find.textContaining('locked'), findsOneWidget);
  });

  testWidgets('ranking events submit the drag-and-drop order', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = await _auth();
    final repository = _FakeEventRepository()..event = _rankingEvent();
    final events = EventProvider(repository: repository);
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
        child: const MaterialApp(
          home: EventDetailsScreen(eventId: 'ranking-1'),
        ),
      ),
    );
    for (
      var attempt = 0;
      attempt < 20 &&
          find.byKey(const Key('event-ranking-options')).evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(events.event, isNotNull);
    final ranking = tester.widget<ReorderableListView>(
      find.byKey(const Key('event-ranking-options')),
    );
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    ranking.onReorder(1, 0);
    await tester.pump();
    await tester.tap(find.text(EventStrings.submit));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedResponses.single['rankedIds'], <String>[
      'opt-2',
      'opt-1',
      'opt-3',
    ]);
  });
}

PubgetEvent _rankingEvent() => PubgetEvent(
  id: 'ranking-1',
  type: EventType.ranking,
  creatorId: 'alice',
  groupId: null,
  title: 'Rank the options',
  description: '',
  configuration: const EventConfiguration(
    question: 'Rank the options',
    options: <EventOption>[
      EventOption(id: 'opt-1', label: 'One'),
      EventOption(id: 'opt-2', label: 'Two'),
      EventOption(id: 'opt-3', label: 'Three'),
    ],
  ),
  status: EventStatus.active,
  startAt: DateTime.utc(2026, 9, 25),
  endAt: DateTime.utc(2027, 9, 25),
  participantsCount: 1,
  responsesCount: 0,
  tally: const EventTally(),
  result: null,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

PubgetEvent _quizEvent() => PubgetEvent(
  id: 'quiz-1',
  type: EventType.quiz,
  creatorId: 'alice',
  groupId: null,
  title: 'Knowledge check',
  description: '',
  configuration: const EventConfiguration(
    question: 'Who wins?',
    questions: <EventQuizQuestion>[
      EventQuizQuestion(
        id: 'q-1',
        prompt: 'Who wins?',
        options: <EventOption>[
          EventOption(id: 'opt-1', label: 'One'),
          EventOption(id: 'opt-2', label: 'Two'),
        ],
        correctOptionId: 'opt-1',
        seconds: 1,
      ),
    ],
  ),
  status: EventStatus.active,
  startAt: DateTime.utc(2026, 9, 25),
  endAt: DateTime.utc(2027, 9, 25),
  participantsCount: 1,
  responsesCount: 0,
  tally: const EventTally(),
  result: null,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

Future<AuthProvider> _auth() async {
  final repository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: repository);
  await auth.initialize();
  return auth;
}

final class _FakeEventRepository implements EventRepository {
  PubgetEvent? event;
  final List<Map<String, dynamic>> submittedResponses =
      <Map<String, dynamic>>[];

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
  }) async {
    submittedResponses.add(responseData);
    return const Success<void>(null);
  }

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) {
    final current = event;
    return Stream<Result<PubgetEvent>>.value(
      current == null
          ? const FailureResult(NotFoundError('This event no longer exists.'))
          : Success(current),
    );
  }
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
