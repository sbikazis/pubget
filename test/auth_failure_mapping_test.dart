import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/authentication/repositories/firebase_auth_repository.dart';

void main() {
  test('Firebase auth codes become readable validation failures', () {
    final duplicate = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'email-already-in-use'),
    );
    final invalid = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'invalid-credential'),
    );
    final missing = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'user-not-found'),
    );
    final password = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'wrong-password'),
    );

    expect(duplicate, isA<ValidationError>());
    expect(duplicate.message, 'This email is already in use.');
    expect(invalid.message, 'The email or password is incorrect.');
    expect(missing.message, 'No account exists with this email.');
    expect(password.message, 'Wrong password.');
  });

  test('network auth code becomes offline-aware failure', () {
    final failure = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'network-request-failed'),
    );

    expect(failure, isA<NetworkError>());
    expect(
      failure.message,
      'Network unavailable. Check your connection and try again.',
    );
  });

  test('cancelled Google sign-in becomes a silent cancelled error', () {
    final failure = FirebaseAuthRepository.mapFailure(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    expect(failure, isA<CancelledError>());
  });

  test('Google configuration errors stay user-facing and non-technical', () {
    final failure = FirebaseAuthRepository.mapFailure(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ),
    );

    expect(
      failure.message,
      'Google sign-in configuration is unavailable on this build.',
    );
    expect(failure.message.toLowerCase(), isNot(contains('rangeerror')));
  });

  test('RangeError from auth is not shown as a stack-style message', () {
    final failure = FirebaseAuthRepository.mapFailure(
      RangeError.range(14, 0, 13, 'length'),
    );

    expect(failure, isA<UnknownError>());
    expect(failure.message, 'Unexpected authentication error.');
    expect(failure.message, isNot(contains('RangeError')));
    expect(failure.message, isNot(contains('0..13')));
  });
}
