import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_shell_create_sheet.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';
import 'package:pubget/features/events/screens/create_event_entry_page.dart';
import 'package:pubget/features/events/screens/event_list_screen.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

import 'authentication_test_support.dart';

void main() {
  test('create sheet order is group, clip, event, fan work', () {
    expect(
      AppShellCreateSheet.actionKeys,
      <String>['create-group', 'create-edit', 'create-event', 'create-fan-work'],
    );
  });

  test('plain members can create events; visitors cannot', () {
    expect(
      memberCanCreateEvents(const GroupMember(uid: 'm1', role: PubgetRank.ronin)),
      isTrue,
    );
    expect(
      memberCanCreateEvents(
        const GroupMember(uid: 'c1', role: PubgetRank.hatamoto),
      ),
      isTrue,
    );
    expect(memberCanCreateEvents(null), isFalse);
    expect(
      const GroupMember(uid: 'm1', role: PubgetRank.ronin).canManageEvents,
      isFalse,
    );
  });

  testWidgets('creation menu lists the four target actions in order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open-create'),
              onPressed: () => AppShellCreateSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-group')), findsOneWidget);
    expect(find.byKey(const Key('create-edit')), findsOneWidget);
    expect(find.byKey(const Key('create-event')), findsOneWidget);
    expect(find.byKey(const Key('create-fan-work')), findsOneWidget);
    expect(find.text(AppStrings.english.browseEvents), findsNothing);
    expect(find.text(AppStrings.english.createVideoClip), findsOneWidget);
    expect(find.text(AppStrings.english.createEvent), findsOneWidget);

    final order = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.key as ValueKey<String>?)?.value)
        .toList();
    expect(
      order,
      <String>['create-group', 'create-edit', 'create-event', 'create-fan-work'],
    );
  });

  testWidgets('a plain member can open event creation from a joined group', (
    tester,
  ) async {
    final auth = await _auth('bob');
    final groups = GroupProvider(repository: _MemberGroupRepository());
    addTearDown(auth.dispose);
    addTearDown(groups.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          home: CreateEventEntryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-event-group-g1')), findsOneWidget);
    expect(find.text('Member Crew'), findsOneWidget);
  });

  testWidgets('group event list create action is reachable for a member', (
    tester,
  ) async {
    final auth = await _auth('bob');
    final groups = GroupProvider(repository: _MemberGroupRepository());
    final list = EventListProvider(repository: _EmptyEventRepository());
    addTearDown(auth.dispose);
    addTearDown(groups.dispose);
    addTearDown(list.dispose);
    await groups.load(groupId: 'g1', userId: 'bob');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ChangeNotifierProvider<EventListProvider>.value(value: list),
        ],
        child: const MaterialApp(
          home: EventListScreen(groupId: 'g1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(groups.canCreateEvents, isTrue);
    expect(groups.canManageEvents, isFalse);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

Future<AuthProvider> _auth(String id) async {
  final repository = FakeAuthRepository(
    user: AuthUser(id: id, email: '$id@example.com'),
  );
  final auth = AuthProvider(repository: repository);
  await auth.initialize();
  return auth;
}

Group _group() => Group(
  id: 'g1',
  name: 'Member Crew',
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'alice',
  membersCount: 3,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 1,
);

final class _MemberGroupRepository implements GroupRepository {
  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(_group());

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(_group());

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: PubgetRank.ronin));

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
      Success(<Group>[_group()]);

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) =>
      Stream<Result<List<Group>>>.fromFuture(listJoinedGroups(userId));

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


final class _EmptyEventRepository implements EventRepository {
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
  }) async => const FailureResult(UnknownError('unused'));

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
      const Stream<Result<PubgetEvent>>.empty();
}
