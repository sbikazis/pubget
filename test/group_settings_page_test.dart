import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/group_settings_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('founder can save the five settings fields', (tester) async {
    final groups = _FakeGroupRepository(viewerRole: GroupRole.founder);
    await tester.pumpWidget(await _harness(groups: groups));
    await tester.pumpAndSettle();

    expect(find.text('You cannot manage group settings'), findsNothing);
    await tester.enterText(find.byKey(const Key('group-settings-name')), 'Renamed');
    await tester.enterText(
      find.byKey(const Key('group-settings-description')),
      'Updated bio',
    );
    await tester.enterText(
      find.byKey(const Key('group-settings-rules')),
      'Be excellent',
    );
    await tester.tap(find.byKey(const Key('group-settings-searchable')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-settings-save')));
    await tester.pumpAndSettle();

    expect(groups.settingsUpdates, hasLength(1));
    final saved = groups.settingsUpdates.single;
    expect(saved.name, 'Renamed');
    expect(saved.description, 'Updated bio');
    expect(saved.rules, 'Be excellent');
    expect(saved.joinPolicy, JoinPolicy.open);
    expect(saved.isSearchable, isFalse);
  });

  testWidgets('unauthorized member cannot submit settings', (tester) async {
    final groups = _FakeGroupRepository(viewerRole: GroupRole.member);
    await tester.pumpWidget(await _harness(groups: groups));
    await tester.pumpAndSettle();

    expect(find.text('You cannot manage group settings'), findsOneWidget);
    expect(find.byKey(const Key('group-settings-save')), findsNothing);
    expect(groups.settingsUpdates, isEmpty);
  });
}

Future<Widget> _harness({required _FakeGroupRepository groups}) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final groupProvider = GroupProvider(repository: groups);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
    ],
    child: const MaterialApp(home: GroupSettingsPage(groupId: 'g1')),
  );
}

final class _FakeGroupRepository implements GroupRepository {
  _FakeGroupRepository({required this.viewerRole});

  final GroupRole viewerRole;
  final settingsUpdates = <GroupSettingsUpdate>[];
  Group _group = group;

  static final group = Group(
    id: 'g1',
    name: 'Anime',
    description: 'Old',
    type: GroupType.public,
    animeId: null,
    founderId: 'alice',
    membersCount: 2,
    maxMembers: 100,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: 'Old rules',
    activityScore: 0,
  );

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(_group);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(_group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: viewerRole));

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
      Success(<Group>[_group]);

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
  }) async {
    settingsUpdates.add(settings);
    _group = _group.copyWith(
      name: settings.name,
      description: settings.description,
      rules: settings.rules,
      joinPolicy: settings.joinPolicy,
      isSearchable: settings.isSearchable,
    );
    return const Success<void>(null);
  }

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
}
