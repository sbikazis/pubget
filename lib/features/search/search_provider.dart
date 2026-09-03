import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../anime/models/anime_models.dart';
import '../anime/repositories/anime_repository.dart';
import '../home/models/home_models.dart';
import '../home/repositories/home_repository.dart';
import 'search_hit.dart';
import 'search_query.dart';

final class SearchProvider extends ChangeNotifier {
  SearchProvider({
    required HomeRepository homeRepository,
    AnimeRepository? animeRepository,
    Analytics? analytics,
    this.debounce = const Duration(milliseconds: 280),
  }) : _homeRepository = homeRepository,
       _animeRepository = animeRepository,
       _analytics = analytics;

  final HomeRepository _homeRepository;
  final AnimeRepository? _animeRepository;
  final Analytics? _analytics;
  final Duration debounce;

  DiscoverySearchResults _results = const DiscoverySearchResults();
  List<SearchHit> _hits = const <SearchHit>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String _query = '';
  Timer? _debounce;
  int _generation = 0;
  String? _inflight;
  String? _userId;
  Set<String> _hiddenUserIds = const <String>{};
  bool _disposed = false;

  DiscoverySearchResults get results => _results;
  List<SearchHit> get hits => _hits;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  String get query => _query;
  bool get isRunnable => SearchQuery.isRunnable(_query);

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    resetSession();
  }

  void bindHiddenUsers(Set<String> ids) {
    if (setEquals(_hiddenUserIds, ids)) return;
    _hiddenUserIds = Set<String>.unmodifiable(ids);
    if (_hits.isEmpty && _results.isEmpty) return;
    _hits = SearchHit.fromDiscovery(
      _results,
      hiddenUserIds: _hiddenUserIds,
    );
    if (_state == LoadingState.loaded && _hits.isEmpty) {
      _state = LoadingState.empty;
    }
    _safeNotify();
  }

  void resetSession() {
    _debounce?.cancel();
    _generation++;
    _inflight = null;
    _query = '';
    _results = const DiscoverySearchResults();
    _hits = const <SearchHit>[];
    _state = LoadingState.initial;
    _failure = null;
    _safeNotify();
  }

  void searchChanged(String query) {
    _debounce?.cancel();
    _query = query;
    if (!SearchQuery.isRunnable(query)) {
      _results = const DiscoverySearchResults();
      _hits = const <SearchHit>[];
      _failure = null;
      _state = LoadingState.initial;
      _safeNotify();
      return;
    }
    _debounce = Timer(debounce, () => unawaited(_search(_query)));
    _safeNotify();
  }

  Future<void> retry() => _search(_query);

  Future<void> _search(String raw) async {
    final prefix = SearchQuery.prefix(raw);
    if (prefix.length < SearchQuery.minLength) return;
    if (_inflight == prefix) return;
    final generation = ++_generation;
    _inflight = prefix;
    _state = LoadingState.loading;
    _failure = null;
    _safeNotify();
    _analytics?.logEvent('search', parameters: {'length': prefix.length});

    final homeResult = await _homeRepository.search(prefix);
    Result<AnimePage>? animeResult;
    if (_animeRepository != null) {
      animeResult = await _animeRepository.searchAnime(prefix, limit: 8);
    }
    if (_disposed || generation != _generation) return;
    _inflight = null;

    homeResult.fold(
      onSuccess: (results) {
        final anime = animeResult?.valueOrNull?.items ?? const <Anime>[];
        _results = DiscoverySearchResults(
          groups: results.groups,
          people: results.people,
          events: results.events,
          anime: anime,
          fanWorks: results.fanWorks,
        );
        _hits = SearchHit.fromDiscovery(
          _results,
          hiddenUserIds: _hiddenUserIds,
        );
        _state = _hits.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        final anime = animeResult?.valueOrNull?.items ?? const <Anime>[];
        if (anime.isNotEmpty) {
          _results = DiscoverySearchResults(anime: anime);
          _hits = SearchHit.fromDiscovery(
            _results,
            hiddenUserIds: _hiddenUserIds,
          );
          _state = LoadingState.loaded;
        } else {
          _failure = failure;
          _state = failure is NetworkError
              ? LoadingState.offline
              : LoadingState.error;
        }
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
    _debounce?.cancel();
    super.dispose();
  }
}
