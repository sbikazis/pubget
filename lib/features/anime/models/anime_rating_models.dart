enum AnimeRatingCriterion {
  story,
  art,
  characters,
  action,
  sound,
  enjoyment;

  String get id => name;

  String get label => switch (this) {
    AnimeRatingCriterion.story => 'Story',
    AnimeRatingCriterion.art => 'Art',
    AnimeRatingCriterion.characters => 'Characters',
    AnimeRatingCriterion.action => 'Action',
    AnimeRatingCriterion.sound => 'Sound',
    AnimeRatingCriterion.enjoyment => 'Enjoyment',
  };
}

final class AnimeCriteriaScores {
  const AnimeCriteriaScores({
    required this.story,
    required this.art,
    required this.characters,
    required this.action,
    required this.sound,
    required this.enjoyment,
  });

  final int story;
  final int art;
  final int characters;
  final int action;
  final int sound;
  final int enjoyment;

  static const empty = AnimeCriteriaScores(
    story: 0,
    art: 0,
    characters: 0,
    action: 0,
    sound: 0,
    enjoyment: 0,
  );

  double get overall {
    const count = 6;
    return (story + art + characters + action + sound + enjoyment) / count;
  }

  int scoreFor(AnimeRatingCriterion criterion) => switch (criterion) {
    AnimeRatingCriterion.story => story,
    AnimeRatingCriterion.art => art,
    AnimeRatingCriterion.characters => characters,
    AnimeRatingCriterion.action => action,
    AnimeRatingCriterion.sound => sound,
    AnimeRatingCriterion.enjoyment => enjoyment,
  };

  AnimeCriteriaScores withScore(AnimeRatingCriterion criterion, int score) {
    final clamped = score.clamp(0, 10);
    return switch (criterion) {
      AnimeRatingCriterion.story => AnimeCriteriaScores(
        story: clamped,
        art: art,
        characters: characters,
        action: action,
        sound: sound,
        enjoyment: enjoyment,
      ),
      AnimeRatingCriterion.art => AnimeCriteriaScores(
        story: story,
        art: clamped,
        characters: characters,
        action: action,
        sound: sound,
        enjoyment: enjoyment,
      ),
      AnimeRatingCriterion.characters => AnimeCriteriaScores(
        story: story,
        art: art,
        characters: clamped,
        action: action,
        sound: sound,
        enjoyment: enjoyment,
      ),
      AnimeRatingCriterion.action => AnimeCriteriaScores(
        story: story,
        art: art,
        characters: characters,
        action: clamped,
        sound: sound,
        enjoyment: enjoyment,
      ),
      AnimeRatingCriterion.sound => AnimeCriteriaScores(
        story: story,
        art: art,
        characters: characters,
        action: action,
        sound: clamped,
        enjoyment: enjoyment,
      ),
      AnimeRatingCriterion.enjoyment => AnimeCriteriaScores(
        story: story,
        art: art,
        characters: characters,
        action: action,
        sound: sound,
        enjoyment: clamped,
      ),
    };
  }

  Map<String, int> toMap() => <String, int>{
    'story': story,
    'art': art,
    'characters': characters,
    'action': action,
    'sound': sound,
    'enjoyment': enjoyment,
  };

  factory AnimeCriteriaScores.fromMap(Map<String, dynamic>? map) {
    int read(String key) => ((map?[key] as num?)?.toInt() ?? 0).clamp(0, 10);
    return AnimeCriteriaScores(
      story: read('story'),
      art: read('art'),
      characters: read('characters'),
      action: read('action'),
      sound: read('sound'),
      enjoyment: read('enjoyment'),
    );
  }
}

final class AnimeCommunityStats {
  const AnimeCommunityStats({
    required this.animeId,
    this.title = '',
    this.imageUrl,
    this.averageScore = 0,
    this.ratingCount = 0,
  });

  final String animeId;
  final String title;
  final String? imageUrl;
  final double averageScore;
  final int ratingCount;

  bool get hasRatings => ratingCount > 0;

  factory AnimeCommunityStats.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AnimeCommunityStats(
      animeId: id ?? map['animeId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      averageScore: (map['averageScore'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

enum AnimeScoreSource { app, mal }

final class AnimeDisplayedScore {
  const AnimeDisplayedScore({required this.value, required this.source});

  final double value;
  final AnimeScoreSource source;

  String get badge => source == AnimeScoreSource.app ? 'A' : 'M';

  static AnimeDisplayedScore? resolve({
    double? malScore,
    AnimeCommunityStats? community,
  }) {
    if (community != null && community.hasRatings) {
      return AnimeDisplayedScore(
        value: community.averageScore,
        source: AnimeScoreSource.app,
      );
    }
    if (malScore != null) {
      return AnimeDisplayedScore(
        value: malScore,
        source: AnimeScoreSource.mal,
      );
    }
    return null;
  }
}

final class AnimeReview {
  const AnimeReview({
    required this.animeId,
    required this.userId,
    this.username = '',
    this.title = '',
    this.imageUrl,
    this.criteria = AnimeCriteriaScores.empty,
    this.overall = 0,
    this.comment = '',
  });

  final String animeId;
  final String userId;
  final String username;
  final String title;
  final String? imageUrl;
  final AnimeCriteriaScores criteria;
  final double overall;
  final String comment;

  factory AnimeReview.fromMap(Map<String, dynamic> map, {String? id}) {
    final criteriaRaw = map['criteria'];
    return AnimeReview(
      animeId: map['animeId'] as String? ?? '',
      userId: id ?? map['userId'] as String? ?? '',
      username: map['username'] as String? ?? '',
      title: map['title'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      criteria: AnimeCriteriaScores.fromMap(
        criteriaRaw is Map ? Map<String, dynamic>.from(criteriaRaw) : null,
      ),
      overall: (map['overall'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String? ?? '',
    );
  }
}

final class CharacterCommunityStats {
  const CharacterCommunityStats({
    required this.characterId,
    this.name = '',
    this.imageUrl,
    this.favoritesCount = 0,
  });

  final String characterId;
  final String name;
  final String? imageUrl;
  final int favoritesCount;

  factory CharacterCommunityStats.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return CharacterCommunityStats(
      characterId: id ?? map['characterId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      favoritesCount: (map['favoritesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
