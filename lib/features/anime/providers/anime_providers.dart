import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../social/repositories/profile_repository.dart';
import '../data/anime_search_ranker.dart';
import '../models/anime_models.dart';
import '../repositories/anime_repository.dart';

LoadingState animeFailureState(Failure failure, {required bool hasContent}) {
  if (hasContent) {
    return failure is NetworkError || failure is TimeoutError
        ? LoadingState.offline
        : LoadingState.loaded;
  }
  if (failure is NetworkError || failure is TimeoutError) {
    return LoadingState.offline;
  }
  return LoadingState.error;
}

final class AnimeSectionSnapshot {
  const AnimeSectionSnapshot({
    this.page = AnimePage.empty,
    this.state = LoadingState.initial,
    this.failure,
  });

  final AnimePage page;
  final LoadingState state;
  final Failure? failure;

  bool get fromCache => page.fromCache;
  List<Anime> get items => page.items;
}

final class AnimeHubProvider extends ChangeNotifier {
  AnimeHubProvider({
    required AnimeRepository repository,
    Analytics? analytics,
  }) : _repository = repository,
       _analytics = analytics;

  final AnimeRepository _repository;
  final Analytics? _analytics;
  final Map<AnimeCatalogKind, AnimeSectionSnapshot> _sections = {
    for (final kind in AnimeCatalogKind.hubHome)
      kind: const AnimeSectionSnapshot(),
  };
  List<AnimeGenre> _genres = const <AnimeGenre>[];
  List<AnimeSeasonYear> _seasons = const <AnimeSeasonYear>[];
  LoadingState _genresState = LoadingState.initial;
  LoadingState _seasonsState = LoadingState.initial;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _fromCache = false;
  bool _disposed = false;
  bool _loading = false;

  Map<AnimeCatalogKind, AnimeSectionSnapshot> get sections =>
      Map<AnimeCatalogKind, AnimeSectionSnapshot>.unmodifiable(_sections);
  AnimeSectionSnapshot section(AnimeCatalogKind kind) =>
      _sections[kind] ?? const AnimeSectionSnapshot();
  List<AnimeGenre> get genres => _genres;
  List<AnimeSeasonYear> get seasons => _seasons;
  LoadingState get genresState => _genresState;
  LoadingState get seasonsState => _seasonsState;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get fromCache => _fromCache;

  Future<void> load({bool refresh = false}) async {
    if (_loading && !refresh) return;
    if (!refresh && _state == LoadingState.loaded) return;
    _loading = true;
    _state = refresh && _hasAnyContent ? LoadingState.refreshing : LoadingState.loading;
    _failure = null;
    _safeNotify();
    _analytics?.logEvent('anime_hub_open');

    var anyCache = false;
    Failure? firstFailure;
    await Future.wait(<Future<void>>[
      for (final kind in AnimeCatalogKind.hubHome) _loadSection(kind),
    ]);
    for (final kind in AnimeCatalogKind.hubHome) {
      if (_disposed) return;
      final snapshot = section(kind);
      anyCache = anyCache || snapshot.fromCache;
      firstFailure ??= snapshot.failure;
    }
    await Future.wait(<Future<void>>[_loadGenres(), _loadSeasons()]);
    if (_disposed) return;
    _fromCache = anyCache;
    _failure = firstFailure;
    _state = _hasAnyContent
        ? LoadingState.loaded
        : (firstFailure == null ? LoadingState.empty : animeFailureState(firstFailure, hasContent: false));
    _loading = false;
    _safeNotify();
  }

  Future<void> retry() => load(refresh: true);

  bool get _hasAnyContent =>
      AnimeCatalogKind.hubHome.any((kind) => section(kind).items.isNotEmpty);

  Future<void> _loadSection(AnimeCatalogKind kind) async {
    _sections[kind] = AnimeSectionSnapshot(
      page: section(kind).page,
      state: LoadingState.loading,
    );
    _safeNotify();
    final result = await _fetchCatalog(kind, page: 1);
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        _sections[kind] = AnimeSectionSnapshot(
          page: page,
          state: page.items.isEmpty ? LoadingState.empty : LoadingState.loaded,
        );
      },
      onFailure: (failure) {
        _sections[kind] = AnimeSectionSnapshot(
          page: section(kind).page,
          state: animeFailureState(failure, hasContent: section(kind).items.isNotEmpty),
          failure: failure,
        );
      },
    );
  }

  Future<void> _loadGenres() async {
    _genresState = LoadingState.loading;
    final result = await _repository.getGenres();
    if (_disposed) return;
    result.fold(
      onSuccess: (genres) {
        _genres = genres.where((genre) => genre.isBrowsable).toList(growable: false);
        _genresState = _genres.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        _genresState = animeFailureState(failure, hasContent: _genres.isNotEmpty);
      },
    );
  }

  Future<void> _loadSeasons() async {
    _seasonsState = LoadingState.loading;
    final result = await _repository.getAvailableSeasons();
    if (_disposed) return;
    result.fold(
      onSuccess: (seasons) {
        _seasons = seasons;
        _seasonsState = seasons.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        _seasonsState = animeFailureState(failure, hasContent: _seasons.isNotEmpty);
      },
    );
  }

  Future<Result<AnimePage>> _fetchCatalog(
    AnimeCatalogKind kind, {
    required int page,
  }) {
    return switch (kind) {
      AnimeCatalogKind.trending => _repository.getTrending(page: page),
      AnimeCatalogKind.popular => _repository.getPopular(page: page),
      AnimeCatalogKind.top => _repository.getTop(page: page),
      AnimeCatalogKind.airing => _repository.getAiring(page: page),
      AnimeCatalogKind.thisSeason => _repository.getThisSeason(page: page),
      AnimeCatalogKind.upcoming => _repository.getUpcoming(page: page),
    };
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class AnimeListProvider extends ChangeNotifier {
  AnimeListProvider({
    required AnimeRepository repository,
    Analytics? analytics,
    this.debounce = Duration.zero,
    this.minQueryLength = 1,
  }) : _repository = repository,
       _analytics = analytics;

  final AnimeRepository _repository;
  final Analytics? _analytics;
  final Duration debounce;
  final int minQueryLength;

  List<Anime> _items = const <Anime>[];
  List<Anime> _catalogSnapshot = const <Anime>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  Failure? _pageFailure;
  bool _hasNextPage = false;
  int _page = 0;
  bool _fromCache = false;
  bool _loadingMore = false;
  bool _disposed = false;
  String? _inflightKey;
  String _title = AnimeStrings.hubTitle;
  AnimeCatalogKind? _catalog;
  String? _genreId;
  int? _year;
  AnimeSeason? _season;
  String _query = '';
  AnimeSearchFilter _filter = const AnimeSearchFilter();
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  List<Anime> get items => _items;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  Failure? get pageFailure => _pageFailure;
  bool get hasNextPage => _hasNextPage;
  bool get fromCache => _fromCache;
  String get title => _title;
  String get query => _query;
  AnimeCatalogKind? get catalogKind => _catalog;
  String? get genreId => _genreId;
  int? get year => _year;
  AnimeSeason? get season => _season;
  AnimeSearchFilter get filter => _filter;
  bool get isSearching => _filter.hasConstraints;

  Future<void> openCatalog(AnimeCatalogKind kind) {
    _reset();
    _catalog = kind;
    _title = kind.label;
    _analytics?.logEvent('anime_category_open', parameters: {'kind': kind.name});
    return _load(page: 1);
  }

  Future<void> openGenre(AnimeGenre genre) {
    _reset();
    _genreId = genre.id;
    _title = genre.name;
    _analytics?.logEvent(
      'anime_genre_open',
      parameters: {'genreId': genre.id, 'name': genre.name},
    );
    return _load(page: 1);
  }

  Future<void> openSeason({required int year, required AnimeSeason season}) {
    _reset();
    _year = year;
    _season = season;
    _title = '${season.label} $year';
    _analytics?.logEvent(
      'anime_season_open',
      parameters: {'year': year, 'season': season.name},
    );
    return _load(page: 1);
  }

  void searchChanged(String query) {
    _searchDebounce?.cancel();
    _query = query;
    _filter = _filter.copyWith(text: query, sort: AnimeSearchSort.members);
    _failure = null;
    _previewFromSnapshot();
    _scheduleSearch();
  }

  void searchSubmitted(String query) {
    _searchDebounce?.cancel();
    _query = query;
    _filter = _filter.copyWith(text: query, sort: AnimeSearchSort.members);
    _previewFromSnapshot();
    _scheduleSearch(immediate: true);
  }

  void applyFilter(AnimeSearchFilter filter) {
    _searchDebounce?.cancel();
    _filter = filter.copyWith(text: _query, sort: AnimeSearchSort.members);
    _failure = null;
    _previewFromSnapshot();
    _scheduleSearch(immediate: true);
  }

  List<Anime> _locallyFiltered(List<Anime> source) {
    final needle = _query.trim();
    if (needle.isEmpty) {
      return source
          .where(_filter.matchesCatalog)
          .toList(growable: false);
    }
    final catalog = source
        .where(_filter.matchesCatalog)
        .toList(growable: false);
    return AnimeSearchRanker.rank(catalog, needle);
  }

  void _previewFromSnapshot() {
    if (_catalogSnapshot.isEmpty) return;
    _items = _locallyFiltered(_catalogSnapshot);
    if (_items.isEmpty && _filter.hasConstraints) {
      _state = LoadingState.empty;
    } else if (_items.isNotEmpty) {
      _state = LoadingState.loaded;
    }
    _safeNotify();
  }

  void _scheduleSearch({bool immediate = false}) {
    final trimmed = _query.trim();
    if (!_filter.hasConstraints) {
      _restoreCatalogSnapshot();
      _safeNotify();
      return;
    }
    if (!immediate &&
        trimmed.length < minQueryLength &&
        !_filter.hasNonTextConstraints) {
      _previewFromSnapshot();
      if (_catalogSnapshot.isEmpty) {
        _items = const <Anime>[];
        _state = LoadingState.initial;
        _failure = null;
        _safeNotify();
      }
      return;
    }
    void run() {
      _analytics?.logEvent(
        'anime_search',
        parameters: {'length': trimmed.length},
      );
      unawaited(_runSearch(generation: ++_searchGeneration));
    }

    if (immediate || debounce == Duration.zero) {
      run();
    } else {
      _searchDebounce = Timer(debounce, run);
    }
  }

  Future<void> retrySearch() {
    if (!_filter.hasConstraints) return Future<void>.value();
    return _runSearch(generation: ++_searchGeneration);
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _query = '';
    _filter = _filter.copyWith(text: '');
    if (_filter.hasNonTextConstraints) {
      _scheduleSearch(immediate: true);
      return;
    }
    _reset();
    _safeNotify();
  }

  Future<void> retry() => _load(page: 1, refresh: true);

  Future<void> loadMore() async {
    if (!_hasNextPage ||
        _loadingMore ||
        _state == LoadingState.loading ||
        _state == LoadingState.loadingMore ||
        _items.isEmpty) {
      return;
    }
    await _load(page: _page + 1, loadMore: true);
  }

  Future<void> retryLoadMore() async {
    if (_items.isEmpty) return retry();
    await _load(page: _page + 1, loadMore: true);
  }

  Future<void> _runSearch({required int generation}) async {
    _catalog = null;
    _genreId = null;
    _year = null;
    _season = null;
    _title = 'Search';
    _page = 0;
    _hasNextPage = false;
    await _load(
      page: 1,
      searchQuery: _query.trim(),
      generation: generation,
    );
  }

  Future<void> _load({
    required int page,
    bool refresh = false,
    bool loadMore = false,
    String? searchQuery,
    int? generation,
  }) async {
    final key = _requestKey(page: page, searchQuery: searchQuery ?? _query.trim());
    if (_inflightKey == key) return;
    _inflightKey = key;
    _pageFailure = null;
    if (loadMore) {
      _loadingMore = true;
      _state = LoadingState.loadingMore;
    } else {
      final keepContent =
          refresh || _items.isNotEmpty || _catalogSnapshot.isNotEmpty;
      if (keepContent) {
        _state = LoadingState.refreshing;
      } else {
        _state = LoadingState.loading;
        _items = const <Anime>[];
      }
    }
    _safeNotify();

    final result = await _fetch(page: page, searchQuery: searchQuery);
    if (_disposed) return;
    if (generation != null && generation != _searchGeneration) {
      final currentKey = _requestKey(page: 1, searchQuery: _query.trim());
      if (currentKey != key) {
        _inflightKey = null;
        return;
      }
    }
    _inflightKey = null;
    _loadingMore = false;

    result.fold(
      onSuccess: (pageResult) {
        var merged = loadMore
            ? _merge(_items, pageResult.items)
            : pageResult.items;
        final searching = searchQuery != null && searchQuery.trim().isNotEmpty;
        if (searching && page == 1) {
          merged = AnimeSearchRanker.rank(merged, searchQuery);
        }
        _items = merged;
        if (!searching && page == 1) {
          _catalogSnapshot = merged;
        }
        _page = pageResult.page;
        _hasNextPage = pageResult.hasNextPage;
        _fromCache = pageResult.fromCache;
        _failure = null;
        _state = merged.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        if (!loadMore && _items.isEmpty && _catalogSnapshot.isNotEmpty) {
          _items = _locallyFiltered(_catalogSnapshot);
        }
        _failure = loadMore ? _failure : failure;
        _pageFailure = loadMore ? failure : null;
        if (loadMore) {
          _state = _items.isEmpty ? animeFailureState(failure, hasContent: false) : LoadingState.loaded;
        } else {
          _state = animeFailureState(failure, hasContent: _items.isNotEmpty);
        }
      },
    );
    _safeNotify();
  }

  Future<Result<AnimePage>> _fetch({required int page, String? searchQuery}) {
    final query = (searchQuery ?? _query).trim();
    final searching =
        _catalog == null &&
        _genreId == null &&
        _year == null &&
        (_filter.hasNonTextConstraints || query.length >= minQueryLength);
    if (searching) {
      return _repository.searchAnime(
        query,
        page: page,
        filter: _filter.copyWith(text: query),
      );
    }
    if (_genreId != null) {
      return _repository.getByGenre(_genreId!, page: page);
    }
    if (_year != null && _season != null) {
      return _repository.getBySeason(year: _year!, season: _season!, page: page);
    }
    return switch (_catalog) {
      AnimeCatalogKind.trending => _repository.getTrending(page: page),
      AnimeCatalogKind.popular => _repository.getPopular(page: page),
      AnimeCatalogKind.top => _repository.getTop(page: page),
      AnimeCatalogKind.airing => _repository.getAiring(page: page),
      AnimeCatalogKind.thisSeason => _repository.getThisSeason(page: page),
      AnimeCatalogKind.upcoming => _repository.getUpcoming(page: page),
      null => Future<Result<AnimePage>>.value(const Success(AnimePage.empty)),
    };
  }

  String _requestKey({required int page, required String searchQuery}) =>
      '${_catalog?.name}|$_genreId|$_year|${_season?.name}|${_filter.genreId}|${_filter.type?.name}|${_filter.season?.name}|${_filter.year}|${_filter.sort.name}|$searchQuery|$page';

  List<Anime> _merge(List<Anime> current, List<Anime> incoming) {
    final seen = current.map((item) => item.id).toSet();
    return <Anime>[
      ...current,
      ...incoming.where((item) => seen.add(item.id)),
    ];
  }

  void _reset() {
    _searchDebounce?.cancel();
    _items = const <Anime>[];
    _catalogSnapshot = const <Anime>[];
    _state = LoadingState.initial;
    _failure = null;
    _pageFailure = null;
    _hasNextPage = false;
    _page = 0;
    _fromCache = false;
    _inflightKey = null;
    _catalog = null;
    _genreId = null;
    _year = null;
    _season = null;
    _query = '';
    _filter = const AnimeSearchFilter();
  }

  void _restoreCatalogSnapshot() {
    _searchDebounce?.cancel();
    _items = _catalogSnapshot;
    _state = _items.isEmpty ? LoadingState.initial : LoadingState.loaded;
    _failure = null;
    _pageFailure = null;
    _hasNextPage = false;
    _page = 0;
    _fromCache = false;
    _inflightKey = null;
    _catalog = _items.isEmpty ? null : AnimeCatalogKind.popular;
    _genreId = null;
    _year = null;
    _season = null;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final class AnimeDetailsProvider extends ChangeNotifier {
  AnimeDetailsProvider({
    required AnimeRepository repository,
    ProfileRepository? profiles,
    Analytics? analytics,
  }) : _repository = repository,
       _profiles = profiles,
       _analytics = analytics;

  final AnimeRepository _repository;
  final ProfileRepository? _profiles;
  final Analytics? _analytics;

  Anime? _anime;
  List<AnimeCharacter> _characters = const <AnimeCharacter>[];
  LoadingState _state = LoadingState.initial;
  LoadingState _charactersState = LoadingState.initial;
  Failure? _failure;
  Failure? _charactersFailure;
  bool _fromCache = false;
  bool _disposed = false;
  String? _loadedId;
  String? _userId;
  List<String> _favoriteIds = const <String>[];
  bool _savingFavorite = false;
  OnboardingProvider? _onboarding;
  final Map<String, AnimeCharacter> _characterProfiles = <String, AnimeCharacter>{};
  final Map<String, Future<AnimeCharacter>> _characterInflight =
      <String, Future<AnimeCharacter>>{};

  Anime? get anime => _anime;
  List<AnimeCharacter> get characters => _characters;
  LoadingState get state => _state;
  LoadingState get charactersState => _charactersState;
  Failure? get failure => _failure;
  Failure? get charactersFailure => _charactersFailure;
  bool get fromCache => _fromCache;
  bool get savingFavorite => _savingFavorite;
  bool get isFavorite {
    final id = _anime?.id;
    if (id == null) return false;
    return _favoriteIds.contains(id);
  }

  void bindFavorites({
    required String? userId,
    required List<String> favoriteIds,
    OnboardingProvider? onboarding,
  }) {
    _userId = userId;
    _onboarding = onboarding;
    if (_savingFavorite) return;
    if (onboarding?.profile == null) return;
    _favoriteIds = List<String>.unmodifiable(favoriteIds);
  }

  Future<void> load(String animeId, {bool refresh = false}) async {
    final id = animeId.trim();
    if (id.isEmpty) {
      _state = LoadingState.empty;
      _failure = const NotFoundError(AnimeStrings.detailsMissing);
      _safeNotify();
      return;
    }
    if (!refresh && _loadedId == id && _anime != null) return;
    _loadedId = id;
    _state = LoadingState.loading;
    _charactersState = LoadingState.loading;
    _failure = null;
    _charactersFailure = null;
    if (!refresh) {
      _anime = null;
      _characters = const <AnimeCharacter>[];
      _characterProfiles.clear();
    }
    _safeNotify();
    _analytics?.logEvent('anime_open', parameters: {'animeId': id});
    unawaited(_loadCharacters(id));
    final result = await _repository.getAnimeDetails(id);
    if (_disposed || _loadedId != id) return;
    result.fold(
      onSuccess: (anime) {
        _anime = anime;
        _fromCache = anime.fromCache;
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = failure is NotFoundError
            ? LoadingState.empty
            : animeFailureState(failure, hasContent: _anime != null);
      },
    );
    _safeNotify();
  }

  Future<void> retry() {
    final id = _loadedId;
    if (id == null) return Future<void>.value();
    return load(id, refresh: true);
  }

  Future<void> retryCharacters() {
    final id = _loadedId;
    if (id == null) return Future<void>.value();
    return _loadCharacters(id);
  }

  Future<AnimeCharacter> characterProfile(AnimeCharacter preview) {
    final cached = _characterProfiles[preview.id];
    if (cached != null && cached.hasFullProfile) {
      return Future<AnimeCharacter>.value(preview.mergeDetails(cached));
    }
    final pending = _characterInflight[preview.id];
    if (pending != null) {
      return pending.then(preview.mergeDetails);
    }
    final future = _loadCharacterProfile(preview);
    _characterInflight[preview.id] = future;
    return future.whenComplete(() => _characterInflight.remove(preview.id));
  }

  Future<AnimeCharacter> _loadCharacterProfile(AnimeCharacter preview) async {
    final result = await _repository.getCharacterDetails(preview.id);
    final merged = result.fold(
      onSuccess: preview.mergeDetails,
      onFailure: (_) => preview,
    );
    if (merged.hasFullProfile) {
      _characterProfiles[preview.id] = merged;
    }
    return merged;
  }

  void _prefetchCharacterProfiles(List<AnimeCharacter> characters) {
    for (final character in characters.take(8)) {
      unawaited(characterProfile(character));
    }
  }

  Future<void> toggleFavorite() async {
    final anime = _anime;
    final userId = _userId;
    final profiles = _profiles;
    if (anime == null || userId == null || profiles == null || _savingFavorite) {
      return;
    }
    final current = [..._favoriteIds];
    final exists = current.contains(anime.id);
    if (!exists && current.length >= 50) {
      _failure = const ValidationError(AnimeStrings.favoriteLimit);
      _safeNotify();
      return;
    }
    final next = exists
        ? current.where((id) => id != anime.id).toList(growable: false)
        : <String>[...current, anime.id];
    _savingFavorite = true;
    _favoriteIds = next;
    _safeNotify();
    final result = await profiles.updateProfile(
      userId,
      ProfileUpdate(favoriteAnimeIds: next),
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (profile) {
        _favoriteIds = profile.favoriteAnimeIds;
        _onboarding?.applyFavoriteAnimeIds(profile.favoriteAnimeIds);
        _analytics?.logEvent(
          exists ? 'anime_unfavorite' : 'anime_favorite',
          parameters: {'animeId': anime.id},
        );
      },
      onFailure: (failure) {
        _favoriteIds = current;
        _failure = failure;
      },
    );
    _savingFavorite = false;
    _safeNotify();
  }

  Future<void> _loadCharacters(String id) async {
    _charactersState = LoadingState.loading;
    final result = await _repository.getCharacters(id);
    if (_disposed || _loadedId != id) return;
    result.fold(
      onSuccess: (characters) {
        _characters = characters;
        _charactersState = characters.isEmpty
            ? LoadingState.empty
            : LoadingState.loaded;
        _charactersFailure = null;
        if (characters.isNotEmpty) {
          _prefetchCharacterProfiles(characters);
        }
      },
      onFailure: (failure) {
        _charactersFailure = failure;
        _charactersState = animeFailureState(
          failure,
          hasContent: _characters.isNotEmpty,
        );
      },
    );
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
