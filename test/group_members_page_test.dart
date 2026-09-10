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
      groupMemberMenuActions(
        canManageMembers: false,
        canChangeRole: true,
        canTransfer: true,
      ),
      <String>['role', 'transfer'],
    );
    expect(
      groupMemberMenuActions(
        canManageMembers: true,
        canChangeRole: true,
        canTransfer: true,
      ),
      <String>['role', 'kick', 'ban', 'transfer'],
    );
  });

  testWidgets('change-role dialog sends each assignable rank to the callable', (
    tester,
  ) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: PubgetRank.mikado);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    final assignable = assignableRanksUnderCeiling(
      actor: PubgetRank.mikado,
      targetCurrent: PubgetRank.ronin,
    );
    for (final role in assignable) {
      members.changeRoleCalls.clear();
      await tester.tap(find.byKey(const Key('member-menu-bob')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change role'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('pick-role-${role.name}')));
      await tester.pumpAndSettle();
      expect(members.changeRoleCalls, <PubgetRank>[role]);
    }
    expect(find.byKey(const Key('pick-role-mikado')), findsNothing);
  });

  testWidgets('unauthorized member does not see admin menu on equal ranks', (
    tester,
  ) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(
      viewerRole: PubgetRank.ronin,
      founderId: 'other-founder',
    );
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-menu-bob')), findsNothing);
  });

  testWidgets('banned users action is hidden without kickBan', (
    tester,
  ) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(
      viewerRole: PubgetRank.ronin,
      founderId: 'other-founder',
    );
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Banned users'), findsNothing);
  });

  testWidgets('authorized member can open banned users', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: PubgetRank.mikado);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Banned users'), findsOneWidget);
  });

  testWidgets('authorized member sees kick and ban', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: PubgetRank.mikado);
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
  final changeRoleCalls = <PubgetRank>[];

  @override
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  }) async {
    return const Success<List<GroupMember>>([
      GroupMember(uid: 'alice', role: PubgetRank.mikado),
      GroupMember(uid: 'bob', role: PubgetRank.ronin),
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
    required PubgetRank role,
    required Set<GroupPermission> permissions,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required PubgetRank role,
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

  @override
  Future<Result<List<GroupBan>>> getBans(String groupId) async =>
      const Success<List<GroupBan>>([]);

  @override
  Future<Result<void>> unbanMember({
    required String groupId,
    required String uid,
  }) async => const Success<void>(null);
}

final class _FakeGroupRepository implements GroupRepository {
  _FakeGroupRepository({
    required this.viewerRole,
    this.founderId = 'alice',
  });

  final PubgetRank viewerRole;
  final String founderId;

  Group get group => Group(
    id: 'g1',
    name: 'Anime',
    description: '',
    type: GroupType.public,
    animeId: null,
    founderId: founderId,
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
      Success(<Group>[group]);

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
