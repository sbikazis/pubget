import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/media_keys.dart';
import 'package:pubget/core/media/media_kind.dart';

void main() {
  group('buildMediaKey', () {
    test('uses the kind folder, the owner uid and a generated name', () {
      final key = buildMediaKey(
        kind: MediaKind.image,
        ownerUid: 'alice',
        extension: 'jpg',
        random: Random(1),
      );
      expect(key, matches(RegExp(r'^images/alice/[0-9a-f-]{36}\.jpg$')));
    });

    test('normalizes the extension and strips unsafe characters', () {
      expect(
        buildMediaKey(
          kind: MediaKind.reels,
          ownerUid: 'bob',
          extension: 'MP4',
          random: Random(2),
        ),
        matches(RegExp(r'^reels/bob/[0-9a-f-]{36}\.mp4$')),
      );
      expect(
        buildMediaKey(
          kind: MediaKind.audio,
          ownerUid: 'bob',
          extension: '../etc',
          random: Random(3),
        ),
        matches(RegExp(r'^audio/bob/[0-9a-f-]{36}\.etc$')),
      );
    });

    test('never embeds a user supplied file name', () {
      final key = buildMediaKey(
        kind: MediaKind.image,
        ownerUid: 'alice',
        extension: 'jpg',
        random: Random(4),
      );
      expect(key.contains('holiday'), isFalse);
      expect(key.contains('..'), isFalse);
    });
  });

  group('generateMediaId', () {
    test('produces a v4-shaped identifier', () {
      final id = generateMediaId(Random(9));
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(id.length, 36);
    });
  });

  group('parseMediaKey', () {
    test('accepts a well-formed key', () {
      expect(parseMediaKey('images/alice/abc-123.jpg'), isNotNull);
      expect(mediaKeyFolder('images/alice/abc-123.jpg'), 'images');
      expect(mediaKeyOwnerUid('images/alice/abc-123.jpg'), 'alice');
    });

    test('rejects traversal, unknown folders and shape errors', () {
      expect(parseMediaKey('images/alice/../../../etc/passwd'), isNull);
      expect(parseMediaKey('images/alice/'), isNull);
      expect(parseMediaKey('secrets/alice/a.jpg'), isNull);
      expect(parseMediaKey('images/alice'), isNull);
      expect(parseMediaKey('images/alice/sub/a.jpg'), isNull);
      expect(parseMediaKey('images/alice/noextension'), isNull);
      expect(parseMediaKey('images/a b/x.jpg'), isNull);
    });
  });

  group('keyOwnedBy', () {
    test('only matches the encoded owner', () {
      expect(keyOwnedBy('images/alice/x.jpg', 'alice'), isTrue);
      expect(keyOwnedBy('images/alice/x.jpg', 'bob'), isFalse);
      expect(keyOwnedBy('not a key', 'alice'), isFalse);
    });
  });
}
