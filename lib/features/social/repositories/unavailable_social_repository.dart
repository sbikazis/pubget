import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/social_models.dart';
import 'social_repository.dart';

final class UnavailableSocialRepository implements SocialRepository {
  const UnavailableSocialRepository(this.message);

  final String message;

  @override
  Future<Result<SocialSnapshot>> getSnapshot(String userId) async =>
      FailureResult<SocialSnapshot>(UnknownError(message));

  @override
  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  }) async => FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> sendFriendRequest({required String toUserId}) async =>
      FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required String response,
  }) async => FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> removeFriend({required String otherUserId}) async =>
      FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> blockUser({required String otherUserId}) async =>
      FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> unblockUser({required String otherUserId}) async =>
      FailureResult<void>(UnknownError(message));
}
