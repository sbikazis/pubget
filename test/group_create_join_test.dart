import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_shell_create_sheet.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/data/group_fuzzy.dart';
import 'package:pubget/features/groups/data/group_image_uploader.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/create_group_wizard_page.dart';
import 'package:pubget/features/groups/screens/group_anime_picker_page.dart';
import 'package:pubget/features/groups/screens/group_character_picker_page.dart';
import 'package:pubget/features/groups/screens/group_details_page.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';

void main() {
  test('create/join chrome is bilingual', () {
    expect(AppStrings.english.joinedGroupsTab, 'Joined groups');
    expect(AppStrings.arabic.joinedGroupsTab, 'المجموعات المنضم إليها');
    expect(AppStrings.english.createdGroupsTab, 'Groups I created');
    expect(AppStrings.arabic.characterReserved, contains('محجوزة'));
    expect(AppStrings.english.groupCapacityReached, 'This group is at capacity');
  });

  test('fuzzy matcher accepts light misspellings', () {
    expect(GroupFuzzy.matches('friren', 'Frieren'), isTrue);
    expect(GroupFuzzy.matches('naruto', 'One Piece'), isFalse);
    expect(GroupFuzzy.matches('lufy', 'Monkey D. Luffy'), isTrue);
  });

  test('group image URLs must be remote http(s), never local paths', () {
    expect(isRemoteHttpUrl('https://example.test/a.png'), isTrue);
    expect(isRemoteHttpUrl('http://cdn.test/a.png'), isTrue);
    expect(isRemoteHttpUrl('/data/user/0/cache/x.jpg'), isFalse);
    expect(isRemoteHttpUrl('file:///tmp/x.jpg'), isFalse);
    expect(isRemoteHttpUrl(''), isFalse);
  });

  testWidgets('create-group opens the type sheet', (tester) async {
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
    await tester.tap(find.byKey(const Key('create-group')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-group-type-public')), findsOneWidget);
    expect(
      find.byKey(const Key('create-group-type-animeRoleplay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('create-group-type-openRoleplay')),
      findsOneWidget,
    );
  });

  testWidgets('public create confirm stays disabled until avatar and name', (
    tester,
  ) async {
    await tester.pumpWidget(await _wizardHarness(GroupType.public));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('group-create-name')), findsOneWidget);
    expect(tester.widget<PubgetPrimaryButton>(
      find.byKey(const Key('group-create-confirm')),
    ).onPressed, isNull);

    await tester.ensureVisible(find.byKey(const Key('group-create-image-url')));
    await tester.enterText(
      find.byKey(const Key('group-create-image-url')),
      'https://example.test/a.png',
    );
    await tester.ensureVisible(find.byKey(const Key('group-create-name')));
    await tester.enterText(find.byKey(const Key('group-create-name')), 'Crew');
    await tester.pump();

    final enabled = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('group-create-confirm')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('anime roleplay confirm stays disabled without character', (
    tester,
  ) async {
    await tester.pumpWidget(await _wizardHarness(GroupType.animeRoleplay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('group-create-name')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('group-create-image-url')));
    await tester.enterText(
      find.byKey(const Key('group-create-image-url')),
      'https://example.test/a.png',
    );
    await tester.ensureVisible(find.byKey(const Key('group-create-name')));
    await tester.enterText(find.byKey(const Key('group-create-name')), 'Crew');
    await tester.pump();
    expect(find.byKey(const Key('group-create-pick-anime')), findsOneWidget);
    expect(find.byKey(const Key('group-create-pick-character')), findsNothing);
    final confirm = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('group-create-confirm')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('anime picker shows popular titles and a no-results state', (
    tester,
  ) async {
    final repository = FakeAnimeRepository(
      filterSearchByQuery: true,
      page: AnimePage(items: <Anime>[sampleAnime()], page: 1),
    );
    final list = AnimeListProvider(repository: repository);
    await tester.pumpWidget(
      ChangeNotifierProvider<AnimeListProvider>.value(
        value: list,
        child: const MaterialApp(home: GroupAnimePickerPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Frieren'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('group-anime-search')), 'zzzzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Frieren'), findsNothing);
    expect(find.byKey(const Key('group-anime-empty')), findsOneWidget);
  });

  testWidgets('reserved character stays locked without revealing the owner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: GroupCharacterPickerPage(
          reservedKeys: const <String>{'hero'},
          catalog: const <RoleplayCharacter>[
            RoleplayCharacter(key: 'hero', name: 'The Hero', avatarUrl: ''),
            RoleplayCharacter(key: 'rival', name: 'The Rival', avatarUrl: ''),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-character-hero')));
    await tester.pump();
    expect(
      find.text(AppStrings.english.characterReserved),
      findsOneWidget,
    );
    expect(find.textContaining('alice'), findsNothing);
  });

  testWidgets('banned visitor does not see join', (tester) async {
    await tester.pumpWidget(await _detailsHarness(banned: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Join group'), findsNothing);
    expect(find.text(AppStrings.english.bannedFromGroup), findsWidgets);
  });

  testWidgets('full group shows capacity instead of join', (tester) async {
    await tester.pumpWidget(await _detailsHarness(full: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Join group'), findsNothing);
    expect(find.text(AppStrings.english.groupCapacityReached), findsOneWidget);
  });
}

Future<Widget> _wizardHarness(GroupType type) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final groups = GroupProvider(repository: _JourneyGroupRepository());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groups),
    ],
    child: MaterialApp(home: CreateGroupWizardPage(type: type)),
  );
}

Future<Widget> _detailsHarness({bool banned = false, bool full = false}) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  final groups = GroupProvider(
    repository: _JourneyGroupRepository(banned: banned, full: full),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<GroupProvider>.value(value: groups),
    ],
    child: const MaterialApp(home: GroupDetailsPage(groupId: 'g1')),
  );
}

final class _JourneyGroupRepository implements GroupRepository {
  _JourneyGroupRepository({this.banned = false, this.full = false});

  final bool banned;
  final bool full;

  Group get group => Group(
    id: 'g1',
    name: 'Rising Crew',
    description: 'A roleplay room',
    type: GroupType.public,
    animeId: null,
    founderId: 'other',
    membersCount: full ? 40 : 4,
    maxMembers: 40,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: 'Be kind',
    activityScore: 1,
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
  }) async => Success(banned);

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

