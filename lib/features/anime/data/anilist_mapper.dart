import '../models/anime_models.dart';

const anilistProviderName = 'anilist';

const anilistAnimeType = 'ANIME';

String? anilistGenreId(String? name) => name?.trim().toLowerCase();

Anime? mapAniListAnime(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = anilistIdOf(map['id']);
  final title = anilistTitle(map['title']);
  if (id == null || title == null || title.isEmpty) return null;

  final titleMap = _map(map['title']);
  final alternatives = <String>[
    if (titleMap != null)
      for (final value in <String?>[
        titleMap['romaji'] as String?,
        titleMap['english'] as String?,
        titleMap['native'] as String?,
      ])
        if (value != null && value.isNotEmpty && value != title) value,
  ];

  return Anime(
    id: id,
    title: title,
    alternativeTitles: List<String>.unmodifiable(_uniqueStrings(alternatives)),
    synopsis: _stripHtml(_string(map['description'])),
    type: anilistAnimeTypeLabel(map['format']),
    status: _anilistStatusLabel(map['status']),
    score: _anilistScore(map['averageScore']),
    rank: null,
    popularity: _int(map['popularity']),
    episodes: _int(map['episodes']),
    duration: _anilistDuration(map['duration']),
    startDate: _anilistDate(map['startDate']),
    endDate: _anilistDate(map['endDate']),
    season: AnimeSeason.tryParse(_string(map['season'])),
    year: _anilistDate(map['startDate'])?.year,
    genres: List<AnimeGenre>.unmodifiable(mapAniListGenres(map['genres'])),
    studios: List<String>.unmodifiable(_studyNames(map['studios'])),
    producers: List<String>.unmodifiable(_studyNames(map['productionCompanies'])),
    relations: List<AnimeRelated>.unmodifiable(
      mapAniListRelations(map['relations']),
    ),
    source: _anilistSourceLabel(map['source']),
    rating: map['isAdult'] == true ? 'R+ - Mild Nudity' : null,
    images: _anilistImages(map['coverImage']),
    trailerUrl: _anilistTrailer(map['trailer']),
    externalLinks: List<AnimeExternalLink>.unmodifiable(
      _anilistExternalLinks(map['externalLinks']),
    ),
    nextEpisodeLabel: _anilistNextEpisode(map['nextAiringEpisode']),
    airing: map['status'] == 'RELEASING' ? true : null,
  );
}

List<Anime> mapAniListAnimeList(Object? raw) {
  if (raw is! List) return const <Anime>[];
  final items = <Anime>[];
  final seen = <String>{};
  for (final entry in raw) {
    final anime = mapAniListAnime(entry);
    if (anime == null || !seen.add(anime.id)) continue;
    items.add(anime);
  }
  return List<Anime>.unmodifiable(items);
}

AnimeCharacter? mapAniListCharacter(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = anilistIdOf(map['id']);
  final name = anilistCharacterName(map['name']);
  if (id == null || name == null || name.isEmpty) return null;
  final voiceNodes = _nodes(_map(map['voiceActors']));
  return AnimeCharacter(
    id: id,
    name: name,
    imageUrl: _anilistCharacterImage(map['image']),
    role: _anilistRoleLabel(_string(map['role'])),
    favorites: _int(map['favourites']),
    about: _stripHtml(_string(map['description'])),
    voiceActors: List<VoiceActor>.unmodifiable(
      voiceNodes.map(_anilistVoiceActor).whereType<VoiceActor>(),
    ),
    animeography: List<CharacterAppearance>.unmodifiable(
      _anilistAppearances(map['media']),
    ),
  );
}

List<AnimeCharacter> mapAniListCharacters(Object? raw) {
  if (raw is! List) return const <AnimeCharacter>[];
  return List<AnimeCharacter>.unmodifiable(
    raw.map(mapAniListCharacter).whereType<AnimeCharacter>(),
  );
}

List<AnimeGenre> mapAniListGenres(Object? raw) {
  if (raw is! List) return const <AnimeGenre>[];
  final items = <AnimeGenre>[];
  for (final entry in raw) {
    final name = _string(entry);
    if (name == null) continue;
    items.add(
      AnimeGenre(
        id: name,
        name: name,
        kind: AnimeTagKind.genre,
      ),
    );
  }
  return List<AnimeGenre>.unmodifiable(_uniqueGenres(items));
}

List<AnimeRelated> mapAniListRelations(Object? raw) {
  final edges = _map(raw)?['edges'];
  if (edges is! List) return const <AnimeRelated>[];
  final items = <AnimeRelated>[];
  for (final edge in edges) {
    if (edge is! Map) continue;
    final relation = _anilistRelationLabel(_string(edge['relationType']));
    final node = _map(edge['node']);
    if (node == null) continue;
    final id = anilistIdOf(node['id']);
    final title = anilistTitle(node['title']);
    if (id == null || title == null || title.isEmpty) continue;
    items.add(
      AnimeRelated(
        id: id,
        title: title,
        relation: relation,
        type: node['type'] == anilistAnimeType
            ? anilistAnimeTypeLabel(node['format'])
            : _string(node['type']),
        imageUrl:
            _anilistImages(_map(node['coverImage'])).displayUrl ??
            _anilistImages(_map(node['coverImage'])).largeUrl,
      ),
    );
  }
  return List<AnimeRelated>.unmodifiable(items);
}

String? anilistIdOf(Object? raw) {
  if (raw is int) return '$raw';
  if (raw is num) return '${raw.toInt()}';
  final text = _string(raw);
  return text == null || text.isEmpty ? null : text;
}

String? anilistTitle(Object? raw) {
  final map = _map(raw);
  if (map == null) return null;
  return _string(map['userPreferred']) ??
      _string(map['romaji']) ??
      _string(map['english']) ??
      _string(map['native']);
}

String? anilistCharacterName(Object? raw) {
  final map = _map(raw);
  if (map == null) return null;
  return _string(map['full']) ?? _string(map['native']);
}

List<String> _studyNames(Object? raw) {
  final names = <String>[];
  for (final node in _nodes(_map(raw))) {
    final name = _string(node['name']);
    if (name != null && name.isNotEmpty) names.add(name);
  }
  return _uniqueStrings(names);
}

VoiceActor? _anilistVoiceActor(Map<String, dynamic> map) {
  final id = anilistIdOf(map['id']);
  final name = anilistCharacterName(map['name']);
  if (id == null || name == null) return null;
  return VoiceActor(
    id: id,
    name: name,
    language: _string(map['language']),
    imageUrl: _anilistCharacterImage(map['image']),
  );
}

List<CharacterAppearance> _anilistAppearances(Object? raw) {
  final nodes = _nodes(_map(raw));
  final items = <CharacterAppearance>[];
  for (final node in nodes) {
    if (node['type'] != anilistAnimeType) continue;
    final id = anilistIdOf(node['id']);
    final title = anilistTitle(node['title']);
    if (id == null || title == null || title.isEmpty) continue;
    items.add(
      CharacterAppearance(
        id: id,
        title: title,
        imageUrl: _anilistImages(_map(node['coverImage'])).largeUrl,
      ),
    );
  }
  return items;
}

String? _anilistAnimeTypeLabel(Object? raw) {
  final text = _string(raw);
  if (text == null) return null;
  return switch (text.toUpperCase()) {
    'TV' => 'TV',
    'MOVIE' => 'Movie',
    'OVA' => 'OVA',
    'ONA' => 'ONA',
    'SPECIAL' => 'Special',
    _ => text.toLowerCase(),
  };
}

String? anilistAnimeTypeLabel(Object? raw) => _anilistAnimeTypeLabel(raw);

String? _anilistStatusLabel(Object? raw) {
  final text = _string(raw);
  if (text == null) return null;
  return switch (text.toUpperCase()) {
    'FINISHED' => 'Finished Airing',
    'RELEASING' => 'Currently Airing',
    'NOT_YET_RELEASED' => 'Not yet aired',
    'CANCELLED' => 'Cancelled',
    'HIATUS' => 'On hiatus',
    _ => text.toLowerCase(),
  };
}

String? _anilistDuration(Object? raw) {
  final value = _int(raw);
  if (value == null) return null;
  return '$value min per ep';
}

double? _anilistScore(Object? raw) {
  final value = _int(raw);
  if (value == null) return null;
  return value / 10;
}

DateTime? _anilistDate(Object? raw) {
  final map = _map(raw);
  if (map == null) return null;
  final year = _int(map['year']);
  final month = _int(map['month']);
  final day = _int(map['day']);
  if (year == null || year <= 0) return null;
  return DateTime(year, month ?? 1, day ?? 1);
}

String? _anilistNextEpisode(Map<String, dynamic>? map) {
  final episode = _int(map?['episode']);
  final seconds = map?['timeUntilAiring'] is num
      ? (map!['timeUntilAiring'] as num).toInt()
      : null;
  if (episode == null) return null;
  if (seconds == null || seconds <= 0) return 'Ep. $episode';
  final hours = (seconds / 3600).ceil();
  return 'Ep. $episode · in $hours h';
}

String? _anilistTrailer(Map<String, dynamic>? map) {
  if (map == null) return null;
  final id = _string(map['id']);
  final site = _string(map['site']);
  if (id == null || id.isEmpty) return null;
  if (site?.toLowerCase() == 'youtube') {
    return 'https://www.youtube.com/watch?v=$id';
  }
  if (site?.toLowerCase() == 'dailymotion') {
    return 'https://www.dailymotion.com/video/$id';
  }
  return 'https://www.youtube.com/watch?v=$id';
}

List<AnimeExternalLink> _anilistExternalLinks(Object? raw) {
  if (raw is! List) return const <AnimeExternalLink>[];
  final links = <AnimeExternalLink>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final url = _string(map['url']);
    if (url == null) continue;
    links.add(AnimeExternalLink(label: _anilistLinkLabel(map), url: url));
  }
  return links;
}

String _anilistLinkLabel(Map<String, dynamic> map) {
  final site = _string(map['site']);
  if (site != null) return site;
  final url = _string(map['url'] ?? '');
  if (url == null) return 'Link';
  try {
    return Uri.parse(url).host.replaceFirst('www.', '');
  } catch (_) {
    return 'Link';
  }
}

String? _anilistSourceLabel(Object? raw) {
  final text = _string(raw);
  if (text == null) return null;
  return text.split('_').map((part) =>
          part.isEmpty ? part : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String? _anilistRoleLabel(Object? raw) {
  final text = _string(raw);
  if (text == null) return null;
  return switch (text.toUpperCase()) {
    'MAIN' => 'Main',
    'SUPPORTING' => 'Supporting',
    'BACKGROUND' => 'Background',
    _ => text.toLowerCase(),
  };
}

String _anilistRelationLabel(Object? raw) {
  final text = _string(raw);
  if (text == null) return '';
  return text.split('_').map((part) => part.toLowerCase()).join(' ');
}

AnimeImages _anilistImages(Map<String, dynamic>? map) {
  if (map == null) return const AnimeImages();
  return AnimeImages(
    thumbnailUrl:
        _string(map['large']) ??
        _string(map['medium']) ??
        _string(map['extraLarge']),
    largeUrl:
        _string(map['extraLarge']) ??
        _string(map['large']) ??
        _string(map['medium']),
  );
}

String? _anilistCharacterImage(Object? raw) {
  final map = _map(raw);
  if (map == null) return null;
  return _string(map['large']) ?? _string(map['medium']);
}

String? _stripHtml(String? raw) {
  if (raw == null) return null;
  final withoutTags = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  final decoded = withoutTags
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
  if (RegExp(r'\s{2,}').hasMatch(decoded)) {
    return decoded.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }
  return decoded;
}

List<Map<String, dynamic>> _nodes(Map<String, dynamic>? map) {
  final list = map?['nodes'];
  if (list is! List) return const <Map<String, dynamic>>[];
  final nodes = <Map<String, dynamic>>[];
  for (final entry in list) {
    if (entry is Map) nodes.add(Map<String, dynamic>.from(entry));
  }
  return nodes;
}

List<AnimeGenre> _uniqueGenres(List<AnimeGenre> items) {
  final seen = <String>{};
  final result = <AnimeGenre>[];
  for (final item in items) {
    if (!seen.add(item.id)) continue;
    result.add(item);
  }
  return result;
}

List<String> _uniqueStrings(List<String> items) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in items) {
    if (!seen.add(item)) continue;
    result.add(item);
  }
  return result;
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
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