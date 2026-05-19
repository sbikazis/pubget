import '../../models/edits_model.dart';
import '../../models/edit_interaction_model.dart';

class FeedRankingLogic {
  // ══════════════════════════════════════════════
  // ── بناء بصمة الاهتمام من تفاعلات المستخدم
  // ══════════════════════════════════════════════

  // أنمي مفضل: animeTitle → وزن مجمّع
  static Map<String, double> buildAnimeInterestMap(
      List<EditInteractionModel> interactions) {
    final Map<String, double> map = {};
    for (final i in interactions) {
      if (i.animeTitle.isEmpty) continue;
      map[i.animeTitle] = (map[i.animeTitle] ?? 0.0) + i.weight;
    }
    return map;
  }

  // ناشرون مفضلون: uploaderId → وزن مجمّع
  static Map<String, double> buildUploaderInterestMap(
      List<EditInteractionModel> interactions) {
    final Map<String, double> map = {};
    for (final i in interactions) {
      if (i.uploaderId.isEmpty) continue;
      map[i.uploaderId] = (map[i.uploaderId] ?? 0.0) + i.weight;
    }
    return map;
  }

  // ══════════════════════════════════════════════
  // ── حساب نقاط تطابق الاهتمام (0.0 → 1.0)
  // ══════════════════════════════════════════════

  static double _interestScore(
    EditModel edit,
    Map<String, double> animeMap,
    Map<String, double> uploaderMap,
  ) {
    if (animeMap.isEmpty && uploaderMap.isEmpty) return 0.0;

    final animeScore = animeMap[edit.animeTitle] ?? 0.0;
    final uploaderScore = uploaderMap[edit.uploaderId] ?? 0.0;

    final maxAnime = animeMap.values.isEmpty
        ? 1.0
        : animeMap.values.reduce((a, b) => a > b ? a : b);
    final maxUploader = uploaderMap.values.isEmpty
        ? 1.0
        : uploaderMap.values.reduce((a, b) => a > b ? a : b);

    final normalizedAnime = maxAnime > 0 ? animeScore / maxAnime : 0.0;
    final normalizedUploader =
        maxUploader > 0 ? uploaderScore / maxUploader : 0.0;

    // الأنمي أهم من الناشر
    return (normalizedAnime * 0.7) + (normalizedUploader * 0.3);
  }

  // ══════════════════════════════════════════════
  // ── حساب جودة الإيديت (0.0 → 1.0)
  // ══════════════════════════════════════════════

  static double _qualityScore(EditModel edit) {
    final likeRatio =
        edit.views > 0 ? edit.likes.length / edit.views : 0.0;
    final watchScore = edit.avgWatchPercent; // 0.0 → 1.0
    final engagementScore =
        edit.views > 0 ? edit.commentsCount / edit.views : 0.0;

    // نسبة اللايكات 50%، متوسط المشاهدة 35%، الكومنتات 15%
    return (likeRatio.clamp(0.0, 1.0) * 0.5) +
        (watchScore.clamp(0.0, 1.0) * 0.35) +
        (engagementScore.clamp(0.0, 1.0) * 0.15);
  }

  // ══════════════════════════════════════════════
  // ── حساب نقاط الحداثة (0.0 → 1.0)
  // ══════════════════════════════════════════════

  static double _freshnessScore(EditModel edit) {
    final ageHours =
        DateTime.now().difference(edit.createdAt).inHours.toDouble();

    // boost قوي في أول 24 ساعة، يتلاشى تدريجياً بعدها
    if (ageHours <= 24) return 1.0 - (ageHours / 24.0) * 0.3;
    if (ageHours <= 72) return 0.7 - ((ageHours - 24) / 48.0) * 0.3;
    if (ageHours <= 168) return 0.4 - ((ageHours - 72) / 96.0) * 0.2;
    return 0.2 * (1.0 / (1.0 + ageHours / 720.0)); // تلاشي بطيء بعد أسبوع
  }

  // ══════════════════════════════════════════════
  // ── المعادلة النهائية
  // النقاط = (تطابق الاهتمام × 40%) + (جودة × 35%) + (حداثة × 25%)
  // ══════════════════════════════════════════════

  static double computeFinalScore(
    EditModel edit,
    Map<String, double> animeMap,
    Map<String, double> uploaderMap,
  ) {
    final interest = _interestScore(edit, animeMap, uploaderMap);
    final quality = _qualityScore(edit);
    final freshness = _freshnessScore(edit);

    return (interest * 0.40) + (quality * 0.35) + (freshness * 0.25);
  }

  // ══════════════════════════════════════════════
  // ── ترتيب الـ Feed مع ضمان التنوع
  // لا إيديتين متتاليتين لنفس الأنمي أو نفس الناشر
  // ══════════════════════════════════════════════

  static List<EditModel> rankAndDiversify(
    List<EditModel> edits,
    Map<String, double> animeMap,
    Map<String, double> uploaderMap,
  ) {
    // ترتيب بالنقاط أولاً
    final scored = edits.map((e) {
      final s = computeFinalScore(e, animeMap, uploaderMap);
      return _ScoredEdit(edit: e, score: s);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final List<EditModel> result = [];
    final List<_ScoredEdit> remaining = List.from(scored);

    String? lastAnime;
    String? lastUploader;

    while (remaining.isNotEmpty) {
      // ابحث عن أول إيديت لا يكرر الأنمي أو الناشر
      int pickedIdx = -1;
      for (int i = 0; i < remaining.length; i++) {
        final e = remaining[i].edit;
        if (e.animeTitle != lastAnime && e.uploaderId != lastUploader) {
          pickedIdx = i;
          break;
        }
      }

      // إذا لم يوجد بديل، خذ الأعلى نقاطاً بدون قيد
      if (pickedIdx == -1) pickedIdx = 0;

      final picked = remaining.removeAt(pickedIdx);
      result.add(picked.edit);
      lastAnime = picked.edit.animeTitle;
      lastUploader = picked.edit.uploaderId;
    }

    return result;
  }

  // ══════════════════════════════════════════════
  // ── Cold Start: أفضل الإيديتات عالمياً بالنقاط
  // ══════════════════════════════════════════════

  static List<EditModel> coldStartRank(List<EditModel> edits) {
    return rankAndDiversify(edits, {}, {});
  }

  // ── هل المستخدم تجاوز مرحلة Cold Start؟ (5 تفاعلات حقيقية)
  static bool isPastColdStart(List<EditInteractionModel> interactions) {
    final meaningful = interactions.where(
      (i) => i.type != InteractionType.skip && i.weight > 0,
    );
    return meaningful.length >= 5;
  }
}

// helper داخلي
class _ScoredEdit {
  final EditModel edit;
  final double score;
  _ScoredEdit({required this.edit, required this.score});
}