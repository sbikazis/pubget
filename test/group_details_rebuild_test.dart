import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/group_details_page.dart';

import 'authentication_test_support.dart';

void main() {
  test('group chrome copy is bilingual', () {
    expect(AppStrings.english.groupDetails, 'Group details');
    expect(AppStrings.arabic.groupDetails, 'تفاصيل المجموعة');
    expect(AppStrings.english.openChat, 'Open chat');
    expect(AppStrings.arabic.addMembers, 'إضافة أعضاء');
    expect(AppStrings.english.roleLabel('shogun'), 'SHŌGUN');
    expect(AppStrings.english.roleLabel('founder'), 'MIKADO');
    expect(AppStrings.english.roleLabel('ronin'), 'RŌNIN');
    expect(AppStrings.arabic.joinPolicyLabel('approval'), 'بطلب');
  });

  testWidgets('founder details show identity, type, and open chat', (
    tester,
  ) async {
    await tester.pumpWidget(await _harness(role: PubgetRank.mikado));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('group-details-hero')), findsOneWidget);
    expect(find.byKey(const Key('group-hero-badges')), findsOneWidget);
    expect(find.text('MIKADO'), findsNothing);
    expect(find.text('Rising Crew'), findsOneWidget);
    expect(find.text('Anime Roleplay'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('4 members'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Open chat'), findsOneWidget);
    expect(find.byKey(const Key('group-details-disband')), findsOneWidget);
    expect(find.text('Disband group'), findsOneWidget);
    expect(find.text('Manage members'), findsOneWidget);
    expect(find.byKey(const Key('group-promote-section')), findsOneWidget);
    expect(find.byKey(const Key('group-promote-coins')), findsOneWidget);
    expect(find.text('Promote and reach'), findsOneWidget);
    expect(find.text('animeRoleplay'), findsNothing);
  });

  testWidgets('visitor sees join, not chat redirect', (tester) async {
    await tester.pumpWidget(await _harness(role: null));
    await tester.pump();
    await tester.pump();

    expect(find.text('Join group'), findsOneWidget);
    expect(find.text('Open chat'), findsNothing);
    expect(find.text('Disband group'), findsNothing);
  });

  testWidgets('control panel follows live rank permissions', (tester) async {
    for (final role in <PubgetRank>[
      PubgetRank.gokenin,
      PubgetRank.hatamoto,
      PubgetRank.daimyo,
      PubgetRank.shogun,
      PubgetRank.mikado,
    ]) {
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey<PubgetRank>(role),
          child: await _harness(role: role),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Open chat'), findsOneWidget, reason: role.name);
      expect(find.text('Join group'), findsNothing, reason: role.name);
      expect(find.byKey(const Key('group-quick-stats')), findsOneWidget);

      if (role == PubgetRank.gokenin) {
        expect(find.text('Manage members'), findsNothing);
        expect(find.byKey(const Key('group-promote-section')), findsNothing);
      } else {
        expect(find.text('Join requests'), findsOneWidget, reason: role.name);
      }

      if (role.index >= PubgetRank.daimyo.index) {
        expect(find.text('Manage members'), findsOneWidget, reason: role.name);
        expect(find.text('Group games'), findsOneWidget, reason: role.name);
      } else {
        expect(find.text('Group games'), findsNothing, reason: role.name);
      }

      if (role.index >= PubgetRank.shogun.index) {
        expect(find.text('Group settings'), findsOneWidget, reason: role.name);
      } else {
        expect(find.text('Group settings'), findsNothing, reason: role.name);
      }

      if (role == PubgetRank.mikado) {
        expect(find.text('Disband group'), findsOneWidget);
      } else {
        expect(find.text('Disband group'), findsNothing);
      }
    }
  });
}

Future<Widget> _harness({required PubgetRank? role}) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final groups = _FakeGroupRepository(viewerRole: role);
  final groupProvider = GroupProvider(repository: groups);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
    ],
    child: const MaterialApp(home: GroupDetailsPage(groupId: 'g1')),
  );
}

final class _FakeGroupRepository implements GroupRepository {
  _FakeGroupRepository({required this.viewerRole});

  final PubgetRank? viewerRole;

  static final group = Group(
    id: 'g1',
    name: 'Rising Crew',
    description: 'A roleplay room',
    type: GroupType.animeRoleplay,
    animeId: 'a1',
    founderId: 'founder',
    membersCount: 4,
    maxMembers: 40,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: 'Be kind',
    activityScore: 1,
  );

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async {
    if (viewerRole == null) return const Success(null);
    return Success(GroupMember(uid: userId, role: viewerRole!));
  }

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(group);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

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
      const Stream.empty();

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
