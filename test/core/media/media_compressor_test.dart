import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:pubget/core/media/media_compressor.dart';

Uint8List noisyJpeg({int size = 600}) {
  final image = img.Image(width: size, height: size);
  var seed = 1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      image.setPixelRgb(x, y, seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

void main() {
  const compressor = ImagePackageMediaCompressor();

  test('returns input untouched when it is already within target', () async {
    final input = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final result = await compressor.compressImage(
      input,
      sourceContentType: 'image/png',
      targetBytes: 1024,
    );
    expect(result.bytes, same(input));
    expect(result.contentType, 'image/png');
  });

  test('compresses an oversized photo down toward the target', () async {
    final input = noisyJpeg();
    final result = await compressor.compressImage(
      input,
      sourceContentType: 'image/jpeg',
      targetBytes: 40 * 1024,
    );
    expect(result.contentType, 'image/jpeg');
    expect(result.bytes.length, lessThan(input.length));
    expect(result.width, isNotNull);
    expect(result.height, isNotNull);
  });

  test('keeps transparency by emitting PNG for alpha images', () async {
    final image = img.Image(width: 512, height: 512, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(255, 0, 0, 120));
    final input = Uint8List.fromList(img.encodePng(image));

    final result = await compressor.compressImage(
      input,
      sourceContentType: 'image/png',
      targetBytes: 1024,
    );
    expect(result.contentType, 'image/png');
    expect(result.bytes.length, greaterThan(0));
  });

  test('hands back undecodable bytes so validation can reject them', () async {
    final input = Uint8List.fromList(List<int>.generate(2048, (i) => i % 251));
    final result = await compressor.compressImage(
      input,
      sourceContentType: 'image/jpeg',
      targetBytes: 16,
    );
    expect(result.bytes, same(input));
  });
}
