import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_members_provider.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_members_repository.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/group_members_page.dart';

import 'authentication_test_support.dart';

void main() {
  test('kick and ban stay out of the menu without manageMembers', () {
    expect(
      groupMemberMenuActions(canManageMembers: false),
      <String>['role', 'transfer'],
    );
    expect(
      groupMemberMenuActions(canManageMembers: true),
      <String>['role', 'kick', 'ban', 'transfer'],
    );
  });

  testWidgets('change-role dialog sends each picked role to the callable', (
    tester,
  ) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: GroupRole.founder);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    for (final role in GroupRole.values) {
      members.changeRoleCalls.clear();
      await tester.tap(find.byKey(const Key('member-menu-bob')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change role'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('pick-role-${role.name}')));
      await tester.pumpAndSettle();
      expect(members.changeRoleCalls, <GroupRole>[role]);
    }
  });

  testWidgets('unauthorized member does not see kick or ban', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: GroupRole.member);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-menu-bob')));
    await tester.pumpAndSettle();

    expect(find.text('Change role'), findsOneWidget);
    expect(find.text('Kick'), findsNothing);
    expect(find.text('Ban'), findsNothing);
    expect(find.text('Transfer ownership'), findsOneWidget);
  });

  testWidgets('authorized member sees kick and ban', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: GroupRole.founder);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-menu-bob')));
    await tester.pumpAndSettle();

    expect(find.text('Kick'), findsOneWidget);
    expect(find.text('Ban'), findsOneWidget);
  });
}

Future<Widget> _harness({
  required _FakeMembersRepository members,
  required _FakeGroupRepository groups,
}) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final membersProvider = GroupMembersProvider(repository: members);
  final groupProvider = GroupProvider(repository: groups);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
      ChangeNotifierProvider<GroupMembersProvider>.value(value: membersProvider),
    ],
    child: const MaterialApp(home: GroupMembersPage(groupId: 'g1')),
  );
}

final class _FakeMembersRepository implements GroupMembersRepository {
  final changeRoleCalls = <GroupRole>[];

  @override
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  }) async {
    return const Success<List<GroupMember>>([
      GroupMember(uid: 'alice', role: GroupRole.founder),
      GroupMember(uid: 'bob', role: GroupRole.member),
    ]);
  }

  @override
  Future<Result<List<JoinRequest>>> getJoinRequests(String groupId) async =>
      const Success<List<JoinRequest>>([]);

  @override
  Future<Result<List<GroupRoleDefinition>>> getRoles(String groupId) async =>
      const Success<List<GroupRoleDefinition>>([]);

  @override
  Future<Result<String>> createInvite({
    required String groupId,
    required String toUid,
  }) async => const Success<String>('invite-1');

  @override
  Future<Result<void>> updateRolePermissions({
    required String groupId,
    required GroupRole role,
    required Set<GroupPermission> permissions,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required GroupRole role,
  }) async {
    changeRoleCalls.add(role);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> kickMember({
    required String groupId,
    required String uid,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> banMember({
    required String groupId,
    required String uid,
  }) async => const Success<void>(null);

  @override
  Future<Result<String>> prepareOwnershipTransfer({
    required String groupId,
    required String uid,
  }) async => const Success<String>('token');

  @override
  Future<Result<void>> transferOwnership({
    required String groupId,
    required String uid,
    required String confirmationToken,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> acceptJoinRequest({
    required String groupId,
    required String uid,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> rejectJoinRequest({
    required String groupId,
    required String uid,
  }) async => const Success<void>(null);
}

final class _FakeGroupRepository implements GroupRepository {
  _FakeGroupRepository({required this.viewerRole});

  final GroupRole viewerRole;

  static final group = Group(
    id: 'g1',
    name: 'Anime',
    description: '',
    type: GroupType.public,
    animeId: null,
    founderId: 'alice',
    membersCount: 2,
    maxMembers: 100,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: '',
    activityScore: 0,
  );

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(group);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: viewerRole));

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
      Success(<Group>[group]);

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      const Success(<Group>[]);
}
