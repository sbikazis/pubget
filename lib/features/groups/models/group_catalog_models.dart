import '../../anime/models/anime_models.dart';
import 'group_models.dart';

/// The browse axes a group picker can be scoped to. Mirrors the server's
/// `browseAnime`, so a rank, a broadcast season, or a whole-catalog search all
/// resolve through the same answer.
enum GroupCatalogKind {
  trending,
  popular,
  top,
  airing,
  upcoming,
  thisSeason,
  season,
}

/// One catalog title as the server resolved it. The id is the server's, so a
/// group stores exactly what the catalog said and never a client guess.
final class CatalogAnime {
  const CatalogAnime({
    required this.id,
    required this.title,
    this.alternativeTitles = const <String>[],
    this.imageUrl = '',
    this.year,
    this.season,
    this.type,
    this.status,
    this.episodes,
    this.genres = const <String>[],
    this.studios = const <String>[],
  });

  final String id;
  final String title;
  final List<String> alternativeTitles;
  final String imageUrl;
  final int? year;
  final String? season;
  final String? type;
  final String? status;
  final int? episodes;
  final List<String> genres;
  final List<String> studios;

  String get subtitleParts => <String>[
    if (year != null) '$year',
    if (season != null && season!.isNotEmpty) season!,
    if (type != null && type!.isNotEmpty && type != 'Unknown') type!,
  ].join(' · ');

  /// The catalog answer, expressed as the `Anime` the group wizard stores.
  /// Nothing here is derived on the device: the id, the year, and the season
  /// are the ones the catalog resolved, so what the user picked is what the
  /// group will be created against.
  Anime toAnime() => Anime(
    id: id,
    title: title,
    alternativeTitles: alternativeTitles,
    type: type,
    status: status,
    episodes: episodes,
    year: year,
    season: AnimeSeason.tryParse(season),
    genres: <AnimeGenre>[
      for (final genre in genres)
        AnimeGenre(id: genre.toLowerCase().replaceAll(' ', '-'), name: genre),
    ],
    studios: studios,
    images: AnimeImages(
      thumbnailUrl: imageUrl.isEmpty ? null : imageUrl,
      largeUrl: imageUrl.isEmpty ? null : imageUrl,
    ),
  );

  factory CatalogAnime.fromMap(Map<String, dynamic> map) => CatalogAnime(
    id: (map['id'] as String? ?? '').trim(),
    title: (map['title'] as String? ?? '').trim(),
    alternativeTitles: _strings(map['alternativeTitles']),
    imageUrl: (map['imageUrl'] as String? ?? '').trim(),
    year: (map['year'] as num?)?.toInt(),
    season: map['season'] as String?,
    type: map['type'] as String?,
    status: map['status'] as String?,
    episodes: (map['episodes'] as num?)?.toInt(),
    genres: _strings(map['genres']),
    studios: _strings(map['studios']),
  );
}

/// One broadcast season of a work, as the catalog knows it. A character is
/// tagged with the seasons it appears in so a group pinned to season 1 can
/// still offer a character introduced in season 3.
final class CatalogSeason {
  const CatalogSeason({
    required this.id,
    required this.title,
    this.year,
    this.season,
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final int? year;
  final String? season;
  final String imageUrl;

  String get label => <String>[
    if (year != null) '$year',
    if (season != null && season!.isNotEmpty) season!,
  ].join(' · ');

  factory CatalogSeason.fromMap(Map<String, dynamic> map) => CatalogSeason(
    id: (map['id'] as String? ?? '').trim(),
    title: (map['title'] as String? ?? '').trim(),
    year: (map['year'] as num?)?.toInt(),
    season: map['season'] as String?,
    imageUrl: (map['imageUrl'] as String? ?? '').trim(),
  );
}

final class GroupCatalogPage {
  const GroupCatalogPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });

  const GroupCatalogPage.empty()
    : items = const <CatalogAnime>[],
      page = 1,
      hasNextPage = false;

  final List<CatalogAnime> items;
  final int page;
  final bool hasNextPage;

  factory GroupCatalogPage.fromMap(Map<String, dynamic> map) => GroupCatalogPage(
    items: _maps(map['items'])
        .map(CatalogAnime.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false),
    page: (map['page'] as num?)?.toInt() ?? 1,
    hasNextPage: map['hasNextPage'] == true,
  );
}

/// One page of a roleplay roster.
final class GroupCharacterPage {
  const GroupCharacterPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
    this.seasons = const <CatalogSeason>[],
  });

  const GroupCharacterPage.empty()
    : items = const <RoleplayCharacter>[],
      page = 1,
      hasNextPage = false,
      seasons = const <CatalogSeason>[];

  final List<RoleplayCharacter> items;
  final int page;
  final bool hasNextPage;

  /// Every season of the work the group is bound to, root first. Empty for an
  /// open roleplay group, which is not tied to one work.
  final List<CatalogSeason> seasons;

  factory GroupCharacterPage.fromMap(Map<String, dynamic> map) =>
      GroupCharacterPage(
        items: _maps(map['items'])
            .map(RoleplayCharacter.fromCatalogMap)
            .where((item) => item.key.isNotEmpty)
            .toList(growable: false),
        page: (map['page'] as num?)?.toInt() ?? 1,
        hasNextPage: map['hasNextPage'] == true,
        seasons: _maps(map['seasons'])
            .map(CatalogSeason.fromMap)
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false),
      );
}

List<String> _strings(Object? value) =>
    (value as List<Object?>? ?? const <Object?>[]).whereType<String>().toList();

List<Map<String, dynamic>> _maps(Object? value) => <Map<String, dynamic>>[
  for (final entry in (value as List<Object?>? ?? const <Object?>[]))
    if (entry is Map) Map<String, dynamic>.from(entry),
];
