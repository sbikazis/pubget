import '../models/anime_models.dart';

/// Serializes anime catalog models to JSON-safe maps for the durable
/// Firestore cache and restores them to fresh domain objects.
abstract final class AnimeCacheCodec {
  static Anime animeFromMap(Map<String, dynamic> map) {
    return Anime(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      alternativeTitles: _stringList(map['alternativeTitles']),
      synopsis: map['synopsis'] as String?,
      type: map['type'] as String?,
      status: map['status'] as String?,
      score: _double(map['score']),
      rank: _int(map['rank']),
      popularity: _int(map['popularity']),
      episodes: _int(map['episodes']),
      duration: map['duration'] as String?,
      startDate: _date(map['startDate']),
      endDate: _date(map['endDate']),
      season: AnimeSeason.tryParse(map['season'] as String?),
      year: _int(map['year']),
      genres: (map['genres'] as List? ?? const [])
          .map(
            (item) => AnimeCacheCodec.genreFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      studios: _stringList(map['studios']),
      producers: _stringList(map['producers']),
      relations: (map['relations'] as List? ?? const [])
          .map(
            (item) => AnimeCacheCodec.relationFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      source: map['source'] as String?,
      rating: map['rating'] as String?,
      images: AnimeImages(
        thumbnailUrl: map['thumbnailUrl'] as String?,
        largeUrl: map['largeUrl'] as String?,
      ),
      trailerUrl: map['trailerUrl'] as String?,
      externalLinks: (map['externalLinks'] as List? ?? const [])
          .map(
            (item) => AnimeExternalLink(
              label: (item as Map)['label'] as String? ?? '',
              url: item['url'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      nextEpisodeLabel: map['nextEpisodeLabel'] as String?,
      airing: map['airing'] as bool?,
    );
  }

  static Map<String, dynamic> animeToMap(Anime anime) {
    return <String, dynamic>{
      'id': anime.id,
      'title': anime.title,
      'alternativeTitles': anime.alternativeTitles,
      'synopsis': anime.synopsis,
      'type': anime.type,
      'status': anime.status,
      'score': anime.score,
      'rank': anime.rank,
      'popularity': anime.popularity,
      'episodes': anime.episodes,
      'duration': anime.duration,
      'startDate': anime.startDate?.toIso8601String(),
      'endDate': anime.endDate?.toIso8601String(),
      'season': anime.season?.name,
      'year': anime.year,
      'genres': anime.genres.map(AnimeCacheCodec.genreToMap).toList(),
      'studios': anime.studios,
      'producers': anime.producers,
      'relations': anime.relations.map(AnimeCacheCodec.relationToMap).toList(),
      'source': anime.source,
      'rating': anime.rating,
      'thumbnailUrl': anime.images.thumbnailUrl,
      'largeUrl': anime.images.largeUrl,
      'trailerUrl': anime.trailerUrl,
      'externalLinks': anime.externalLinks
          .map(
            (link) => <String, dynamic>{'label': link.label, 'url': link.url},
          )
          .toList(),
      'nextEpisodeLabel': anime.nextEpisodeLabel,
      'airing': anime.airing,
    };
  }

  static AnimePage pageFromMap(Map<String, dynamic> map) {
    return AnimePage(
      items: (map['items'] as List? ?? const [])
          .map(
            (item) => AnimeCacheCodec.animeFromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      page: _int(map['page']) ?? 1,
      hasNextPage: map['hasNextPage'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> pageToMap(AnimePage page) {
    return <String, dynamic>{
      'items': page.items.map(AnimeCacheCodec.animeToMap).toList(),
      'page': page.page,
      'hasNextPage': page.hasNextPage,
    };
  }

  static AnimeGenre genreFromMap(Map<String, dynamic> map) {
    return AnimeGenre(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      kind: AnimeTagKind.values.asNameMap()[map['kind']] ?? AnimeTagKind.genre,
      count: _int(map['count']),
    );
  }

  static Map<String, dynamic> genreToMap(AnimeGenre genre) {
    return <String, dynamic>{
      'id': genre.id,
      'name': genre.name,
      'kind': genre.kind.name,
      'count': genre.count,
    };
  }

  static AnimeRelated relationFromMap(Map<String, dynamic> map) {
    return AnimeRelated(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      relation: map['relation'] as String? ?? '',
      type: map['type'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  static Map<String, dynamic> relationToMap(AnimeRelated relation) {
    return <String, dynamic>{
      'id': relation.id,
      'title': relation.title,
      'relation': relation.relation,
      'type': relation.type,
      'imageUrl': relation.imageUrl,
    };
  }

  static AnimeStudio studioFromMap(Map<String, dynamic> map) {
    return AnimeStudio(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      count: _int(map['count']),
    );
  }

  static Map<String, dynamic> studioToMap(AnimeStudio studio) {
    return <String, dynamic>{
      'id': studio.id,
      'name': studio.name,
      'count': studio.count,
    };
  }

  static List<AnimeStudio> studiosFromMap(Map<String, dynamic> map) {
    return (map['items'] as List? ?? const [])
        .map(
          (item) => AnimeCacheCodec.studioFromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> studiosToMap(List<AnimeStudio> studios) {
    return <String, dynamic>{
      'items': studios.map(AnimeCacheCodec.studioToMap).toList(),
    };
  }

  static AnimeCharacter characterFromMap(Map<String, dynamic> map) {
    final voiceActors = (map['voiceActors'] as List? ?? const [])
        .map(
          (item) => VoiceActor(
            id: (item as Map)['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            language: item['language'] as String?,
            imageUrl: item['imageUrl'] as String?,
            animeTitle: item['animeTitle'] as String?,
          ),
        )
        .toList(growable: false);
    final appearances = (map['animeography'] as List? ?? const [])
        .map(
          (item) => CharacterAppearance(
            id: (item as Map)['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            role: item['role'] as String?,
            imageUrl: item['imageUrl'] as String?,
            url: item['url'] as String?,
          ),
        )
        .toList(growable: false);
    return AnimeCharacter(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      role: map['role'] as String?,
      favorites: _int(map['favorites']),
      url: map['url'] as String?,
      about: map['about'] as String?,
      nameKanji: map['nameKanji'] as String?,
      nicknames: _stringList(map['nicknames']),
      voiceActors: voiceActors,
      animeography: appearances,
    );
  }

  static Map<String, dynamic> characterToMap(AnimeCharacter character) {
    return <String, dynamic>{
      'id': character.id,
      'name': character.name,
      'imageUrl': character.imageUrl,
      'role': character.role,
      'favorites': character.favorites,
      'url': character.url,
      'about': character.about,
      'nameKanji': character.nameKanji,
      'nicknames': character.nicknames,
      'voiceActors': character.voiceActors
          .map(
            (actor) => <String, dynamic>{
              'id': actor.id,
              'name': actor.name,
              'language': actor.language,
              'imageUrl': actor.imageUrl,
              'animeTitle': actor.animeTitle,
            },
          )
          .toList(),
      'animeography': character.animeography
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'role': item.role,
              'imageUrl': item.imageUrl,
              'url': item.url,
            },
          )
          .toList(),
    };
  }

  static List<AnimeSeasonYear> seasonsFromMap(Map<String, dynamic> map) {
    final years = map['years'] as List? ?? const [];
    return years
        .map(
          (item) => AnimeSeasonYear(
            year: (item as Map)['year'] as int? ?? 0,
            seasons: (item['seasons'] as List? ?? const [])
                .map(
                  (name) =>
                      AnimeSeason.values.asNameMap()[name] ??
                      AnimeSeason.winter,
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> seasonsToMap(List<AnimeSeasonYear> seasons) {
    return <String, dynamic>{
      'years': seasons
          .map(
            (item) => <String, dynamic>{
              'year': item.year,
              'seasons': item.seasons.map((season) => season.name).toList(),
            },
          )
          .toList(),
    };
  }

  static List<AnimeCharacter> charactersFromMap(Map<String, dynamic> map) {
    return (map['items'] as List? ?? const [])
        .map(
          (item) => AnimeCacheCodec.characterFromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> charactersToMap(List<AnimeCharacter> characters) {
    return <String, dynamic>{
      'items': characters.map(AnimeCacheCodec.characterToMap).toList(),
    };
  }

  static List<Anime> summariesFromMap(Map<String, dynamic> map) {
    return (map['items'] as List? ?? const [])
        .map(
          (item) => AnimeCacheCodec.animeFromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> summariesToMap(List<Anime> items) {
    return <String, dynamic>{
      'items': items.map(AnimeCacheCodec.animeToMap).toList(),
    };
  }

  static List<AnimeGenre> genresFromMap(Map<String, dynamic> map) {
    return (map['items'] as List? ?? const [])
        .map(
          (item) => AnimeCacheCodec.genreFromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> genresToMap(List<AnimeGenre> genres) {
    return <String, dynamic>{
      'items': genres.map(AnimeCacheCodec.genreToMap).toList(),
    };
  }

  static List<String> _stringList(Object? raw) {
    final list = raw as List?;
    if (list == null) return const <String>[];
    return list.whereType<String>().toList(growable: false);
  }

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;

  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}
