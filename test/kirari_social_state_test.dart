import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/kirari/data/kirari_repository.dart';

void main() {
  group('Kirari reel viewer interactions', () {
    test('parses server-owned like/save state and public creator identity', () {
      final reel = KirariReel.fromMap(<dynamic, dynamic>{
        'id': 'reel-1',
        'creatorId': 'creator-1',
        'creatorUsername': 'anime_fan',
        'creatorAvatarUrl': 'https://example.test/avatar.jpg',
        'caption': 'A scene edit',
        'playbackUrl': 'https://example.test/video.mp4',
        'coverUrl': 'https://example.test/cover.jpg',
        'durationSeconds': 15,
        'likesCount': 12,
        'commentsCount': 3,
        'viewerLiked': true,
        'viewerSaved': false,
      });

      expect(reel.viewerLiked, isTrue);
      expect(reel.viewerSaved, isFalse);
      expect(reel.creatorUsername, 'anime_fan');
      expect(reel.creatorAvatarUrl, 'https://example.test/avatar.jpg');
    });

    test('copyWith changes viewer state and counters without losing reel data', () {
      final reel = KirariReel.fromMap(<dynamic, dynamic>{
        'id': 'reel-2',
        'creatorId': 'creator-2',
        'caption': 'Another edit',
        'playbackUrl': 'https://example.test/video.mp4',
        'coverUrl': '',
        'durationSeconds': 12,
        'likesCount': 4,
        'commentsCount': 1,
      });

      final updated = reel.copyWith(
        viewerLiked: true,
        viewerSaved: true,
        likesCount: 5,
      );

      expect(updated.viewerLiked, isTrue);
      expect(updated.viewerSaved, isTrue);
      expect(updated.likesCount, 5);
      expect(updated.commentsCount, 1);
      expect(updated.id, reel.id);
      expect(updated.creatorId, reel.creatorId);
    });
  });
}
