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
    this.imageUrl,
    this.rating,
  });

  final String characterId;
  final String name;
  final String? imageUrl;
  final int? rating;

  factory CharacterFavorite.fromMap(Map<String, dynamic> map, {String? id}) {
    return CharacterFavorite(
      characterId: id ?? map['characterId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      rating: (map['rating'] as num?)?.toInt(),
    );
  }
}

final class AnimeCustomList {
  const AnimeCustomList({
    required this.id,
    required this.name,
    this.description = '',
    this.private = false,
    this.itemsCount = 0,
    this.ownerUid = '',
  });

  final String id;
  final String name;
  final String description;
  final bool private;
  final int itemsCount;
  final String ownerUid;

  AnimeCustomList copyWith({
    String? name,
    String? description,
    bool? private,
    int? itemsCount,
  }) {
    return AnimeCustomList(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      private: private ?? this.private,
      itemsCount: itemsCount ?? this.itemsCount,
      ownerUid: ownerUid,
    );
  }

  factory AnimeCustomList.fromMap(Map<String, dynamic> map, {String? id}) {
    return AnimeCustomList(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      private: map['private'] == true,
      itemsCount: (map['itemsCount'] as num?)?.toInt() ?? 0,
      ownerUid: map['ownerUid'] as String? ?? '',
    );
  }
}

final class AnimeCustomListItem {
  const AnimeCustomListItem({required this.animeId, this.title = ''});

  final String animeId;
  final String title;

  factory AnimeCustomListItem.fromMap(Map<String, dynamic> map) {
    return AnimeCustomListItem(
      animeId: map['animeId'] as String? ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
    );
  }
}

final class AnimeCustomListDetail {
  const AnimeCustomListDetail({required this.list, this.items = const []});

  final AnimeCustomList list;
  final List<AnimeCustomListItem> items;

  factory AnimeCustomListDetail.fromMap(Map<String, dynamic> map) {
    final rawList = map['list'];
    final list = rawList is Map
        ? AnimeCustomList.fromMap(Map<String, dynamic>.from(rawList))
        : const AnimeCustomList(id: '', name: '');
    final rawItems = map['items'] as List<Object?>? ?? const <Object?>[];
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) => AnimeCustomListItem.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return AnimeCustomListDetail(list: list, items: items);
  }
}

final class CustomListMembership {
  const CustomListMembership({required this.listId, this.name = ''});

  final String listId;
  final String name;

  factory CustomListMembership.fromMap(Map<String, dynamic> map) {
    return CustomListMembership(
      listId: map['listId'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }
}
