import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/kirari/data/kirari_repository.dart';

void main() {
  group('Kirari data contracts', () {
    test('reel mapping retains renditions and audio attribution', () {
      final reel = KirariReel.fromMap({
        'id': 'reel-1',
        'creatorId': 'creator-1',
        'caption': 'Anime edit',
        'playbackUrl': 'https://cdn.example/video-540.mp4',
        'coverUrl': 'https://cdn.example/cover.jpg',
        'durationSeconds': 42,
        'likesCount': 12,
        'commentsCount': 3,
        'audioId': 'audio-1',
        'audioAttribution': {
          'title': 'Original soundtrack',
          'artist': 'Artist',
          'license': 'CC-BY-4.0',
          'attribution': 'Credit Artist',
        },
        'renditions': {
          '360': {'path': 'kirari-processed/u/r/360.mp4'},
          '540': {'path': 'kirari-processed/u/r/540.mp4'},
          '720': {'path': 'kirari-processed/u/r/720.mp4'},
        },
      });

      expect(reel.id, 'reel-1');
      expect(reel.durationSeconds, 42);
      expect(reel.renditionPaths.keys, containsAll(['360', '540', '720']));
      expect(reel.audioAttribution['license'], 'CC-BY-4.0');
      expect(reel.audioId, 'audio-1');
    });

    test('audio mapping preserves the license and attribution displayed to creators', () {
      final track = KirariAudioTrack.fromMap({
        'id': 'audio-1',
        'title': 'Original soundtrack',
        'artist': 'Artist',
        'license': 'CC-BY-4.0',
        'licenseUrl': 'https://creativecommons.org/licenses/by/4.0/',
        'sourceUrl': 'https://artist.example/source',
        'rightsHolder': 'Artist Studio',
        'sourceCreatorId': 'artist-1',
        'attribution': 'Credit Artist',
      }, 'https://cdn.example/audio.mp3');

      expect(track.id, 'audio-1');
      expect(track.license, 'CC-BY-4.0');
      expect(track.licenseUrl, 'https://creativecommons.org/licenses/by/4.0/');
      expect(track.sourceUrl, 'https://artist.example/source');
      expect(track.rightsHolder, 'Artist Studio');
      expect(track.sourceCreatorId, 'artist-1');
      expect(track.attribution, 'Credit Artist');
      expect(track.audioUrl, 'https://cdn.example/audio.mp3');
    });

    test('feed page cursor and has-more state remain available for pagination', () {
      final page = KirariFeedPageResult(
        const [],
        hasMore: true,
        nextCursor: const {'afterId': 'reel-8', 'afterScore': 77.5},
      );

      expect(page.hasMore, isTrue);
      expect(page.nextCursor?['afterId'], 'reel-8');
      expect(page.nextCursor?['afterScore'], 77.5);
    });
  });
}
