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
import 'package:pubget/features/groups/screens/group_bans_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('authorized user can unban a banned member', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: GroupRole.founder);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    expect(find.text('carol'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unban-carol')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unban').last);
    await tester.pumpAndSettle();

    expect(members.unbanCalls, <String>['carol']);
    expect(find.text('carol'), findsNothing);
    expect(find.text('No banned users'), findsOneWidget);
  });

  testWidgets('unauthorized user cannot unban', (tester) async {
    final members = _FakeMembersRepository();
    final groups = _FakeGroupRepository(viewerRole: GroupRole.member);
    await tester.pumpWidget(
      await _harness(members: members, groups: groups),
    );
    await tester.pumpAndSettle();

    expect(find.text('You cannot manage bans'), findsOneWidget);
    expect(find.byKey(const Key('unban-carol')), findsNothing);
    expect(members.unbanCalls, isEmpty);
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
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(
        value: GroupProvider(repository: groups),
      ),
      ChangeNotifierProvider<GroupMembersProvider>.value(
        value: GroupMembersProvider(repository: members),
      ),
    ],
    child: const MaterialApp(home: GroupBansPage(groupId: 'g1')),
  );
}

final class _FakeMembersRepository implements GroupMembersRepository {
  final unbanCalls = <String>[];
  var _bans = <GroupBan>[
    const GroupBan(uid: 'carol', bannedByUid: 'alice'),
  ];

  @override
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  }) async => const Success<List<GroupMember>>([]);

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
  }) async => const Success<void>(null);

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
      Success<List<GroupBan>>(List<GroupBan>.from(_bans));

  @override
  Future<Result<void>> unbanMember({
    required String groupId,
    required String uid,
  }) async {
    unbanCalls.add(uid);
    _bans = _bans.where((ban) => ban.uid != uid).toList(growable: false);
    return const Success<void>(null);
  }
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
}
