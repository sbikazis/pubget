/// Canonical product limits. Feature code must import this file instead of
/// repeating magic numbers (fan threshold, edit windows, etc.).
abstract final class Limits {
  static const int fanThreshold = 5;
  static const int respectMin = 1;
  static const int respectMax = 7;

  static const int editMaxDurationSeconds = 180;
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
}
