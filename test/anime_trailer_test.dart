import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/widgets/anime_trailer.dart';

void main() {
  group('youtubeVideoIdFrom', () {
    test('reads the id from every shape the providers return', () {
      // Jikan and AniList do not agree on the shape of the link, so the player
      // has to cope with all of them.
      expect(
        youtubeVideoIdFrom('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        youtubeVideoIdFrom('https://youtube.com/watch?v=dQw4w9WgXcQ&t=42'),
        'dQw4w9WgXcQ',
      );
      expect(
        youtubeVideoIdFrom('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(youtubeVideoIdFrom('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        youtubeVideoIdFrom(
          'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects anything that is not a YouTube video', () {
      expect(youtubeVideoIdFrom('https://example.test/trailer.mp4'), isNull);
      expect(youtubeVideoIdFrom('https://www.youtube.com/watch'), isNull);
      expect(youtubeVideoIdFrom('https://youtu.be/'), isNull);
      expect(youtubeVideoIdFrom('not a url'), isNull);
    });

    test('does not treat a lookalike host as YouTube', () {
      expect(
        youtubeVideoIdFrom('https://notyoutube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        youtubeVideoIdFrom('https://youtube.com.evil.test/watch?v=abc'),
        isNull,
      );
    });
  });
}
