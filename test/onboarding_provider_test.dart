import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';

import 'authentication_test_support.dart';

void main() {
  const authUser = AuthUser(id: 'user-1', email: 'fan@example.com');

  test('onboarding keeps auth and profile completion separate', () async {
    final repository = FakeUserRepository();
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.loadProfile(authUser.id);
    expect(provider.profile, isNull);

    final result = await provider.saveProfile(
      authUser: authUser,
      username: 'anime_fan',
      favoriteAnimes: const <String>['Fantasy'],
      isProfileCompleted: true,
    );

    expect(result.isSuccess, isTrue);
    expect(provider.isProfileCompleted, isTrue);
    expect(provider.profile?.favoriteAnimes, <String>['Fantasy']);
    expect(provider.state, LoadingState.loaded);
  });

  test('avatar bytes are uploaded through the repository', () async {
    final repository = FakeUserRepository();
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.saveProfileWithAvatar(
      authUser: authUser,
      avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: 'image/png',
      isProfileCompleted: false,
    );

    expect(result.isSuccess, isTrue);
    expect(repository.avatarUploads, 1);
    expect(provider.profile?.avatarUrl, 'https://example.com/avatar.jpg');
  });
}
