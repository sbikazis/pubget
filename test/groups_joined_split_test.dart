import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/groups_home_page.dart';
import 'package:pubget/features/groups/screens/joined_groups_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets(
    'plain memberships appear only under Joined; founded groups appear under Groups',
    (tester) async {
      final authRepository = FakeAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      );
      final auth = AuthProvider(repository: authRepository);
      await auth.initialize();
      addTearDown(authRepository.close);
      addTearDown(auth.dispose);

      final repository = _SplitGroupRepository();
      final groups = GroupProvider(repository: repository);
      addTearDown(groups.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ],
          child: AppShellScope(
            openDrawer: () {},
            child: const MaterialApp(home: GroupsHomePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Founded Group B'), findsOneWidget);
      expect(find.text('Member Group A'), findsNothing);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ],
          child: AppShellScope(
            openDrawer: () {},
            child: const MaterialApp(home: JoinedGroupsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Member Group A'), findsOneWidget);
      expect(find.text('Founded Group B'), findsNothing);
    },
  );
}

Group _group(String id, String name, {required String founderId}) {
  return Group(
    id: id,
    name: name,
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
}

final class _SplitGroupRepository implements GroupRepository {
  final Group founded = _group('b', 'Founded Group B', founderId: 'alice');
  final Group joined = _group('a', 'Member Group A', founderId: 'other');

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(founded);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async =>
      Success(groupId == joined.id ? joined : founded);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(
    GroupMember(
      uid: userId,
      role: groupId == founded.id ? GroupRole.founder : GroupRole.member,
    ),
  );

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
      Success(<Group>[founded]);

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      Success(<Group>[joined]);
}
