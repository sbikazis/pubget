import 'dart:async';
import 'dart:typed_data';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/auth_user.dart';
import '../models/pubget_user.dart';
import 'auth_repository.dart';
import 'user_repository.dart';

final class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository(this.message);

  final String message;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => Stream<AuthUser?>.value(null);

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async => FailureResult<AuthUser>(UnknownError(message));

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async => FailureResult<AuthUser>(UnknownError(message));

  @override
  Future<Result<AuthUser>> signInWithGoogle() async =>
      FailureResult<AuthUser>(UnknownError(message));

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async =>
      FailureResult<void>(UnknownError(message));

  @override
  Future<Result<void>> signOut() async => const Success<void>(null);
}

final class UnavailableUserRepository implements UserRepository {
  const UnavailableUserRepository(this.message);

  final String message;

  @override
  Future<Result<PubgetUser>> createUserProfile(PubgetUser user) async =>
      FailureResult<PubgetUser>(UnknownError(message));

  @override
  Future<Result<PubgetUser?>> getUserProfile(String userId) async =>
      FailureResult<PubgetUser?>(UnknownError(message));

  @override
  Future<Result<PubgetUser>> updateUserProfile(PubgetUser user) async =>
      FailureResult<PubgetUser>(UnknownError(message));

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => FailureResult<String>(UnknownError(message));
}
