import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../models/group_catalog_models.dart';
import '../models/group_models.dart';
import '../repositories/group_catalog_repository.dart';

/// One paginated, debounced, race-free list for a group picker.
///
/// The picker used to hold a single page and filter it locally, so scrolling
/// ended after twenty titles and a search that could not reach the network
/// answered "nothing found" instead of "the catalog is unreachable". This
/// provider makes the server the answer: pages are fetched on demand, merged
/// without duplicates, and a failed page keeps the pages already on screen with
/// a retry next to them.
final class GroupCatalogProvider extends ChangeNotifier {
  GroupCatalogProvider({
    required GroupCatalogRepository repository,
    this.debounce = const Duration(milliseconds: 350),
    this.pageSize = 25,
  }) : _repository = repository;

  final GroupCatalogRepository _repository;
  final Duration debounce;
  final int pageSize;

  List<CatalogAnime> _anime = const <CatalogAnime>[];
  LoadingState _animeState = LoadingState.initial;
  Failure? _animeFailure;
  Failure? _animePageFailure;
  bool _animeHasNextPage = false;
  bool _animeLoadingMore = false;
  int _animePage = 0;
  GroupCatalogRequest? _animeRequest;
  Timer? _animeDebounce;
  int _animeGeneration = 0;

  List<RoleplayCharacter> _characters = const <RoleplayCharacter>[];
  List<CatalogSeason> _seasons = const <CatalogSeason>[];
  LoadingState _charactersState = LoadingState.initial;
  Failure? _charactersFailure;
  Failure? _charactersPageFailure;
  bool _charactersHasNextPage = false;
  bool _charactersLoadingMore = false;
  int _charactersPage = 0;
  GroupCharacterRequest? _charactersRequest;
  Timer? _charactersDebounce;
  int _charactersGeneration = 0;
  Set<String> _reservedKeys = const <String>{};

  List<CatalogAnime> get anime => _anime;
  LoadingState get animeState => _animeState;
  Failure? get animeFailure => _animeFailure;
  Failure? get animePageFailure => _animePageFailure;
  bool get animeHasNextPage => _animeHasNextPage;
  bool get animeLoadingMore => _animeLoadingMore;
  String get animeQuery => _animeRequest?.query.trim() ?? '';
  GroupCatalogRequest? get animeRequest => _animeRequest;
  List<String> get animeSuggestions => <String>[
    if (animeQuery.isNotEmpty) animeQuery,
  ];

  List<RoleplayCharacter> get characters => _characters;
  List<CatalogSeason> get seasons => _seasons;
  LoadingState get charactersState => _charactersState;
  Failure? get charactersFailure => _charactersFailure;
  Failure? get charactersPageFailure => _charactersPageFailure;
  bool get charactersHasNextPage => _charactersHasNextPage;
  bool get charactersLoadingMore => _charactersLoadingMore;
  String get charactersQuery =>
      _charactersRequest?.query.trim() ?? '';
  Set<String> get reservedKeys => _reservedKeys;

  // ---------------------------------------------------------------- anime ---

  /// Opens the catalog on a browse axis. Re-selecting the axis it is already on
  /// refreshes it, so a retry never silently does nothing.
  Future<void> openAnime(GroupCatalogRequest request) async {
    _animeDebounce?.cancel();
    if (_animeRequest?.cacheKey == request.cacheKey &&
        _anime.isNotEmpty &&
        _animeState == LoadingState.loaded) {
      return;
    }
    _animeRequest = request;
    _animeGeneration += 1;
    _anime = const <CatalogAnime>[];
    _animePage = 0;
    _animeHasNextPage = false;
    _animePageFailure = null;
    _animeState = LoadingState.loading;
    _animeFailure = null;
    _safeNotify();
    await _fetchAnime(page: 1, generation: _animeGeneration, request: request);
  }

  /// A keystroke. The list is not rebuilt locally — the answer that matters is
  /// the one the catalog returns for the whole title set, not for the twenty
  /// titles already on screen.
  void searchAnime(String query) => _scheduleAnime(
    GroupCatalogRequest.search(query),
  );

  Future<void> loadMoreAnime() async {
    final request = _animeRequest;
    if (request == null ||
        !_animeHasNextPage ||
        _animeLoadingMore ||
        _anime.isEmpty ||
        _animeState == LoadingState.loading) {
      return;
    }
    _animeLoadingMore = true;
    _animeState = LoadingState.loadingMore;
    _safeNotify();
    await _fetchAnime(
      page: _animePage + 1,
      generation: _animeGeneration,
      request: request,
      loadMore: true,
    );
  }

  Future<void> retryAnime() {
    final request = _animeRequest;
    if (request == null) return Future<void>.value();
    _animeGeneration += 1;
    if (_anime.isEmpty) {
      _animeState = LoadingState.loading;
      _animeFailure = null;
      _safeNotify();
    }
    return _fetchAnime(page: 1, generation: _animeGeneration, request: request);
  }

  Future<void> retryAnimePage() {
    final request = _animeRequest;
    if (request == null || _anime.isEmpty) return retryAnime();
    return _fetchAnime(
      page: _animePage + 1,
      generation: _animeGeneration,
      request: request,
      loadMore: true,
    );
  }

  void _scheduleAnime(GroupCatalogRequest request) {
    _animeDebounce?.cancel();
    _animeRequest = request;
    final generation = ++_animeGeneration;
    // Keep what is on screen while the answer is on its way, so typing never
    // blanks the list; a request that has not landed yet still shows as busy.
    if (_animeState == LoadingState.loaded) {
      _animeState = LoadingState.refreshing;
    }
    _safeNotify();
    _animeDebounce = Timer(debounce, () {
      unawaited(_fetchAnime(page: 1, generation: generation, request: request));
    });
  }

  Future<void> _fetchAnime({
    required int page,
    required int generation,
    required GroupCatalogRequest request,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      _animePageFailure = null;
    } else {
      _animeFailure = null;
    }
    final result = await _repository.browseAnime(request, page: page);
    if (_disposed || generation != _animeGeneration) return;
    _animeLoadingMore = false;
    result.fold(
      onSuccess: (page_) {
        _anime = loadMore ? _mergeAnime(_anime, page_.items) : page_.items;
        _animePage = page_.page;
        _animeHasNextPage = page_.hasNextPage && page_.items.isNotEmpty;
        _animeFailure = null;
        _animeState = _anime.isEmpty
            ? LoadingState.empty
            : LoadingState.loaded;
      },
      onFailure: (failure) {
        if (loadMore) {
          // The pages already on screen stay: a failed tail is a retry, not a
          // lost list.
          _animePageFailure = failure;
          _animeState = _anime.isEmpty
              ? _stateFor(failure)
              : LoadingState.loaded;
          return;
        }
        _anime = const <CatalogAnime>[];
        _animeHasNextPage = false;
        _animeFailure = failure;
        _animeState = _stateFor(failure);
      },
    );
    _safeNotify();
  }

  List<CatalogAnime> _mergeAnime(
    List<CatalogAnime> current,
    List<CatalogAnime> incoming,
  ) {
    final seen = current.map((item) => item.id).toSet();
    return <CatalogAnime>[
      ...current,
      ...incoming.where((item) => seen.add(item.id)),
    ];
  }

  // ----------------------------------------------------------- characters ---

  Future<void> openCharacters(GroupCharacterRequest request) async {
    _charactersDebounce?.cancel();
    if (_charactersRequest?.cacheKey == request.cacheKey &&
        _characters.isNotEmpty &&
        _charactersState == LoadingState.loaded) {
      return;
    }
    _charactersRequest = request;
    _charactersGeneration += 1;
    _characters = const <RoleplayCharacter>[];
    _seasons = const <CatalogSeason>[];
    _charactersPage = 0;
    _charactersHasNextPage = false;
    _charactersPageFailure = null;
    _charactersState = LoadingState.loading;
    _charactersFailure = null;
    _safeNotify();
    await _fetchCharacters(
      page: 1,
      generation: _charactersGeneration,
      request: request,
    );
  }

  void searchCharacters(String query) => _scheduleCharacters(
    GroupCharacterRequest.search(
      animeId: _charactersRequest?.animeId,
      query: query,
      groupId: _charactersRequest?.groupId,
    ),
  );

  /// Locks the characters a group has already taken. The keys are known; who
  /// holds them is not, and is never sent to the client.
  void reserve(Set<String> keys) {
    if (keys.isEmpty) return;
    final merged = <String>{..._reservedKeys, ...keys};
    _reservedKeys = merged;
    _characters = _characters
        .map((item) => merged.contains(item.key) ? item.asReserved() : item)
        .toList(growable: false);
    _safeNotify();
  }

  Future<void> loadMoreCharacters() async {
    final request = _charactersRequest;
    if (request == null ||
        !_charactersHasNextPage ||
        _charactersLoadingMore ||
        _characters.isEmpty ||
        _charactersState == LoadingState.loading) {
      return;
    }
    _charactersLoadingMore = true;
    _charactersState = LoadingState.loadingMore;
    _safeNotify();
    await _fetchCharacters(
      page: _charactersPage + 1,
      generation: _charactersGeneration,
      request: request,
      loadMore: true,
    );
  }

  Future<void> retryCharacters() {
    final request = _charactersRequest;
    if (request == null) return Future<void>.value();
    _charactersGeneration += 1;
    if (_characters.isEmpty) {
      _charactersState = LoadingState.loading;
      _charactersFailure = null;
      _safeNotify();
    }
    return _fetchCharacters(
      page: 1,
      generation: _charactersGeneration,
      request: request,
    );
  }

  Future<void> retryCharactersPage() {
    final request = _charactersRequest;
    if (request == null || _characters.isEmpty) return retryCharacters();
    return _fetchCharacters(
      page: _charactersPage + 1,
      generation: _charactersGeneration,
      request: request,
      loadMore: true,
    );
  }

  void _scheduleCharacters(GroupCharacterRequest request) {
    _charactersDebounce?.cancel();
    _charactersRequest = request;
    final generation = ++_charactersGeneration;
    if (_charactersState == LoadingState.loaded) {
      _charactersState = LoadingState.refreshing;
    }
    _safeNotify();
    _charactersDebounce = Timer(debounce, () {
      unawaited(
        _fetchCharacters(
          page: 1,
          generation: generation,
          request: request,
        ),
      );
    });
  }

  Future<void> _fetchCharacters({
    required int page,
    required int generation,
    required GroupCharacterRequest request,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      _charactersPageFailure = null;
    } else {
      _charactersFailure = null;
    }
    final result = await _repository.browseCharacters(request, page: page);
    if (_disposed || generation != _charactersGeneration) return;
    _charactersLoadingMore = false;
    result.fold(
      onSuccess: (page_) {
        final reserved = _reservedKeys;
        final decorated = page_.items
            .map(
              (item) => reserved.contains(item.key) ? item.asReserved() : item,
            )
            .toList(growable: false);
        _characters = loadMore
            ? _mergeCharacters(_characters, decorated)
            : decorated;
        if (page_.seasons.isNotEmpty) _seasons = page_.seasons;
        _charactersPage = page_.page;
        _charactersHasNextPage = page_.hasNextPage && page_.items.isNotEmpty;
        _charactersFailure = null;
        _charactersState = _characters.isEmpty
            ? LoadingState.empty
            : LoadingState.loaded;
      },
      onFailure: (failure) {
        if (loadMore) {
          _charactersPageFailure = failure;
          _charactersState = _characters.isEmpty
              ? _stateFor(failure)
              : LoadingState.loaded;
          return;
        }
        _characters = const <RoleplayCharacter>[];
        _charactersHasNextPage = false;
        _charactersFailure = failure;
        _charactersState = _stateFor(failure);
      },
    );
    _safeNotify();
  }

  List<RoleplayCharacter> _mergeCharacters(
    List<RoleplayCharacter> current,
    List<RoleplayCharacter> incoming,
  ) {
    final seen = current.map((item) => item.key).toSet();
    return <RoleplayCharacter>[
      ...current,
      ...incoming.where((item) => seen.add(item.key)),
    ];
  }

  LoadingState _stateFor(Failure failure) => switch (failure) {
    NetworkError() || TimeoutError() => LoadingState.offline,
    _ => LoadingState.error,
  };

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _animeDebounce?.cancel();
    _charactersDebounce?.cancel();
    super.dispose();
  }

  bool _disposed = false;
}
