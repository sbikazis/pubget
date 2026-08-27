import '../../models/edit_interaction_model.dart';
import '../../models/edits_model.dart';

class FeedRecommendationEngine {
  static const int _shortTermWindow = 20;
  static const int _longTermMinInteractions = 5;

  static Map<String, double> buildInterestMap(
    List<EditInteractionModel> interactions,
  ) {
    final map = <String, double>{};
    for (final interaction in interactions) {
      final key = interaction.animeTitle.trim();
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0.0) + interaction.weight;
    }
    return map;
  }

  static Map<String, double> buildCreatorMap(
    List<EditInteractionModel> interactions,
  ) {
    final map = <String, double>{};
    for (final interaction in interactions) {
      final key = interaction.uploaderId.trim();
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0.0) + interaction.weight;
    }
    return map;
  }

  static Map<String, double> buildSessionIntentMap(
    List<EditInteractionModel> interactions,
  ) {
    final recent = interactions.take(_shortTermWindow).toList();
    return buildInterestMap(recent);
  }

  static double scoreEdit({
    required EditModel edit,
    required Map<String, double> longTermInterests,
    required Map<String, double> shortTermInterests,
    required Map<String, double> creatorAffinity,
    required int recentExposureCount,
    required bool isFresh,
    required double qualitySignal,
    required double diversityBoost,
  }) {
    final longTerm = longTermInterests[edit.animeTitle] ?? 0.0;
    final shortTerm = shortTermInterests[edit.animeTitle] ?? 0.0;
    final creatorAffinityScore = creatorAffinity[edit.uploaderId] ?? 0.0;

    final relevance = (longTerm * 0.45) + (shortTerm * 0.35);
    final freshness = isFresh ? 0.25 : 0.0;
    final creator = creatorAffinityScore * 0.15;
    final engagement = qualitySignal * 0.30;
    final diversity = diversityBoost * 0.15;
    final repetitionPenalty = recentExposureCount > 0 ? (recentExposureCount * 0.08) : 0.0;

    return relevance + freshness + creator + engagement + diversity - repetitionPenalty;
  }

  static List<EditModel> rankCandidates({
    required List<EditModel> candidates,
    required List<EditInteractionModel> interactions,
    required Set<String> recentlySeen,
  }) {
    final longTerm = buildInterestMap(interactions);
    final shortTerm = buildSessionIntentMap(interactions);
    final creatorAffinity = buildCreatorMap(interactions);

    final now = DateTime.now();
    final scored = candidates.map((edit) {
      final ageHours = now.difference(edit.createdAt).inHours;
      final isFresh = ageHours <= 72;
      final relevantExposure = interactions
          .where((i) => i.animeTitle == edit.animeTitle)
          .length;

      final qualitySignal = edit.views > 0
          ? ((edit.likes.length / edit.views) * 0.5) +
              ((edit.avgWatchPercent.clamp(0.0, 1.0)) * 0.4) +
              ((edit.commentsCount / (edit.views + 1)) * 0.25)
          : 0.25;

      final diversityBoost = recentlySeen.contains(edit.id) ? 0.0 : 0.18;
      final score = scoreEdit(
        edit: edit,
        longTermInterests: longTerm,
        shortTermInterests: shortTerm,
        creatorAffinity: creatorAffinity,
        recentExposureCount: relevantExposure,
        isFresh: isFresh,
        qualitySignal: qualitySignal.clamp(0.0, 1.0),
        diversityBoost: diversityBoost,
      );

      return _RankedEdit(edit: edit, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    final result = <EditModel>[];
    final seenAnime = <String>{};
    final seenCreators = <String>{};

    for (final ranked in scored) {
      final edit = ranked.edit;
      if (seenAnime.length >= 3 && seenAnime.contains(edit.animeTitle)) {
        continue;
      }
      if (seenCreators.length >= 3 && seenCreators.contains(edit.uploaderId)) {
        continue;
      }
      result.add(edit);
      if (edit.animeTitle.isNotEmpty) seenAnime.add(edit.animeTitle);
      if (edit.uploaderId.isNotEmpty) seenCreators.add(edit.uploaderId);
    }

    return result;
  }

  static bool isColdStart(List<EditInteractionModel> interactions) {
    final meaningful = interactions.where((i) => i.weight > 0 && i.type != InteractionType.skip).toList();
    return meaningful.length < _longTermMinInteractions;
  }
}

class _RankedEdit {
  final EditModel edit;
  final double score;

  _RankedEdit({required this.edit, required this.score});
}
