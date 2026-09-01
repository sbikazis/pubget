import '../../../core/errors/result.dart';
import '../models/social_models.dart';

abstract interface class SocialRepository {
  Future<Result<SocialSnapshot>> getSnapshot(String userId);

  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  });

  Future<Result<void>> sendFriendRequest({required String toUserId});

  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required String response,
  });

  Future<Result<void>> removeFriend({required String otherUserId});

  Future<Result<void>> blockUser({required String otherUserId});

  Future<Result<void>> unblockUser({required String otherUserId});
}
