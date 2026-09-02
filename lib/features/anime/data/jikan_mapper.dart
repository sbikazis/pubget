import '../models/anime_models.dart';

const jikanProviderName = 'jikan';

Anime? mapJikanAnime(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = _idOf(map['mal_id']);
  final title = _string(map['title']);
  if (id == null || title == null || title.isEmpty) return null;

  final english = _string(map['title_english']);
  final japanese = _string(map['title_japanese']);
  final synonyms = _stringList(map['title_synonyms']);
  final alternatives = <String>[
    if (english != null && english != title) english,
    if (japanese != null && japanese != title) japanese,
    ...synonyms.where((value) => value != title),
  ];

  return Anime(
    id: id,
    title: title,
    alternativeTitles: List<String>.unmodifiable(alternatives),
    synopsis: _string(map['synopsis']),
    type: _string(map['type']),
    status: _string(map['status']),
    score: _double(map['score']),
    rank: _int(map['rank']),
    popularity: _int(map['popularity']),
    episodes: _int(map['episodes']),
    duration: _string(map['duration']),
    startDate: _date(_map(map['aired'])?['from']),
    endDate: _date(_map(map['aired'])?['to']),
    season: AnimeSeason.tryParse(_string(map['season'])),
    year: _int(map['year']),
    genres: List<AnimeGenre>.unmodifiable(_genresFrom(map)),
    studios: List<String>.unmodifiable(_namedList(map['studios'])),
    producers: List<String>.unmodifiable(_namedList(map['producers'])),
    source: _string(map['source']),
    images: _images(map['images']),
    trailerUrl: _trailer(map['trailer']),
    externalLinks: List<AnimeExternalLink>.unmodifiable(_externalLinks(map)),
    nextEpisodeLabel: _string(_map(map['broadcast'])?['string']),
    airing: map['airing'] is bool ? map['airing'] as bool : null,
  );
}

List<Anime> mapJikanAnimeList(Object? raw) {
  if (raw is! List) return const <Anime>[];
  final items = <Anime>[];
  final seen = <String>{};
  for (final entry in raw) {
    final anime = mapJikanAnime(entry) ?? _animeFromWatchOrRecommendation(entry);
    if (anime == null || !seen.add(anime.id)) continue;
    items.add(anime);
  }
  return List<Anime>.unmodifiable(items);
}

AnimeCharacter? mapJikanCharacterEntry(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final character = _map(map['character']) ?? map;
  final id = _idOf(character['mal_id']);
  final name = _string(character['name']);
  if (id == null || name == null || name.isEmpty) return null;
  return AnimeCharacter(
    id: id,
    name: name,
    imageUrl: _images(character['images']).displayUrl,
    role: _string(map['role']),
    favorites: _int(map['favorites'] ?? character['favorites']),
    url: _string(character['url']),
    voiceActors: List<VoiceActor>.unmodifiable(_voiceActors(map['voice_actors'])),
  );
}

List<AnimeCharacter> mapJikanCharacters(Object? raw) {
  if (raw is! List) return const <AnimeCharacter>[];
  return List<AnimeCharacter>.unmodifiable(
    raw.map(mapJikanCharacterEntry).whereType<AnimeCharacter>(),
  );
}

List<AnimeGenre> mapJikanGenres(Object? raw, {AnimeTagKind kind = AnimeTagKind.genre}) {
  if (raw is! List) return const <AnimeGenre>[];
  final items = <AnimeGenre>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final id = _idOf(map['mal_id']);
    final name = _string(map['name']);
    if (id == null || name == null || name.isEmpty) continue;
    items.add(
      AnimeGenre(
        id: id,
        name: name,
        kind: kind,
        count: _int(map['count']),
      ),
    );
  }
  return List<AnimeGenre>.unmodifiable(items);
}

List<AnimeSeasonYear> mapJikanSeasons(Object? raw) {
  if (raw is! List) return const <AnimeSeasonYear>[];
  final years = <AnimeSeasonYear>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final year = _int(map['year']);
    if (year == null) continue;
    final seasons = <AnimeSeason>[];
    final listed = map['seasons'];
    if (listed is List) {
      for (final value in listed) {
        final season = AnimeSeason.tryParse(value?.toString());
        if (season != null) seasons.add(season);
      }
    }
    years.add(
      AnimeSeasonYear(
        year: year,
        seasons: List<AnimeSeason>.unmodifiable(seasons),
      ),
    );
  }
  years.sort((a, b) => b.year.compareTo(a.year));
  return List<AnimeSeasonYear>.unmodifiable(years);
}

({int page, bool hasNextPage}) mapJikanPagination(Object? raw) {
  if (raw is! Map) return (page: 1, hasNextPage: false);
  final map = Map<String, dynamic>.from(raw);
  return (
    page: _int(map['current_page']) ?? 1,
    hasNextPage: map['has_next_page'] == true,
  );
}

Anime? _animeFromWatchOrRecommendation(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final entry = map['entry'];
  if (entry is List && entry.isNotEmpty) {
    return mapJikanAnime(entry.first);
  }
  if (entry is Map) return mapJikanAnime(entry);
  final anime = map['anime'];
  if (anime is Map) return mapJikanAnime(anime);
  return null;
}

List<AnimeGenre> _genresFrom(Map<String, dynamic> map) {
  return <AnimeGenre>[
    ...mapJikanGenres(map['genres'], kind: AnimeTagKind.genre),
    ...mapJikanGenres(map['themes'], kind: AnimeTagKind.theme),
    ...mapJikanGenres(map['demographics'], kind: AnimeTagKind.demographic),
    ...mapJikanGenres(map['explicit_genres'], kind: AnimeTagKind.explicit),
  ];
}

List<VoiceActor> _voiceActors(Object? raw) {
  if (raw is! List) return const <VoiceActor>[];
  final actors = <VoiceActor>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final person = _map(map['person']) ?? map;
    final id = _idOf(person['mal_id']);
    final name = _string(person['name']);
    if (id == null || name == null) continue;
    actors.add(
      VoiceActor(
        id: id,
        name: name,
        language: _string(map['language']),
        imageUrl: _images(person['images']).displayUrl,
      ),
    );
  }
  return actors;
}

List<AnimeExternalLink> _externalLinks(Map<String, dynamic> map) {
  final links = <AnimeExternalLink>[];
  final url = _string(map['url']);
  if (url != null) {
    links.add(AnimeExternalLink(label: 'MyAnimeList', url: url));
  }
  _addNamedLinks(links, map['external']);
  _addNamedLinks(links, map['streaming'], fallbackLabel: 'Streaming');
  return links;
}

void _addNamedLinks(
  List<AnimeExternalLink> links,
  Object? raw, {
  String fallbackLabel = 'Link',
}) {
  if (raw is! List) return;
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final url = _string(map['url']);
    if (url == null) continue;
    links.add(
      AnimeExternalLink(
        label: _string(map['name']) ?? fallbackLabel,
        url: url,
      ),
    );
  }
}

AnimeImages _images(Object? raw) {
  final jpg = _map(_map(raw)?['jpg']);
  final webp = _map(_map(raw)?['webp']);
  return AnimeImages(
    thumbnailUrl:
        _string(jpg?['image_url']) ??
        _string(jpg?['small_image_url']) ??
        _string(webp?['image_url']),
    largeUrl:
        _string(jpg?['large_image_url']) ??
        _string(webp?['large_image_url']) ??
        _string(jpg?['image_url']),
  );
}

String? _trailer(Object? raw) {
  final map = _map(raw);
  if (map == null) return null;
  return _string(map['url']) ?? _string(map['embed_url']);
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<String> _namedList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((entry) {
        if (entry is Map) return _string(entry['name']);
        return _string(entry);
      })
      .whereType<String>()
      .toList(growable: false);
}

String? _idOf(Object? raw) {
  if (raw is int) return '$raw';
  if (raw is num) return '${raw.toInt()}';
  final text = _string(raw);
  return text == null || text.isEmpty ? null : text;
}

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

double? _double(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

DateTime? _date(Object? raw) {
  final text = _string(raw);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map(_string).whereType<String>().toList(growable: false);
}
