import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';

void main() {
  test(
    'optimistic leave hides membership before the server responds',
    () async {
      final repository = _FakeGroupRepository();
      final provider = GroupProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.load(groupId: 'g1', userId: 'alice');

      provider.leaveOptimistically('g1');

      expect(provider.isMember, isFalse);
      expect(provider.leaveState, LeaveState.pending);
      repository.leaveCompleter.complete(const Success<void>(null));
      await provider.leaveOperation;
      expect(provider.leaveState, LeaveState.confirmed);
      expect(provider.isMember, isFalse);
    },
  );

  test(
    'optimistic leave restores membership when the callable fails',
    () async {
      final repository = _FakeGroupRepository();
      final provider = GroupProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.load(groupId: 'g1', userId: 'alice');

      provider.leaveOptimistically('g1');
      repository.leaveCompleter.complete(
        const FailureResult<void>(NetworkError('offline')),
      );
      await provider.leaveOperation;

      expect(provider.leaveState, LeaveState.reverted);
      expect(provider.membership?.uid, 'alice');
      expect(provider.failure?.message, 'offline');
    },
  );

  test('loadJoined uses memberships, not the discover search list', () async {
    final repository = _FakeGroupRepository();
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.search('');
    expect(provider.searchResults.single.id, 'g1');

    await provider.loadJoined('alice');
    expect(provider.joinedGroups, isEmpty);
    expect(provider.joinedState, LoadingState.empty);
  });

  test('join success stores the follow-up membership, not a stub uid', () async {
    final repository = _FakeGroupRepository(
      membershipAfterJoin: const GroupMember(
        uid: 'alice',
        role: GroupRole.commander,
      ),
    );
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.join('g1', userId: 'alice');

    expect(result.isSuccess, isTrue);
    expect(provider.membership?.uid, 'alice');
    expect(provider.membership?.uid, isNotEmpty);
    expect(provider.membership?.role, GroupRole.commander);
    expect(provider.isMember, isTrue);
    expect(provider.isFounder, isFalse);
    expect(provider.canManageMembers, isTrue);
    expect(provider.canManageSettings, isFalse);
    expect(repository.membershipReads, <String>['g1:alice']);
  });

  test('join membership drives details-vs-chat: members are not founders', () async {
    final repository = _FakeGroupRepository(
      membershipAfterJoin: const GroupMember(
        uid: 'alice',
        role: GroupRole.member,
      ),
    );
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.join('g1', userId: 'alice');

    // GroupDetailsPage redirects to chat when isMember && !isFounder.
    expect(provider.isMember, isTrue);
    expect(provider.isFounder, isFalse);
    expect(provider.membership?.uid, 'alice');
  });

  test('requestToJoin does not fabricate a membership', () async {
    final repository = _FakeGroupRepository();
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.requestToJoin('g1');

    expect(result.isSuccess, isTrue);
    expect(provider.membership, isNull);
    expect(provider.isMember, isFalse);
    expect(repository.membershipReads, isEmpty);
  });

  test('join does not keep a stub when the membership read fails', () async {
    final repository = _FakeGroupRepository(failMembershipRead: true);
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.join('g1', userId: 'alice');

    expect(result.isSuccess, isFalse);
    expect(provider.membership, isNull);
    expect(provider.membership?.uid, isNot(''));
    expect(provider.state, LoadingState.error);
  });

  test('updateSettings persists callable fields onto the group', () async {
    final repository = _FakeGroupRepository();
    final provider = GroupProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load(groupId: 'g1', userId: 'alice');

    final result = await provider.updateSettings(
      groupId: 'g1',
      settings: const GroupSettingsUpdate(
        name: 'Renamed',
        description: 'New desc',
        rules: 'Be kind',
        joinPolicy: JoinPolicy.approval,
        isSearchable: false,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(repository.settingsUpdates.single.name, 'Renamed');
    expect(repository.settingsUpdates.single.joinPolicy, JoinPolicy.approval);
    expect(provider.group?.name, 'Renamed');
    expect(provider.group?.description, 'New desc');
    expect(provider.group?.rules, 'Be kind');
    expect(provider.group?.joinPolicy, JoinPolicy.approval);
    expect(provider.group?.isSearchable, isFalse);
  });
}

final class _FakeGroupRepository implements GroupRepository {
  _FakeGroupRepository({
    this.membershipAfterJoin,
    this.failMembershipRead = false,
  });

  final leaveCompleter = Completer<Result<void>>();
  final GroupMember? membershipAfterJoin;
  final bool failMembershipRead;
  final membershipReads = <String>[];
  final settingsUpdates = <GroupSettingsUpdate>[];
  Group _group = group;

  static final group = Group(
    id: 'g1',
    name: 'Anime',
    description: '',
    type: GroupType.public,
    animeId: null,
    founderId: 'founder',
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
  Future<Result<Group>> getGroup(String groupId) async => Success(_group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async {
    membershipReads.add('$groupId:$userId');
    if (failMembershipRead) {
      return const FailureResult(UnknownError('membership missing'));
    }
    return Success(
      membershipAfterJoin ??
          GroupMember(uid: userId, role: GroupRole.member),
    );
  }

  @override
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> leaveGroup(String groupId) => leaveCompleter.future;

  @override
  Future<Result<void>> requestToJoin({required String groupId}) async =>
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
}
