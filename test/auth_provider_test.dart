import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';

import 'authentication_test_support.dart';

void main() {
  test('auth provider exposes session state after email sign-in', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initialize();
    final result = await provider.signInWithEmail(
      email: 'fan@example.com',
      password: 'password',
    );

    expect(result.isSuccess, isTrue);
    expect(provider.currentUser?.id, 'user-1');
    expect(provider.isAuthenticated, isTrue);
    expect(provider.state, LoadingState.loaded);
  });

  test('auth provider exposes readable failure state', () async {
    final repository = FakeAuthRepository(
      authFailure: const ValidationError('Email or password is incorrect.'),
    );
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.signInWithEmail(
      email: 'fan@example.com',
      password: 'wrong-password',
    );

    expect(provider.state, LoadingState.error);
    expect(provider.failure?.message, 'Email or password is incorrect.');
  });

  test('password reset does not put the session into loading', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    final future = provider.sendPasswordResetEmail(email: 'fan@example.com');
    expect(provider.isResetting, isTrue);
    expect(provider.state, isNot(LoadingState.loading));
    await future;
    expect(provider.isResetting, isFalse);
    expect(provider.failure, isNull);
  });

  test('cancelled Google sign-in is not treated as a failure', () async {
    final repository = FakeAuthRepository(authFailure: const CancelledError());
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.signInWithGoogle();

    expect(result.isSuccess, isFalse);
    expect(provider.failure, isNull);
    expect(provider.state, LoadingState.loaded);
    expect(provider.isAuthenticated, isFalse);
  });

  test('sign-out clears the session', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initialize();
    await provider.signInWithEmail(
      email: 'fan@example.com',
      password: 'password',
    );
    expect(provider.isAuthenticated, isTrue);

    await provider.signOut();
    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
    expect(provider.state, LoadingState.loaded);
  });

  test('restored session stays authenticated without going to login', () async {
    final repository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    addTearDown(repository.close);
    final provider = AuthProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initialize();
    expect(provider.isAuthenticated, isTrue);
    expect(provider.currentUser?.email, 'fan@example.com');
  });
}
