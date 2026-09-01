import '../../../core/errors/result.dart';
import '../models/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> signInWithGoogle();

  Future<Result<void>> sendPasswordResetEmail({required String email});

  Future<Result<void>> signOut();
}
