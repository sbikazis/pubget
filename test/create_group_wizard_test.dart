import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/presentation/pages/create_group_wizard/create_group_wizard_page.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('public wizard publishes with welcome and background fields', (
    tester,
  ) async {
    final repository = _CapturingGroupRepository();
    await tester.pumpWidget(await _wizardHarness(repository));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Step 1 — identity.
    await tester.ensureVisible(find.byKey(const Key('group-create-image-url')));
    await tester.enterText(
      find.byKey(const Key('group-create-image-url')),
      'https://example.test/a.png',
    );
    await tester.ensureVisible(find.byKey(const Key('group-create-name')));
    await tester.enterText(find.byKey(const Key('group-create-name')), 'Crew');
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 2 — type (already public).
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 3 — rules & privacy (default capacity 100 is valid).
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 4 — customization: welcome message + chat background.
    await tester.ensureVisible(
      find.byKey(const Key('group-create-welcome-message')),
    );
    await tester.enterText(
      find.byKey(const Key('group-create-welcome-message')),
      'Welcome to the crew!',
    );
    await tester.ensureVisible(find.byKey(const Key('group-create-chat-background')));
    await tester.enterText(
      find.byKey(const Key('group-create-chat-background')),
      'https://cdn.example.com/bg.jpg',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 5 — permissions (view only).
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 6 — preview.
    await tester.tap(find.byKey(const Key('group-create-next')));
    await tester.pumpAndSettle();

    // Step 7 — publish.
    await tester.ensureVisible(
      find.byKey(const Key('group-create-final-publish')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-create-final-publish')));
    await tester.pumpAndSettle();

    expect(repository.lastDraft, isNotNull);
    final draft = repository.lastDraft!;
    expect(draft.name, 'Crew');
    expect(draft.imageUrl, 'https://example.test/a.png');
    expect(draft.type, GroupType.public);
    expect(draft.welcomeMessage, 'Welcome to the crew!');
    expect(draft.chatBackgroundUrl, 'https://cdn.example.com/bg.jpg');
  });
}

Future<Widget> _wizardHarness(GroupRepository repository) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final groups = GroupProvider(repository: repository);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groups),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      home: CreateGroupWizardPage(type: GroupType.public),
    ),
  );
}

final class _CapturingGroupRepository implements GroupRepository {
  GroupDraft? lastDraft;

  Group get group => Group(
    id: 'g1',
    name: 'Rising Crew',
    description: 'A roleplay room',
    type: GroupType.public,
    animeId: null,
    founderId: 'other',
    membersCount: 1,
    maxMembers: 40,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: 'Be kind',
    activityScore: 1,
  );

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async {
    lastDraft = draft;
    return Success(group);
  }

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => const Success(null);

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