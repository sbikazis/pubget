import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../google_sign_in_config.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    String? googleServerClientId,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _googleServerClientId =
           googleServerClientId ?? GoogleSignInConfig.serverClientId;

  final firebase_auth.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final String _googleServerClientId;
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
    } on Object catch (error, stackTrace) {
      return FailureResult<AuthUser>(mapFailure(error, stackTrace: stackTrace));
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
    } on Object catch (error, stackTrace) {
      return FailureResult<AuthUser>(mapFailure(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithGoogle() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize(
        serverClientId: _googleServerClientId,
      );
      await _googleInitialization;
      final account = await _googleSignIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const FailureResult<AuthUser>(
          UnknownError(
            'Google sign-in did not return an ID token. Check the Android OAuth client configuration.',
          ),
        );
      }
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = _mapUser(userCredential.user);
      return user == null
          ? const FailureResult<AuthUser>(
              UnknownError('Google authentication returned no user.'),
            )
          : Success<AuthUser>(user);
    } on Object catch (error, stackTrace) {
      return FailureResult<AuthUser>(mapFailure(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Success<void>(null);
    } on Object catch (error, stackTrace) {
      return FailureResult<void>(mapFailure(error, stackTrace: stackTrace));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      return const Success<void>(null);
    } on Object catch (error, stackTrace) {
      return FailureResult<void>(mapFailure(error, stackTrace: stackTrace));
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

  static Failure mapFailure(Object error, {StackTrace? stackTrace}) {
    if (error is firebase_auth.FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => const ValidationError(
          'Enter a valid email address.',
        ),
        'user-not-found' => const ValidationError(
          'No account exists with this email.',
        ),
        'wrong-password' => const ValidationError('Wrong password.'),
        'invalid-credential' => const ValidationError(
          'The email or password is incorrect.',
        ),
        'email-already-in-use' => const ValidationError(
          'This email is already in use.',
        ),
        'weak-password' => const ValidationError('Choose a stronger password.'),
        'user-disabled' => const PermissionError(
          'This account is currently disabled.',
        ),
        'network-request-failed' => const NetworkError(
          'Network unavailable. Check your connection and try again.',
        ),
        'too-many-requests' => const NetworkError(
          'Too many attempts. Please try again later.',
        ),
        'operation-not-allowed' => const PermissionError(
          'This sign-in method is not enabled yet.',
        ),
        _ => const UnknownError('Unexpected authentication error.'),
      };
    }
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => const CancelledError(),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          const UnknownError(
            'Google sign-in configuration is unavailable on this build.',
          ),
        _ => const UnknownError('Google sign-in could not be completed.'),
      };
    }
    if (error is firebase_auth.FirebaseException &&
        error.code == 'network-request-failed') {
      return const NetworkError(
        'Network unavailable. Check your connection and try again.',
      );
    }
    _logUnexpectedAuthError(error, stackTrace);
    return const UnknownError('Unexpected authentication error.');
  }

  static void _logUnexpectedAuthError(Object error, StackTrace? stackTrace) {
    debugPrint('Unexpected authentication error: $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
}
