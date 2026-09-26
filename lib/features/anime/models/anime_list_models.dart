/// The five personal states a member can give a title.
///
/// Favouriting is intentionally not a status: the heart on an anime page is a
/// separate flag so a title can be a favourite while still being watched.
enum AnimeListStatus {
  wantToWatch,
  watching,
  completed,
  watchLater,
  notInterested;

  /// The tab order used by "My list".
  static const tabs = <AnimeListStatus>[
    AnimeListStatus.wantToWatch,
    AnimeListStatus.watching,
    AnimeListStatus.completed,
    AnimeListStatus.watchLater,
    AnimeListStatus.notInterested,
  ];
}

extension AnimeListStatusCodec on AnimeListStatus {
  String get wireValue => switch (this) {
    AnimeListStatus.wantToWatch => 'want_to_watch',
    AnimeListStatus.watching => 'watching',
    AnimeListStatus.completed => 'completed',
    AnimeListStatus.watchLater => 'watch_later',
    AnimeListStatus.notInterested => 'not_interested',
  };

  /// Stable English source string; the visible label is always resolved
  /// through `AppTranslationMapping.statusMap`.
  String get label => switch (this) {
    AnimeListStatus.wantToWatch => 'plan to watch',
    AnimeListStatus.watching => 'watching',
    AnimeListStatus.completed => 'completed',
    AnimeListStatus.watchLater => 'plan to watch later',
    AnimeListStatus.notInterested => 'dropped',
  };

  /// Legacy documents are readable: the two retired states fold into the
  /// closest surviving one, and the retired `favorites` state becomes a
  /// favourite flag instead of a status.
  static AnimeListStatus? tryParse(String? value) {
    return switch (value) {
      'want_to_watch' || 'plan_to_watch' => AnimeListStatus.wantToWatch,
      'watching' => AnimeListStatus.watching,
      'completed' => AnimeListStatus.completed,
      'watch_later' || 'on_hold' => AnimeListStatus.watchLater,
      'not_interested' || 'dropped' => AnimeListStatus.notInterested,
      'favorites' => AnimeListStatus.wantToWatch,
      _ => null,
    };
  }

  /// True when the stored status was the retired `favorites` state, so the
  /// heart can be restored on read.
  static bool legacyFavorite(String? value) => value == 'favorites';
}

final class AnimeListEntry {
  const AnimeListEntry({
    required this.animeId,
    required this.status,
    this.title = '',
    this.rating,
    this.favorite = false,
    this.updatedAt,
  });

  final String animeId;
  final AnimeListStatus status;
  final String title;
  final int? rating;
  final bool favorite;
  final DateTime? updatedAt;

  AnimeListEntry copyWith({
    AnimeListStatus? status,
    String? title,
    int? rating,
    bool? favorite,
    DateTime? updatedAt,
  }) => AnimeListEntry(
    animeId: animeId,
    status: status ?? this.status,
    title: title ?? this.title,
    rating: rating ?? this.rating,
    favorite: favorite ?? this.favorite,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory AnimeListEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawStatus = map['status'] as String?;
    return AnimeListEntry(
      animeId: id ?? map['animeId'] as String? ?? '',
      status:
          AnimeListStatusCodec.tryParse(rawStatus) ??
          AnimeListStatus.wantToWatch,
      title: map['title'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt(),
      favorite:
          map['favorite'] == true ||
          AnimeListStatusCodec.legacyFavorite(rawStatus),
      updatedAt: readAnimeTimestamp(map['updatedAt']),
    );
  }
}

/// Reads a server timestamp that may arrive as a [DateTime], a Firestore
/// `Timestamp` serialized by the callable SDK, an epoch number or an ISO
/// string, and returns it in UTC. Anything unrecognised yields `null` so a
/// sort can fall back instead of throwing.
DateTime? readAnimeTimestamp(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is int) {
    // Firestore exposes seconds; anything larger is already milliseconds.
    final millis = raw.abs() < 100000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }
  if (raw is Map) {
    final seconds = raw['_seconds'] ?? raw['seconds'];
    if (seconds is num) {
      return readAnimeTimestamp(
        seconds.toInt() * 1000 +
            ((raw['_nanoseconds'] ?? 0) as num).toInt() ~/ 1000000,
      );
    }
    return null;
  }
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw)?.toUtc();
  }
  return null;
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

/// How "My list" renders a status tab.
enum AnimeListView { grid, network }

/// Client-side ordering for "My list". None of these are time-of-release
/// driven: they only react to what the member did or scored.
enum AnimeListSort {
  recentlyUpdated,
  titleAsc,
  titleDesc,
  ratingDesc,
  ratingAsc,
  popularityDesc,
  yearDesc,
  yearAsc;

  String get sourceKey => switch (this) {
    AnimeListSort.recentlyUpdated => 'recently updated',
    AnimeListSort.titleAsc => 'title a-z',
    AnimeListSort.titleDesc => 'title z-a',
    AnimeListSort.ratingDesc => 'highest rated',
    AnimeListSort.ratingAsc => 'lowest rated',
    AnimeListSort.popularityDesc => 'most popular',
    AnimeListSort.yearDesc => 'newest year',
    AnimeListSort.yearAsc => 'oldest year',
  };
}

/// Broadcast-format chips above "My list".
enum AnimeListFormatFilter {
  all,
  tv,
  ona,
  ova,
  movie,
  special,
  airing;

  String get wireValue => switch (this) {
    AnimeListFormatFilter.all => '',
    AnimeListFormatFilter.tv => 'TV',
    AnimeListFormatFilter.ona => 'ONA',
    AnimeListFormatFilter.ova => 'OVA',
    AnimeListFormatFilter.movie => 'Movie',
    AnimeListFormatFilter.special => 'Special',
    AnimeListFormatFilter.airing => 'airing',
  };

  /// `airing` is a state, not a format, so it maps through the status map
  /// while the rest go through the format map.
  bool get isAiringState => this == AnimeListFormatFilter.airing;
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
          (item) =>
              AnimeCustomListItem.fromMap(Map<String, dynamic>.from(item)),
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
