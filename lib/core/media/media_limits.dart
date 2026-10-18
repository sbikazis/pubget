import '../constants/limits.dart';
import 'media_kind.dart';

/// Every size/duration boundary of the media layer in one configurable place.
///
/// Values are the agreed defaults: Reels stay inside the product's locked
/// 3–60 s window ([Limits]), images aim for ~150 KB after compression, Reels
/// aim for ≤5 MB, and nothing may exceed the hard ceilings below no matter
/// what compression did. The server (`worker/src/validation.js`) and the
/// storage rules re-enforce the same numbers — this class only gives the app
/// a fast, honest pre-flight.
final class MediaLimits {
  const MediaLimits({
    this.imageTargetBytes = 150 * 1024,
    this.imageMaxBytes = 10 * 1024 * 1024,
    this.reelsTargetBytes = 5 * 1024 * 1024,
    this.reelsMaxBytes = 5 * 1024 * 1024,
    this.audioMaxBytes = 50 * 1024 * 1024,
    this.reelsMinDurationSeconds = Limits.editMinDurationSeconds,
    this.reelsMaxDurationSeconds = Limits.editMaxDurationSeconds,
    this.audioMaxDurationSeconds = 300,
    this.maxUploadAttempts = 3,
    this.allowUnverifiedAudioDuration = true,
  });

  /// Post-compression goal for images. Not a rejection threshold.
  final int imageTargetBytes;

  /// Absolute image ceiling — enforced after compression, always.
  final int imageMaxBytes;

  /// Post-compression goal for Reels video.
  final int reelsTargetBytes;

  /// Absolute Reels ceiling. No on-device video compression exists yet, so a
  /// file above this is rejected rather than uploaded oversized.
  final int reelsMaxBytes;

  /// Absolute audio ceiling.
  final int audioMaxBytes;

  final int reelsMinDurationSeconds;
  final int reelsMaxDurationSeconds;
  final int audioMaxDurationSeconds;

  /// Client-side attempt cap for one logical upload.
  final int maxUploadAttempts;

  /// When false, audio whose duration cannot be verified is rejected.
  final bool allowUnverifiedAudioDuration;

  /// Absolute ceiling for [kind]; bytes above this must never be uploaded.
  int maxBytesFor(MediaKind kind) => switch (kind) {
        MediaKind.image => imageMaxBytes,
        MediaKind.reels => reelsMaxBytes,
        MediaKind.audio => audioMaxBytes,
      };

  /// Post-compression goal for [kind]; null when the kind has no target.
  int? targetBytesFor(MediaKind kind) => switch (kind) {
        MediaKind.image => imageTargetBytes,
        MediaKind.reels => reelsTargetBytes,
        MediaKind.audio => null,
      };

  /// Whether [duration] is acceptable for [kind]. Null means "unverified".
  bool allowsDuration(MediaKind kind, Duration? duration) {
    switch (kind) {
      case MediaKind.image:
        return true;
      case MediaKind.reels:
        if (duration == null) return false;
        final seconds = duration.inSeconds;
        return seconds >= reelsMinDurationSeconds &&
            seconds <= reelsMaxDurationSeconds;
      case MediaKind.audio:
        if (duration == null) return allowUnverifiedAudioDuration;
        return duration <= Duration(seconds: audioMaxDurationSeconds);
    }
  }
}
