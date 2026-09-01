import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(duplicate, isA<ValidationError>());
    expect(duplicate.message, 'This email is already in use.');
    expect(invalid.message, 'The email or password is incorrect.');
  });

  test('network auth code becomes offline-aware failure', () {
    final failure = FirebaseAuthRepository.mapFailure(
      FirebaseAuthException(code: 'network-request-failed'),
    );

    expect(failure, isA<NetworkError>());
    expect(failure.message, 'Check your connection and try again.');
  });
}
