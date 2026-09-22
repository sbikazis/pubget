import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../models/pubget_user.dart';
import '../models/username_status.dart';

abstract interface class UserRepository {
  Future<Result<PubgetUser>> createUserProfile(PubgetUser user);

  Future<Result<PubgetUser?>> getUserProfile(String userId);

  Future<Result<PubgetUser>> updateUserProfile(PubgetUser user);

  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  /// Instant server-side availability check (spec §3.2). Read-only.
  Future<Result<UsernameStatus>> checkUsernameAvailable(String username);

  /// Server-side reserved-claim of a username before the profile document is
  /// created. Returns the canonical (lowercased) form on success.
  Future<Result<String>> reserveUsername(String username);

  /// Mirrors the account language choice to the server (spec §1.4).
  Future<Result<void>> updateLanguage(String language);
}
