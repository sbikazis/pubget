import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';
import 'package:pubget/features/social/models/profile_social_link.dart';

void main() {
  test('user model round-trips the new profile schema', () {
    final createdAt = DateTime.utc(2026, 9);
    final user = PubgetUser(
      id: 'user-1',
      email: 'fan@example.com',
      username: 'anime_fan',
      displayName: 'Anime Fan',
      avatarUrl: 'https://example.com/avatar.jpg',
      coverUrl: 'https://example.com/cover.jpg',
      bio: 'Mystery enthusiast',
      age: 21,
      gender: 'prefer_not_to_say',
      country: 'Japan',
      favoriteQuote: 'Believe it',
      animeTwin: 'Naruto',
      socialLinks: const [
        ProfileSocialLink(url: 'https://x.com/fan', platform: 'x'),
      ],
      favoriteAnimes: const <String>['Naruto', 'One Piece'],
      favoriteAnimeIds: const <String>['20', '21'],
      createdAt: createdAt,
      isProfileCompleted: true,
    );

    final map = user.toMap();
    final restored = PubgetUser.fromMap(map);

    expect(restored.id, user.id);
    expect(restored.createdAt, createdAt);
    expect(restored.favoriteAnimes, <String>['Naruto', 'One Piece']);
    expect(restored.favoriteAnimeIds, <String>['20', '21']);
    expect(restored.gender, 'prefer_not_to_say');
    expect(restored.whoCanMessageMe, 'related');
    expect(restored.coverUrl, 'https://example.com/cover.jpg');
    expect(restored.age, 21);
    expect(restored.socialLinks.single.url, 'https://x.com/fan');
    expect(restored.sectionPrivacy.favorites, isTrue);
    expect(map, isNot(contains('coinsBalance')));
    expect(map, isNot(contains('isPremium')));
    expect(map, isNot(contains('subscription')));
  });
}
