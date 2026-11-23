import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/media_url_cache.dart';

void main() {
  group('MediaUrlCache', () {
    late DateTime now;
    late MediaUrlCache cache;

    setUp(() {
      now = DateTime.utc(2026, 11, 22, 12);
      cache = MediaUrlCache(clock: () => now);
    });

    ResolvedMediaUrl entry({Duration life = const Duration(minutes: 10)}) =>
        ResolvedMediaUrl(
          url: 'https://media.example/signed?signature=abc',
          expiresAt: now.add(life),
        );

    test('serves a fresh signed URL without re-resolving', () {
      cache.write('images/alice/a.jpg', entry());
      expect(
        cache.read('images/alice/a.jpg'),
        'https://media.example/signed?signature=abc',
      );
      expect(cache.length, 1);
    });

    test('drops a URL once it nears signature expiry', () {
      cache.write(
        'images/alice/a.jpg',
        entry(life: const Duration(seconds: 20)),
      );
      // The default 30 s safety margin already makes this entry stale.
      expect(cache.read('images/alice/a.jpg'), isNull);
      expect(cache.length, 0);
    });

    test('invalidation forces the next read to miss', () {
      cache.write('images/alice/a.jpg', entry());
      cache.invalidate('images/alice/a.jpg');
      expect(cache.read('images/alice/a.jpg'), isNull);
    });

    test('keeps at most maxEntries, evicting the oldest', () {
      final bounded = MediaUrlCache(maxEntries: 2, clock: () => now);
      bounded.write('a', entry());
      bounded.write('b', entry());
      bounded.write('c', entry());
      expect(bounded.read('a'), isNull);
      expect(bounded.read('b'), isNotNull);
      expect(bounded.read('c'), isNotNull);
      expect(bounded.length, 2);
    });
  });
}
