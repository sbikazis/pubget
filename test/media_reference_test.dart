import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/media_reference.dart';

void main() {
  group('isR2MediaKey', () {
    test('accepts supported user and scoped media references', () {
      expect(isR2MediaKey('images/alice/abc123.jpg'), isTrue);
      expect(isR2MediaKey('reels/alice/abc123.mp4'), isTrue);
      expect(isR2MediaKey('audio/alice/abc123.m4a'), isTrue);
      expect(isR2MediaKey('groups/g1/alice/abc123.webp'), isTrue);
      expect(
        isR2MediaKey('privateChats/chat:alice:bob/alice/abc123.ogg'),
        isTrue,
      );
    });

    test(
      'rejects arbitrary, traversal, malformed and mismatched media keys',
      () {
        expect(isR2MediaKey('users/alice/avatar.jpg'), isFalse);
        expect(isR2MediaKey('../alice/file.jpg'), isFalse);
        expect(isR2MediaKey('images/../file.jpg'), isFalse);
        expect(isR2MediaKey('images/alice/file.exe'), isFalse);
        expect(isR2MediaKey('reels/alice/file.jpg'), isFalse);
        expect(isR2MediaKey('audio/alice/file.mp4'), isFalse);
        expect(isR2MediaKey('groups/g1/alice/../../file.jpg'), isFalse);
        expect(isR2MediaKey(''), isFalse);
      },
    );
  });

  group('media reference resolution', () {
    test('opaque legacy schemes are never treated as R2 object keys', () {
      expect(isOpaqueMediaReference('gs://pubget-media/alice/a.jpg'), isTrue);
      expect(isOpaqueMediaReference('firebase-storage://alice/a.jpg'), isTrue);
      expect(isOpaqueMediaReference('https://cdn.example.com/a.jpg'), isFalse);
      expect(isOpaqueMediaReference('images/alice/a.jpg'), isFalse);
    });

    test(
      'legacy HTTP links are upgraded to TLS without touching other shapes',
      () {
        expect(
          secureMediaUrl('http://cdn.example.com/a.jpg'),
          'https://cdn.example.com/a.jpg',
        );
        expect(
          secureMediaUrl('https://cdn.example.com/a.jpg'),
          'https://cdn.example.com/a.jpg',
        );
        expect(
          secureMediaUrl('gs://pubget-media/a.jpg'),
          'gs://pubget-media/a.jpg',
        );
        expect(secureMediaUrl('images/alice/a.jpg'), 'images/alice/a.jpg');
      },
    );

    test('resolver fails closed and leaves full URLs alone', () async {
      expect(await resolveMediaDownloadUrl(''), isNull);
      expect(await resolveMediaDownloadUrl('gs://pubget-media/a.jpg'), isNull);
      expect(await resolveMediaDownloadUrl('users/alice/a.jpg'), isNull);
      // Tests have no R2_WORKER_URL dart-define, so even a valid key cannot be
      // turned into a bearer URL. This is the fail-closed production contract.
      expect(await resolveMediaDownloadUrl('images/alice/a.jpg'), isNull);
      expect(
        await resolveMediaDownloadUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
    });

    test('picked video extensions map to Worker-accepted MIME types', () {
      expect(videoContentTypeFor('clip.MP4'), 'video/mp4');
      expect(videoContentTypeFor('clip.webm'), 'video/webm');
      expect(videoContentTypeFor('clip.mov'), 'video/quicktime');
      expect(videoContentTypeFor('clip.qt'), 'video/quicktime');
      expect(videoContentTypeFor('clip.unknown'), 'video/mp4');
    });
  });
}
