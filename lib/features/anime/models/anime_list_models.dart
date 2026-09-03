enum AnimeListStatus {
  watching,
  completed,
  planToWatch,
  dropped,
  onHold,
  favorites,
}

extension AnimeListStatusCodec on AnimeListStatus {
  String get wireValue => switch (this) {
    AnimeListStatus.watching => 'watching',
    AnimeListStatus.completed => 'completed',
    AnimeListStatus.planToWatch => 'plan_to_watch',
    AnimeListStatus.dropped => 'dropped',
    AnimeListStatus.onHold => 'on_hold',
    AnimeListStatus.favorites => 'favorites',
  };

  String get label => switch (this) {
    AnimeListStatus.watching => 'Watching',
    AnimeListStatus.completed => 'Completed',
    AnimeListStatus.planToWatch => 'Plan to watch',
    AnimeListStatus.dropped => 'Dropped',
    AnimeListStatus.onHold => 'On hold',
    AnimeListStatus.favorites => 'Favorites',
  };

  static AnimeListStatus? tryParse(String? value) {
    return switch (value) {
      'watching' => AnimeListStatus.watching,
      'completed' => AnimeListStatus.completed,
      'plan_to_watch' => AnimeListStatus.planToWatch,
      'dropped' => AnimeListStatus.dropped,
      'on_hold' => AnimeListStatus.onHold,
      'favorites' => AnimeListStatus.favorites,
      _ => null,
    };
  }
}

final class AnimeListEntry {
  const AnimeListEntry({
    required this.animeId,
    required this.status,
    this.title = '',
    this.rating,
    this.updatedAt,
  });

  final String animeId;
  final AnimeListStatus status;
  final String title;
  final int? rating;
  final DateTime? updatedAt;

  factory AnimeListEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final status =
        AnimeListStatusCodec.tryParse(map['status'] as String?) ??
        AnimeListStatus.planToWatch;
    return AnimeListEntry(
      animeId: id ?? map['animeId'] as String? ?? '',
      status: status,
      title: map['title'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt(),
    );
  }
}

final class AnimeListPage {
  const AnimeListPage({
    this.items = const <AnimeListEntry>[],
    this.cursor,
    this.hasMore = false,
  });

  final List<AnimeListEntry> items;
  final String? cursor;
  final bool hasMore;

  factory AnimeListPage.fromMap(Map<String, dynamic> map) {
    final raw = map['items'] as List<Object?>? ?? const <Object?>[];
    return AnimeListPage(
      items: raw
          .whereType<Map>()
          .map(
            (item) => AnimeListEntry.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      cursor: map['cursor'] as String?,
      hasMore: map['hasMore'] == true,
    );
  }
}

final class CharacterFavorite {
  const CharacterFavorite({
    required this.characterId,
    this.name = '',
    this.rating,
  });

  final String characterId;
  final String name;
  final int? rating;

  factory CharacterFavorite.fromMap(Map<String, dynamic> map, {String? id}) {
    return CharacterFavorite(
      characterId: id ?? map['characterId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt(),
    );
  }
}
