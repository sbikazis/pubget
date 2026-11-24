import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_limits.dart';
import 'package:pubget/core/media/media_validation.dart';

Uint8List _pngBytes() => Uint8List.fromList(<int>[
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    ]);

Uint8List _jpegBytes() => Uint8List.fromList(<int>[
      0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, // JFIF header
      0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
    ]);

void main() {
  group('image upload file names', () {
    test('cropped PNG bytes are named .png even when the caller says jpg', () {
      final name = imageFileNameForUpload(
        bytes: _pngBytes(),
        contentType: 'image/jpeg',
        prefix: 'avatar',
      );
      expect(name, 'avatar.png');

      final accepted = validateMediaUpload(
        kind: MediaKind.image,
        bytes: _pngBytes(),
        claimedContentType: 'image/png',
        declaredExtension: name.split('.').last,
        limits: const MediaLimits(),
      );
      expect(accepted.isAccepted, isTrue, reason: accepted.failure?.message);
    });

    test('JPEG bytes keep the .jpg name', () {
      expect(
        imageFileNameForUpload(
          bytes: _jpegBytes(),
          contentType: 'image/jpeg',
          prefix: 'cover',
        ),
        'cover.jpg',
      );
    });
  });
}
