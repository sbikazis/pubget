import 'dart:typed_data';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';
import 'profile_repository.dart';

final class UnavailableProfileRepository implements ProfileRepository {
  const UnavailableProfileRepository(this.message);

  final String message;

  @override
  Future<Result<PublicProfile>> getPublicProfile(String userId) async =>
      FailureResult<PublicProfile>(UnknownError(message));

  @override
  Future<Result<PubgetUser>> getOwnProfile(String userId) async =>
      FailureResult<PubgetUser>(UnknownError(message));

  @override
  Future<Result<PubgetUser>> updateProfile(
    String userId,
    ProfileUpdate update,
  ) async => FailureResult<PubgetUser>(UnknownError(message));

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async => FailureResult<String>(UnknownError(message));
}
