import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';

import 'authentication_test_support.dart';

void main() {
  const authUser = AuthUser(
    id: 'user-1',
    email: 'fan@example.com',
    displayName: 'Anime Fan',
    avatarUrl: 'https://example.com/avatar.jpg',
  );

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

  test('completed profile requires username, display name, and avatar', () async {
    final repository = FakeUserRepository();
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.saveProfile(
      authUser: const AuthUser(id: 'user-2', email: 'fan2@example.com'),
      isProfileCompleted: true,
    );

    expect(result.isSuccess, isFalse);
    expect(repository.user, isNull);
    expect(provider.canEnterHome, isFalse);
    expect(provider.state, LoadingState.error);
  });

  test('onboarding preserves existing optional profile and privacy settings', () async {
    final repository = FakeUserRepository()
      ..user = PubgetUser(
        id: authUser.id,
        email: authUser.email,
        username: 'anime_fan',
        displayName: 'Anime Fan',
        avatarUrl: authUser.avatarUrl,
        coverUrl: 'https://example.com/cover.jpg',
        bio: 'Original bio',
        age: 24,
        country: 'Morocco',
        profileVisibility: 'private',
        activityVisibility: 'private',
        language: 'ar',
        createdAt: DateTime.utc(2026, 1, 1),
        isProfileCompleted: false,
      );
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.loadProfile(authUser.id);
    final result = await provider.saveProfile(
      authUser: authUser,
      username: 'anime_fan',
      displayName: 'Anime Fan Updated',
      bio: 'Updated bio',
      age: 25,
      country: 'Morocco',
      isProfileCompleted: true,
    );

    expect(result.isSuccess, isTrue);
    expect(provider.profile?.age, 25);
    expect(provider.profile?.country, 'Morocco');
    expect(provider.profile?.coverUrl, 'https://example.com/cover.jpg');
    expect(provider.profile?.profileVisibility, 'private');
    expect(provider.profile?.activityVisibility, 'private');
    expect(provider.profile?.language, 'ar');
    expect(provider.profile?.bio, 'Updated bio');
  });

  test('legacy skipped profiles still require identity completion', () async {
    final repository = FakeUserRepository()
      ..user = PubgetUser(
        id: authUser.id,
        email: authUser.email,
        hasSkippedOnboarding: true,
        createdAt: DateTime.utc(2026, 1, 1),
        isProfileCompleted: false,
      );
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.loadProfile(authUser.id);

    expect(provider.canEnterHome, isFalse);
  });

  test('avatar bytes are uploaded through the repository', () async {
    final repository = FakeUserRepository();
    final provider = OnboardingProvider(repository: repository);
    addTearDown(provider.dispose);

    final result = await provider.saveProfileWithAvatar(
      authUser: authUser,
      avatarBytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: 'image/png',
      username: 'anime_fan',
      displayName: 'Anime Fan',
      age: 22,
      country: 'Morocco',
      isProfileCompleted: true,
    );

    expect(result.isSuccess, isTrue);
    expect(repository.avatarUploads, 1);
    expect(provider.profile?.avatarUrl, 'https://example.com/avatar.jpg');
    expect(provider.profile?.age, 22);
    expect(provider.profile?.country, 'Morocco');
  });
}
