import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
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
}
