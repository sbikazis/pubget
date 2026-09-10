import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_shell_drawer.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/notifications/providers/unread_engine.dart';
import 'package:pubget/features/notifications/widgets/unread_badge.dart';
import 'package:pubget/features/private_chat/models/private_chat_models.dart';

void main() {
  test('group unread uses lastMessageAt vs member lastReadAt', () {
    final unread = Group(
      id: 'g1',
      name: 'Unread',
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
      lastActivityAt: DateTime(2026, 2, 2),
      viewerLastReadAt: DateTime(2026, 2, 1),
    );
    final read = Group(
      id: 'g2',
      name: 'Read',
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
      lastActivityAt: DateTime(2026, 2, 1),
      viewerLastReadAt: DateTime(2026, 2, 2),
    );
    expect(unread.hasUnread, isTrue);
    expect(read.hasUnread, isFalse);
  });

  test('private unread uses lastMessageAt vs participant lastReadAt', () {
    final chat = PrivateChatSummary(
      id: 'c1',
      participantIds: const <String>['alice', 'bob'],
      userA: 'alice',
      userB: 'bob',
      participants: <String, PrivateChatParticipant>{
        'alice': PrivateChatParticipant(
          displayName: 'Alice',
          avatarUrl: '',
          lastReadAt: DateTime(2026, 2, 1),
        ),
        'bob': const PrivateChatParticipant(
          displayName: 'Bob',
          avatarUrl: '',
        ),
      },
      lastMessageAt: DateTime(2026, 2, 2),
      lastMessageText: 'hey',
      lastMessageSenderId: 'bob',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(chat.isUnreadFor('alice'), isTrue);
    expect(chat.isUnreadFor('bob'), isFalse);
  });

  test('shared UnreadEngine keeps drawer and tab counts identical', () {
    final unread = UnreadEngine()
      ..sync(notifications: 4, groups: 2, privateChats: 3);
    expect(unread.notifications, 4);
    expect(unread.groups, 2);
    expect(unread.privateChats, 3);
    expect(AppShellDrawer.unreadCountFor('notifications', unread), 4);
    expect(AppShellDrawer.unreadCountFor('groups', unread), 2);
    expect(AppShellDrawer.unreadCountFor('joined', unread), 2);
    expect(AppShellDrawer.unreadCountFor('private', unread), 3);
    unread.sync(notifications: 0, groups: 0, privateChats: 0);
    expect(unread.notifications, 0);
    expect(AppShellDrawer.unreadCountFor('notifications', unread), 0);
  });

  test('group provider unreadCount follows joined lastReadAt data', () async {
    final now = DateTime(2026, 3, 3);
    final repository = _UnreadGroupRepository(
      groups: <Group>[
        Group(
          id: 'unread',
          name: 'Unread crew',
          description: '',
          type: GroupType.public,
          animeId: null,
          founderId: 'other',
          membersCount: 2,
          maxMembers: 100,
          joinPolicy: JoinPolicy.open,
          isSearchable: true,
          createdAt: DateTime(2026),
          chatBackgroundUrl: null,
          rules: '',
          activityScore: 0,
          lastActivityAt: now,
          viewerLastReadAt: now.subtract(const Duration(hours: 1)),
        ),
        Group(
          id: 'read',
          name: 'Read crew',
          description: '',
          type: GroupType.public,
          animeId: null,
          founderId: 'other',
          membersCount: 2,
          maxMembers: 100,
          joinPolicy: JoinPolicy.open,
          isSearchable: true,
          createdAt: DateTime(2026),
          chatBackgroundUrl: null,
          rules: '',
          activityScore: 0,
          lastActivityAt: now.subtract(const Duration(hours: 2)),
          viewerLastReadAt: now,
        ),
      ],
    );
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.openJoined('alice');
    await Future<void>.delayed(Duration.zero);
    expect(provider.unreadCount, 1);

    repository.groups = repository.groups
        .map(
          (group) => Group(
            id: group.id,
            name: group.name,
            description: group.description,
            type: group.type,
            animeId: group.animeId,
            founderId: group.founderId,
            membersCount: group.membersCount,
            maxMembers: group.maxMembers,
            joinPolicy: group.joinPolicy,
            isSearchable: group.isSearchable,
            createdAt: group.createdAt,
            chatBackgroundUrl: group.chatBackgroundUrl,
            rules: group.rules,
            activityScore: group.activityScore,
            lastActivityAt: group.lastActivityAt,
            viewerLastReadAt: now.add(const Duration(minutes: 1)),
          ),
        )
        .toList(growable: false);
    await provider.closeJoined();
    await provider.openJoined('alice');
    await Future<void>.delayed(Duration.zero);
    expect(provider.unreadCount, 0);
  });

  testWidgets('shell tabs and drawer read the same UnreadEngine', (tester) async {
    final unread = UnreadEngine()
      ..sync(notifications: 5, groups: 2, privateChats: 3);
    await tester.pumpWidget(
      ChangeNotifierProvider<UnreadEngine>.value(
        value: unread,
        child: AppShellScope(
          openDrawer: () {},
          currentTab: AppShellTab.discover,
          child: const MaterialApp(
            home: Scaffold(
              drawer: AppShellDrawer(),
              body: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    expect(AppShellDrawer.unreadCountFor('groups', unread), unread.groups);
    expect(AppShellDrawer.unreadCountFor('joined', unread), unread.groups);
    expect(AppShellDrawer.unreadCountFor('private', unread), unread.privateChats);
    expect(
      AppShellDrawer.unreadCountFor('notifications', unread),
      unread.notifications,
    );
    expect(find.byType(UnreadBadge), findsWidgets);
  });
}

final class _UnreadGroupRepository implements GroupRepository {
  _UnreadGroupRepository({required this.groups});

  List<Group> groups;

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(groups.first);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(groups.first);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: GroupRole.member));

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
      Success(groups);

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      Success(groups);

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) =>
      Stream.value(Success(groups));

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

