import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/constants/limits.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_limits.dart';

void main() {
  group('MediaLimits defaults', () {
    const limits = MediaLimits();

    test('match the agreed ceilings', () {
      expect(limits.imageMaxBytes, 10 * 1024 * 1024);
      expect(limits.reelsMaxBytes, 5 * 1024 * 1024);
      expect(limits.audioMaxBytes, 50 * 1024 * 1024);
      expect(limits.imageTargetBytes, 150 * 1024);
    });

    test('keep the Reels window locked to the product limits', () {
      expect(limits.reelsMinDurationSeconds, Limits.editMinDurationSeconds);
      expect(limits.reelsMaxDurationSeconds, Limits.editMaxDurationSeconds);
      expect(limits.reelsMinDurationSeconds, 3);
      expect(limits.reelsMaxDurationSeconds, 60);
    });

    test('expose per-kind ceilings and targets', () {
      expect(limits.maxBytesFor(MediaKind.image), limits.imageMaxBytes);
      expect(limits.maxBytesFor(MediaKind.reels), limits.reelsMaxBytes);
      expect(limits.maxBytesFor(MediaKind.audio), limits.audioMaxBytes);
      expect(limits.targetBytesFor(MediaKind.image), limits.imageTargetBytes);
      expect(limits.targetBytesFor(MediaKind.reels), limits.reelsTargetBytes);
      expect(limits.targetBytesFor(MediaKind.audio), isNull);
    });
  });

  group('allowsDuration', () {
    const limits = MediaLimits();

    test('images never carry a duration constraint', () {
      expect(limits.allowsDuration(MediaKind.image, null), isTrue);
      expect(limits.allowsDuration(MediaKind.image, const Duration(hours: 3)), isTrue);
    });

    test('reels must be verified and inside 3..60 s', () {
      expect(limits.allowsDuration(MediaKind.reels, null), isFalse);
      expect(limits.allowsDuration(MediaKind.reels, const Duration(seconds: 2)), isFalse);
      expect(limits.allowsDuration(MediaKind.reels, const Duration(seconds: 3)), isTrue);
      expect(limits.allowsDuration(MediaKind.reels, const Duration(seconds: 60)), isTrue);
      expect(limits.allowsDuration(MediaKind.reels, const Duration(seconds: 61)), isFalse);
    });

    test('audio allows unverified duration by default', () {
      expect(limits.allowsDuration(MediaKind.audio, null), isTrue);
      expect(limits.allowsDuration(MediaKind.audio, const Duration(seconds: 300)), isTrue);
      expect(limits.allowsDuration(MediaKind.audio, const Duration(seconds: 301)), isFalse);
    });

    test('audio can be made strict', () {
      const strict = MediaLimits(allowUnverifiedAudioDuration: false);
      expect(strict.allowsDuration(MediaKind.audio, null), isFalse);
    });
  });
}
