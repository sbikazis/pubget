import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../models/pubget_user.dart';

abstract interface class UserRepository {
  Future<Result<PubgetUser>> createUserProfile(PubgetUser user);

  Future<Result<PubgetUser?>> getUserProfile(String userId);

  Future<Result<PubgetUser>> updateUserProfile(PubgetUser user);

  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });
}
