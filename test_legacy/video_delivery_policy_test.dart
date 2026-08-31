import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/logic/video_delivery_policy.dart';

void main() {
  group('VideoDeliveryPolicy', () {
    test('classifies very slow network with low throughput', () {
      final profile = VideoDeliveryPolicy.resolve(
        throughputMbps: 0.5,
        rebufferCount: 3,
        startupMs: 2200,
        avgBufferPercent: 0.55,
      );

      expect(profile.targetResolution, 360);
      expect(profile.bitrateKbps, 500);
    });

    test('classifies very fast network with strong throughput', () {
      final profile = VideoDeliveryPolicy.resolve(
        throughputMbps: 10,
        rebufferCount: 0,
        startupMs: 800,
        avgBufferPercent: 0.92,
      );

      expect(profile.targetResolution, 1080);
      expect(profile.preloadAhead, 5);
      expect(profile.networkQuality, VideoNetworkQuality.veryFast);
    });
  });
}
