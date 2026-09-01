import 'dart:typed_data';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';
import 'package:pubget/features/social/models/public_profile.dart';
import 'package:pubget/features/social/models/social_models.dart';
import 'package:pubget/features/social/repositories/profile_repository.dart';
import 'package:pubget/features/social/repositories/social_repository.dart';

final class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    PubgetUser? ownProfile,
    PublicProfile? publicProfile,
    this.failure,
  }) : ownProfile =
           ownProfile ??
           PubgetUser(
             id: 'user-1',
             email: 'fan@example.com',
             username: 'anime_fan',
             createdAt: DateTime(2026),
             isProfileCompleted: true,
           ),
       publicProfile =
           publicProfile ??
           const PublicProfile(
             uid: 'user-2',
             username: 'other_fan',
             totalRespect: 12,
             fansCount: 2,
           );

  PubgetUser ownProfile;
  PublicProfile publicProfile;
  Failure? failure;
  ProfileUpdate? lastUpdate;

  @override
  Future<Result<PubgetUser>> getOwnProfile(String userId) async =>
      failure == null
      ? Success<PubgetUser>(ownProfile)
      : FailureResult<PubgetUser>(failure!);

  @override
  Future<Result<PublicProfile>> getPublicProfile(String userId) async =>
      failure == null
      ? Success<PublicProfile>(publicProfile)
      : FailureResult<PublicProfile>(failure!);

  @override
  Future<Result<PubgetUser>> updateProfile(
    String userId,
    ProfileUpdate update,
  ) async {
    lastUpdate = update;
    ownProfile = ownProfile.copyWith(
      bio: update.bio,
      favoriteAnimeIds: update.favoriteAnimeIds,
      profileVisibility: update.profileVisibility,
      activityVisibility: update.activityVisibility,
      whoCanMessageMe: update.whoCanMessageMe,
    );
    return Success<PubgetUser>(ownProfile);
  }

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async => const Success<String>('https://example.test/avatar.jpg');
}

final class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({this.snapshot = const SocialSnapshot(), this.failure});

  SocialSnapshot snapshot;
  Failure? failure;
  int respectCalls = 0;
  int friendRequestCalls = 0;
  int blockCalls = 0;

  Result<T> _result<T>(T value) =>
      failure == null ? Success<T>(value) : FailureResult<T>(failure!);

  @override
  Future<Result<SocialSnapshot>> getSnapshot(String userId) async =>
      _result<SocialSnapshot>(snapshot);

  @override
  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  }) async {
    respectCalls++;
    return _result<void>(null);
  }

  @override
  Future<Result<void>> sendFriendRequest({required String toUserId}) async {
    friendRequestCalls++;
    return _result<void>(null);
  }

  @override
  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required String response,
  }) async => _result<void>(null);

  @override
  Future<Result<void>> removeFriend({required String otherUserId}) async =>
      _result<void>(null);

  @override
  Future<Result<void>> blockUser({required String otherUserId}) async {
    blockCalls++;
    snapshot = SocialSnapshot(
      friendships: <Friendship>[
        ...snapshot.friendships.where(
          (item) =>
              !((item.userA == 'user-1' && item.userB == otherUserId) ||
                  (item.userA == otherUserId && item.userB == 'user-1')),
        ),
        Friendship(
          userA: 'user-1',
          userB: otherUserId,
          status: FriendshipStatus.blocked,
          requestedBy: 'user-1',
          blockedBy: 'user-1',
        ),
      ],
      givenRespect: snapshot.givenRespect,
      receivedRespect: snapshot.receivedRespect,
    );
    return _result<void>(null);
  }

  @override
  Future<Result<void>> unblockUser({required String otherUserId}) async =>
      _result<void>(null);
}
