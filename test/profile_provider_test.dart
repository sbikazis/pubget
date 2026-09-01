import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/social/providers/profile_provider.dart';
import 'package:pubget/features/social/repositories/profile_repository.dart';

import 'social_test_support.dart';

void main() {
  test('loads private owner data only for the owner', () async {
    final repository = FakeProfileRepository();
    final provider = ProfileProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load(viewerId: 'user-1', profileId: 'user-1');

    expect(provider.isOwner, isTrue);
    expect(provider.ownProfile?.email, 'fan@example.com');
    expect(provider.publicProfile, isNull);
  });

  test('viewer receives only the public projection', () async {
    final repository = FakeProfileRepository();
    final provider = ProfileProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load(viewerId: 'user-1', profileId: 'user-2');

    expect(provider.isOwner, isFalse);
    expect(provider.publicProfile?.username, 'other_fan');
    expect(provider.ownProfile, isNull);
  });

  test('updates only the profile fields in ProfileUpdate', () async {
    final repository = FakeProfileRepository();
    final provider = ProfileProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load(viewerId: 'user-1', profileId: 'user-1');

    await provider.update(
      'user-1',
      const ProfileUpdate(
        bio: 'Updated',
        favoriteAnimeIds: <String>['frieren'],
        profileVisibility: 'private',
        activityVisibility: 'private',
      ),
    );

    expect(repository.lastUpdate?.toMap().keys, <String>[
      'bio',
      'favoriteAnimeIds',
      'profileVisibility',
      'activityVisibility',
    ]);
    expect(provider.ownProfile?.profileVisibility, 'private');
  });
}
