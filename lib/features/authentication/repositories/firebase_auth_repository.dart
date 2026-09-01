import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final firebase_auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      return user == null
          ? const FailureResult<AuthUser>(
              UnknownError('Authentication returned no user.'),
            )
          : Success<AuthUser>(user);
    } on Object catch (error) {
      return FailureResult<AuthUser>(mapFailure(error));
    }
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      return user == null
          ? const FailureResult<AuthUser>(
              UnknownError('Account creation returned no user.'),
            )
          : Success<AuthUser>(user);
    } on Object catch (error) {
      return FailureResult<AuthUser>(mapFailure(error));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithGoogle() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      final account = await _googleSignIn.authenticate();
      final authentication = account.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: authentication.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = _mapUser(userCredential.user);
      return user == null
          ? const FailureResult<AuthUser>(
              UnknownError('Google authentication returned no user.'),
            )
          : Success<AuthUser>(user);
    } on Object catch (error) {
      return FailureResult<AuthUser>(mapFailure(error));
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult<void>(mapFailure(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult<void>(mapFailure(error));
    }
  }

  static AuthUser? _mapUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      avatarUrl: user.photoURL,
    );
  }

  static Failure mapFailure(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => const ValidationError(
          'Enter a valid email address.',
        ),
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          const ValidationError('The email or password is incorrect.'),
        'email-already-in-use' => const ValidationError(
          'This email is already in use.',
        ),
        'weak-password' => const ValidationError('Choose a stronger password.'),
        'user-disabled' => const PermissionError(
          'This account is currently disabled.',
        ),
        'network-request-failed' => const NetworkError(
          'Check your connection and try again.',
        ),
        'too-many-requests' => const NetworkError(
          'Too many attempts. Please try again later.',
        ),
        'operation-not-allowed' => const PermissionError(
          'This sign-in method is not enabled yet.',
        ),
        _ => UnknownError(error.message ?? 'Authentication failed.'),
      };
    }
    if (error is firebase_auth.FirebaseException &&
        error.code == 'network-request-failed') {
      return const NetworkError('Check your connection and try again.');
    }
    return const UnknownError('We could not complete that action.');
  }
}
