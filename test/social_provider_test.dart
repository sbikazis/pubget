import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/social/models/social_models.dart';
import 'package:pubget/features/social/providers/social_provider.dart';

import 'social_test_support.dart';

void main() {
  test('prevents self-respect before calling the repository', () async {
    final repository = FakeSocialRepository();
    final provider = SocialProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load('user-1');

    final result = await provider.giveRespect(toUserId: 'user-1', value: 7);

    expect(result.failureOrNull, isA<ValidationError>());
    expect(repository.respectCalls, 0);
    expect(provider.state, LoadingState.error);
  });

  test(
    'accepts only bounded respect and derives fans at five or more',
    () async {
      final repository = FakeSocialRepository(
        snapshot: const SocialSnapshot(
          receivedRespect: <RespectRelation>[
            RespectRelation(fromUserId: 'a', toUserId: 'user-1', value: 4),
            RespectRelation(fromUserId: 'b', toUserId: 'user-1', value: 5),
            RespectRelation(fromUserId: 'c', toUserId: 'user-1', value: 7),
          ],
        ),
      );
      final provider = SocialProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.load('user-1');

      expect(provider.fans.length, 2);
      expect(
        (await provider.giveRespect(
          toUserId: 'user-2',
          value: 8,
        )).failureOrNull,
        isA<ValidationError>(),
      );
      expect(repository.respectCalls, 0);
      expect(
        await provider.giveRespect(toUserId: 'user-2', value: 6),
        isNotNull,
      );
      expect(repository.respectCalls, 1);
    },
  );

  test('separates incoming and outgoing deterministic relationships', () async {
    final repository = FakeSocialRepository(
      snapshot: const SocialSnapshot(
        friendships: <Friendship>[
          Friendship(
            userA: 'user-1',
            userB: 'user-2',
            status: FriendshipStatus.pending,
            requestedBy: 'user-2',
          ),
          Friendship(
            userA: 'user-1',
            userB: 'user-3',
            status: FriendshipStatus.pending,
            requestedBy: 'user-1',
          ),
        ],
      ),
    );
    final provider = SocialProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load('user-1');

    expect(provider.incomingRequests.single.requestedBy, 'user-2');
    expect(provider.outgoingRequests.single.otherUserId('user-1'), 'user-3');
  });
}
