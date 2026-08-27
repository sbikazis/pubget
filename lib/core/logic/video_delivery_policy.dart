import 'dart:math' as math;

enum VideoNetworkQuality {
  verySlow,
  slow,
  medium,
  fast,
  veryFast,
}

class VideoDeliveryProfile {
  final VideoNetworkQuality networkQuality;
  final int targetResolution;
  final int bitrateKbps;
  final int preloadAhead;
  final int bufferSeconds;
  final int cacheMinutes;
  final bool adaptiveBitrate;

  const VideoDeliveryProfile({
    required this.networkQuality,
    required this.targetResolution,
    required this.bitrateKbps,
    required this.preloadAhead,
    required this.bufferSeconds,
    required this.cacheMinutes,
    required this.adaptiveBitrate,
  });
}

class VideoDeliveryPolicy {
  static const Map<VideoNetworkQuality, VideoDeliveryProfile> _profiles = {
    VideoNetworkQuality.verySlow: VideoDeliveryProfile(
      networkQuality: VideoNetworkQuality.verySlow,
      targetResolution: 360,
      bitrateKbps: 500,
      preloadAhead: 1,
      bufferSeconds: 12,
      cacheMinutes: 30,
      adaptiveBitrate: true,
    ),
    VideoNetworkQuality.slow: VideoDeliveryProfile(
      networkQuality: VideoNetworkQuality.slow,
      targetResolution: 480,
      bitrateKbps: 900,
      preloadAhead: 2,
      bufferSeconds: 18,
      cacheMinutes: 45,
      adaptiveBitrate: true,
    ),
    VideoNetworkQuality.medium: VideoDeliveryProfile(
      networkQuality: VideoNetworkQuality.medium,
      targetResolution: 720,
      bitrateKbps: 1800,
      preloadAhead: 3,
      bufferSeconds: 24,
      cacheMinutes: 75,
      adaptiveBitrate: true,
    ),
    VideoNetworkQuality.fast: VideoDeliveryProfile(
      networkQuality: VideoNetworkQuality.fast,
      targetResolution: 1080,
      bitrateKbps: 3500,
      preloadAhead: 4,
      bufferSeconds: 30,
      cacheMinutes: 120,
      adaptiveBitrate: true,
    ),
    VideoNetworkQuality.veryFast: VideoDeliveryProfile(
      networkQuality: VideoNetworkQuality.veryFast,
      targetResolution: 1080,
      bitrateKbps: 5000,
      preloadAhead: 5,
      bufferSeconds: 36,
      cacheMinutes: 180,
      adaptiveBitrate: true,
    ),
  };

  static VideoNetworkQuality classifyNetwork({
    required double throughputMbps,
    required int rebufferCount,
    required int startupMs,
    required double avgBufferPercent,
  }) {
    final normalizedThroughput = throughputMbps.isFinite
        ? throughputMbps.clamp(0.2, 20.0)
        : 0.2;

    final slowPenalty = rebufferCount * 0.9;
    final startupPenalty = startupMs > 0 ? (startupMs / 1000.0) * 0.12 : 0.0;
    final bufferPenalty = avgBufferPercent > 0 ? (1.0 - avgBufferPercent) * 2.5 : 0.0;

    final score = normalizedThroughput - slowPenalty - startupPenalty - bufferPenalty;

    if (score < 0.8) return VideoNetworkQuality.verySlow;
    if (score < 1.8) return VideoNetworkQuality.slow;
    if (score < 4.0) return VideoNetworkQuality.medium;
    if (score < 7.0) return VideoNetworkQuality.fast;
    return VideoNetworkQuality.veryFast;
  }

  static VideoDeliveryProfile resolve({
    required double throughputMbps,
    required int rebufferCount,
    required int startupMs,
    required double avgBufferPercent,
  }) {
    final quality = classifyNetwork(
      throughputMbps: throughputMbps,
      rebufferCount: rebufferCount,
      startupMs: startupMs,
      avgBufferPercent: avgBufferPercent,
    );
    return _profiles[quality]!;
  }

  static int estimatePreloadCount(VideoDeliveryProfile profile, {required bool userSwipingFast}) {
    if (userSwipingFast) {
      return math.max(1, profile.preloadAhead - 1);
    }
    return profile.preloadAhead;
  }
}
