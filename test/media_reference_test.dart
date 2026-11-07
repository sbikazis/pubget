import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/media_reference.dart';

void main() {
  group('isR2MediaKey', () {
    test('accepts supported user and scoped media references', () {
      expect(isR2MediaKey('images/alice/abc123.jpg'), isTrue);
      expect(isR2MediaKey('reels/alice/abc123.mp4'), isTrue);
      expect(isR2MediaKey('audio/alice/abc123.m4a'), isTrue);
      expect(isR2MediaKey('groups/g1/alice/abc123.webp'), isTrue);
      expect(isR2MediaKey('privateChats/chat:alice:bob/alice/abc123.ogg'), isTrue);
    });

    test('rejects arbitrary, traversal, malformed and mismatched media keys', () {
      expect(isR2MediaKey('users/alice/avatar.jpg'), isFalse);
      expect(isR2MediaKey('../alice/file.jpg'), isFalse);
      expect(isR2MediaKey('images/../file.jpg'), isFalse);
      expect(isR2MediaKey('images/alice/file.exe'), isFalse);
      expect(isR2MediaKey('reels/alice/file.jpg'), isFalse);
      expect(isR2MediaKey('audio/alice/file.mp4'), isFalse);
      expect(isR2MediaKey('groups/g1/alice/../../file.jpg'), isFalse);
      expect(isR2MediaKey(''), isFalse);
    });
  });
}
