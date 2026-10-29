import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/media_duration.dart';
import 'package:pubget/core/media/media_kind.dart';

import 'media_test_support.dart';

void main() {
  group('ISO-BMFF (mp4)', () {
    test('reads the duration from moov/mvhd for a reels file', () {
      expect(
        parseMediaDuration(buildMp4Bytes(seconds: 30), MediaKind.reels),
        const Duration(seconds: 30),
      );
    });

    test('reads the same container for audio (m4a)', () {
      expect(
        parseMediaDuration(buildMp4Bytes(seconds: 15), MediaKind.audio),
        const Duration(seconds: 15),
      );
    });

    test('honours a non-default timescale', () {
      expect(
        parseMediaDuration(
          buildMp4Bytes(seconds: 12, timescale: 600),
          MediaKind.reels,
        ),
        const Duration(seconds: 12),
      );
    });

    test('returns null when the boxes are absent', () {
      expect(
        parseMediaDuration(Uint8List.fromList(<int>[0, 0, 0, 0, 1, 2, 3, 4]), MediaKind.reels),
        isNull,
      );
    });
  });

  group('audio', () {
    test('estimates MP3 duration from the first frame header', () {
      final bytes = Uint8List.fromList(<int>[
        0xff, 0xfb, 0x90, 0x00, // MPEG1 Layer III, 128 kbps
        ...List<int>.filled(15996, 0),
      ]);
      expect(parseMediaDuration(bytes, MediaKind.audio), const Duration(seconds: 1));
    });

    test('returns null for unverifiable Ogg audio', () {
      expect(parseMediaDuration(Uint8List.fromList(webmBytes), MediaKind.audio), isNull);
    });
  });

  test('images never carry a duration', () {
    expect(parseMediaDuration(pngBytes, MediaKind.image), isNull);
  });
}
