import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pubget/core/media/media_compressor.dart';

void main() {
  group('DefaultMediaCompressor', () {
    test('compresses JPEG off the calling isolate and reports output size', () async {
      final source = img.encodeJpg(img.Image(width: 1200, height: 800), quality: 95);
      final result = await const DefaultMediaCompressor().compressImage(
        source,
        sourceContentType: 'image/jpeg',
        targetBytes: 1024,
      );

      expect(result.contentType, 'image/jpeg');
      expect(result.bytes, isNotEmpty);
      expect(result.bytes.length, lessThanOrEqualTo(source.length));
      final decoded = img.decodeJpg(result.bytes);
      expect(decoded, isNotNull);
      expect(result.width, decoded!.width);
      expect(result.height, decoded.height);
    });

    test('preserves GIF bytes to avoid flattening animation', () async {
      final source = img.encodeGif(img.Image(width: 8, height: 8));
      final result = await const DefaultMediaCompressor().compressImage(
        source,
        sourceContentType: 'image/gif',
        targetBytes: 1,
      );

      expect(result.contentType, 'image/gif');
      expect(result.bytes, orderedEquals(source));
    });

    test('rejects invalid target sizes', () async {
      expect(
        () => const DefaultMediaCompressor().compressImage(
          Uint8List.fromList(<int>[1, 2, 3]),
          sourceContentType: 'image/jpeg',
          targetBytes: 0,
        ),
        throwsFormatException,
      );
    });
  });
}
