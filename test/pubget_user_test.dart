import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';

void main() {
  test('user model round-trips the new profile schema', () {
    final createdAt = DateTime.utc(2026, 9);
    final user = PubgetUser(
      id: 'user-1',
      email: 'fan@example.com',
      username: 'anime_fan',
      displayName: 'Anime Fan',
      avatarUrl: 'https://example.com/avatar.jpg',
      bio: 'Mystery enthusiast',
      favoriteAnimes: const <String>['Mystery', 'Fantasy'],
      createdAt: createdAt,
      isProfileCompleted: true,
    );

    final map = user.toMap();
    final restored = PubgetUser.fromMap(map);

    expect(restored.id, user.id);
    expect(restored.createdAt, createdAt);
    expect(restored.favoriteAnimes, <String>['Mystery', 'Fantasy']);
    expect(restored.whoCanMessageMe, 'related');
    expect(map, isNot(contains('coinsBalance')));
    expect(map, isNot(contains('isPremium')));
    expect(map, isNot(contains('subscription')));
  });
}
