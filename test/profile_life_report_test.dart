import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/social/models/profile_section_privacy.dart';
import 'package:pubget/features/social/models/profile_social_link.dart';
import 'package:pubget/features/social/repositories/profile_repository.dart';

void main() {
  test('social link detects common platforms', () {
    expect(
      ProfileSocialLink.detectPlatform('https://www.instagram.com/fan'),
      'instagram',
    );
    expect(ProfileSocialLink.detectPlatform('https://x.com/fan'), 'x');
    expect(ProfileSocialLink.detectPlatform('https://example.com'), 'other');
  });

  test('section privacy round-trips', () {
    const privacy = ProfileSectionPrivacy(favorites: false, works: false);
    final restored = ProfileSectionPrivacy.fromMap(privacy.toMap());
    expect(restored.favorites, isFalse);
    expect(restored.works, isFalse);
    expect(restored.friends, isTrue);
  });

  test('profile update includes life-report fields', () {
    final update = ProfileUpdate(
      username: 'fan',
      bio: 'hello',
      age: 20,
      country: 'Morocco',
      socialLinks: const [
        ProfileSocialLink(url: 'https://x.com/fan'),
      ],
      sectionPrivacy: const ProfileSectionPrivacy(fans: false),
      favoriteAnimeIds: const <String>['frieren'],
      profileVisibility: 'public',
      activityVisibility: 'public',
    );
    final map = update.toMap();
    expect(map['username'], 'fan');
    expect(map['age'], 20);
    expect(map['sectionPrivacy'], isA<Map<String, dynamic>>());
    expect((map['socialLinks'] as List).single['url'], 'https://x.com/fan');
  });
}
