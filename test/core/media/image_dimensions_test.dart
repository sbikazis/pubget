import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/image_dimensions.dart';

void main() {
  group('readImageDimensions', () {
    test('reads PNG dimensions from the IHDR chunk', () {
      final bytes = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x02, 0x58, // width  = 600
        0x00, 0x00, 0x01, 0x2C, // height = 300
        0x08, 0x06, 0x00, 0x00, 0x00,
      ]);
      expect(readImageDimensions(bytes), (width: 600, height: 300));
    });

    test('reads GIF logical screen size', () {
      final bytes = Uint8List.fromList(<int>[
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
        0x40, 0x01, // width  = 320
        0x90, 0x00, // height = 144
        0x00, 0x00, 0x00,
      ]);
      expect(readImageDimensions(bytes), (width: 320, height: 144));
    });

    test('reads JPEG dimensions from the first SOF0 marker', () {
      final bytes = Uint8List.fromList(<int>[
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x10, // APP0, length 16
        0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
        0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0xFF, 0xDB, 0x00, 0x04, 0x00, 0x00, // DQT
        0xFF, 0xC0, 0x00, 0x11, 0x08, // SOF0, length 17, precision 8
        0x04, 0xB0, // height = 1200
        0x06, 0x40, // width  = 1600
        0x03,
      ]);
      expect(readImageDimensions(bytes), (width: 1600, height: 1200));
    });

    test('reads WebP VP8X canvas size', () {
      final bytes = Uint8List.fromList(<int>[
        0x52, 0x49, 0x46, 0x46, 0x1A, 0x00, 0x00, 0x00, // RIFF
        0x57, 0x45, 0x42, 0x50, // WEBP
        0x56, 0x50, 0x38, 0x58, // VP8X
        0x0A, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0xA6, 0x38, 0x00, // width - 1  = 0x38A6 = 14502 -> 14503
        0xF0, 0x25, 0x00, // height - 1 = 0x25F0 = 9712  -> 9713
      ]);
      expect(readImageDimensions(bytes), (width: 14503, height: 9713));
    });

    test('returns null instead of guessing on an unknown format', () {
      expect(
        readImageDimensions(
          Uint8List.fromList(<int>[0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]),
        ),
        isNull,
      );
    });

    test('returns null for a truncated header', () {
      expect(readImageDimensions(Uint8List.fromList(<int>[1, 2, 3])), isNull);
      final png = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00,
      ]);
      expect(readImageDimensions(png), isNull);
    });

    test('returns null when a declared dimension is zero', () {
      final bytes = Uint8List.fromList(<int>[
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00, 0x00,
      ]);
      expect(readImageDimensions(bytes), isNull);
    });
  });
}
