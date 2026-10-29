import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_limits.dart';
import 'package:pubget/core/media/media_validation.dart';

import 'media_test_support.dart';

Uint8List pad(Uint8List bytes, [int length = 32]) {
  final size = bytes.length > length ? bytes.length : length;
  final out = Uint8List(size);
  out.setRange(0, bytes.length, bytes);
  return out;
}

void main() {
  group('sniffMediaSignature', () {
    test('detects each accepted image container', () {
      expect(sniffMediaSignature(pad(jpegBytes))?.contentType, 'image/jpeg');
      expect(sniffMediaSignature(pad(pngBytes))?.contentType, 'image/png');
      expect(sniffMediaSignature(pad(gifBytes))?.contentType, 'image/gif');
      expect(sniffMediaSignature(pad(webpBytes))?.contentType, 'image/webp');
    });

    test('detects video containers and ignores the file name', () {
      expect(sniffMediaSignature(buildMp4Bytes(seconds: 5))?.kind, MediaKind.reels);
      expect(sniffMediaSignature(pad(webmBytes))?.contentType, 'video/webm');
    });

    test('returns null for content that is not accepted media', () {
      expect(sniffMediaSignature(pad(htmlBytes)), isNull);
      expect(sniffMediaSignature(Uint8List(0)), isNull);
      expect(sniffMediaSignature(Uint8List.fromList(<int>[1, 2, 3])), isNull);
    });
  });

  group('validateMediaUpload', () {
    const limits = MediaLimits();

    test('accepts a real JPEG for the image kind', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(jpegBytes),
        claimedContentType: 'image/jpeg',
        limits: limits,
        declaredExtension: 'jpg',
      );
      expect(result.isAccepted, isTrue);
      expect(result.signature?.contentType, 'image/jpeg');
    });

    test('rejects empty bytes', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: Uint8List(0),
        claimedContentType: 'image/jpeg',
        limits: limits,
      );
      expect(result.isAccepted, isFalse);
      expect(result.failure, isNotNull);
    });

    test('rejects content that is not media at all', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(htmlBytes),
        claimedContentType: 'image/jpeg',
        limits: limits,
      );
      expect(result.isAccepted, isFalse);
    });

    test('rejects bytes whose kind does not match the request', () {
      final result = validateMediaUpload(
        kind: MediaKind.reels,
        bytes: pad(pngBytes),
        claimedContentType: 'video/mp4',
        limits: limits,
      );
      expect(result.isAccepted, isFalse);
      expect(result.failure?.message, contains('image'));
    });

    test('rejects a mislabeled extension', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(pngBytes),
        claimedContentType: 'image/png',
        limits: limits,
        declaredExtension: 'jpg',
      );
      expect(result.isAccepted, isFalse);
      expect(result.failure?.message, contains('does not match'));
    });

    test('accepts the jpeg alias for a .jpg file', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(jpegBytes),
        claimedContentType: 'image/jpeg',
        limits: limits,
        declaredExtension: 'jpeg',
      );
      expect(result.isAccepted, isTrue);
    });

    test('rejects a file above the hard ceiling', () {
      const tiny = MediaLimits(imageMaxBytes: 16);
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(pngBytes, 64),
        claimedContentType: 'image/png',
        limits: tiny,
      );
      expect(result.isAccepted, isFalse);
      expect(result.failure?.message, contains('limit'));
    });

    test('ignores an empty claimed content type when bytes are valid', () {
      final result = validateMediaUpload(
        kind: MediaKind.image,
        bytes: pad(pngBytes),
        claimedContentType: '',
        limits: limits,
      );
      expect(result.isAccepted, isTrue);
    });
  });
}
