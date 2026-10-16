/// Canonical product limits. Feature code must import this file instead of
/// repeating magic numbers (fan threshold, edit windows, etc.).
///
/// The server is the source of truth — see `functions/src/editsConfig.js`.
/// These mirror it for pre-flight validation only; the server re-validates
/// every write and Storage rules enforce the hard limit.
abstract final class Limits {
  static const int fanThreshold = 5;
  static const int respectMin = 1;
  static const int respectMax = 7;

  /// Axis 15 §15.2 — Reels are 3–60s. This was 180 here while the UI said
  /// "3 minutes" and the dead reels config said 60; all three now agree.
  static const int editMinDurationSeconds = 3;
  static const int editMaxDurationSeconds = 60;

  /// Spec target is 500MB, but the media pipeline downloads the whole source
  /// into the 512MB gen2 /tmp, so 100MB is the safe ceiling until the upload
  /// pipeline moves to streaming. See docs/axis-15-phase-0-audit.md.
  static const int editMaxBytes = 100 * 1024 * 1024;
  static const int editQualifiedViewPercent = 10;
  static const int editCompletionPercent = 90;
  static const Duration editRepostWindow = Duration(days: 30);
  static const int editCaptionMax = 1000;
  static const int editAnimeTagMax = 128;
  static const int editCommentMax = 500;
  static const int editStickerMax = 32;
  static const int editMentionMax = 8;
  static const int editFeedPageSize = 5;
  static const int editPrefetchCount = 1;

  /// §15.7 — must match TAG_LIMITS in functions/src/editsConfig.js.
  static const int editHashtagsMax = 12;
  static const int editHashtagMaxLength = 64;
  static const int editCharacterIdsMax = 8;
  static const int editCharacterIdMaxLength = 128;
}
