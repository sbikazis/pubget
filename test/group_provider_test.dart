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
}

final class _FakeGroupRepository implements GroupRepository {
  final leaveCompleter = Completer<Result<void>>();

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
  Future<Result<Group>> getGroup(String groupId) async => Success(group);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: GroupRole.member));

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
}
