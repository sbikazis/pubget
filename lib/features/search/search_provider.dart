import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../anime/data/anime_search_ranker.dart';
import '../anime/models/anime_models.dart';
import '../anime/repositories/anime_repository.dart';
import '../home/models/home_models.dart';
import '../home/repositories/home_repository.dart';
import '../reels/models/audio_models.dart';
import '../reels/repositories/audio_repository.dart';
import 'data/shared_preferences_search_history_store.dart';
import 'search_hit.dart';
import 'search_history.dart';
import 'search_query.dart';
import 'search_rank.dart';

final class SearchProvider extends ChangeNotifier {
  SearchProvider({
    required HomeRepository homeRepository,
    AnimeRepository? animeRepository,
    AudioRepository? audioRepository,
    Analytics? analytics,
    SearchHistory? history,
    this.debounce = const Duration(milliseconds: 280),
  }) : _homeRepository = homeRepository,
       _animeRepository = animeRepository,
       _audioRepository = audioRepository,
       _analytics = analytics,
       _history =
           history ??
           SearchHistory(store: SharedPreferencesSearchHistoryStore()) {
    _history.addListener(_onHistoryChanged);
    unawaited(_history.load());
  }

  final HomeRepository _homeRepository;
  final AnimeRepository? _animeRepository;
  final AudioRepository? _audioRepository;
  final Analytics? _analytics;
  final SearchHistory _history;
  final Duration debounce;

  DiscoverySearchResults _results = const DiscoverySearchResults();

  /// Every hit the backend produced, in server relevance order.
  List<SearchHit> _allHits = const <SearchHit>[];

  /// What the screen renders: [_allHits] narrowed by [filter] and re-ordered by
  /// the local fuzzy ranker.
  List<SearchHit> _view = const <SearchHit>[];

  SearchHitType? _filter;
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

  /// The ranked, filtered list the UI shows.
  List<SearchHit> get hits => _view;

  /// The unfiltered set — used to decide whether a filter is what emptied the
  /// screen, so the empty state can say so instead of "nothing found".
  bool get hasAnyHit => _allHits.isNotEmpty;

  LoadingState get state => _state;
  Failure? get failure => _failure;
  String get query => _query;
  bool get isRunnable => SearchQuery.isRunnable(_query);
  SearchHitType? get filter => _filter;
  SearchHistory get history => _history;

  /// Entity types present in the current results, in a stable display order.
  ///
  /// Only types that actually have hits are offered: a chip that can only ever
  /// empty the screen is a dead control.
  List<SearchHitType> get availableFilters {
    final present = <SearchHitType>{for (final hit in _allHits) hit.type};
    return <SearchHitType>[
      for (final type in SearchHitType.values)
        if (present.contains(type)) type,
    ];
  }

  void setFilter(SearchHitType? type) {
    if (_filter == type) return;
    _filter = type;
    _rebuildView();
    _safeNotify();
  }

  /// Remembers [raw] in the recent-search list. Called when the member commits
  /// a search (submits or opens a result), never per keystroke — otherwise the
  /// history would fill with `f`, `fr`, `fri`.
  void recordQuery(String raw) => unawaited(_history.record(raw));

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    resetSession();
  }

  void bindHiddenUsers(Set<String> ids) {
    if (setEquals(_hiddenUserIds, ids)) return;
    _hiddenUserIds = Set<String>.unmodifiable(ids);
    if (_allHits.isEmpty && _results.isEmpty) return;
    _allHits = SearchHit.fromDiscovery(_results, hiddenUserIds: _hiddenUserIds);
    _rebuildView();
    if (_state == LoadingState.loaded && _allHits.isEmpty) {
      _state = LoadingState.empty;
    }
    _safeNotify();
  }

  void resetSession() {
    _debounce?.cancel();
    _generation++;
    _inflight = null;
    _query = '';
    _filter = null;
    _results = const DiscoverySearchResults();
    _allHits = const <SearchHit>[];
    _view = const <SearchHit>[];
    _state = LoadingState.initial;
    _failure = null;
    _safeNotify();
  }

  void searchChanged(String query) {
    _debounce?.cancel();
    _query = query;
    if (!SearchQuery.isRunnable(query)) {
      _results = const DiscoverySearchResults();
      _allHits = const <SearchHit>[];
      _view = const <SearchHit>[];
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

    // Anime and audio are independent lookups; start them before awaiting
    // discovery so the three round-trips overlap instead of queueing.
    final animeFuture = _animeRepository?.searchAnime(prefix, limit: 8);
    final audioFuture = _audioRepository?.searchAudios(query: prefix, limit: 8);

    final homeResult = await _homeRepository.search(prefix);
    final animeResult = animeFuture == null ? null : await animeFuture;
    final audioResult = audioFuture == null ? null : await audioFuture;
    if (_disposed || generation != _generation) return;
    _inflight = null;

    final anime = AnimeSearchRanker.rank(
      animeResult?.valueOrNull?.items ?? const <Anime>[],
      prefix,
      keepUnmatched: true,
    );
    // Audio search is an additional surface: a failure there degrades to "no
    // audio results" instead of failing the whole search.
    final audios = audioResult?.valueOrNull ?? const <ReelAudio>[];

    homeResult.fold(
      onSuccess: (results) {
        _results = DiscoverySearchResults(
          groups: results.groups,
          people: results.people,
          events: results.events,
          anime: anime,
          fanWorks: results.fanWorks,
          characters: results.characters,
          reels: results.reels,
        );
        _applyHits(results, anime: anime, audios: audios);
      },
      onFailure: (failure) {
        if (anime.isNotEmpty || audios.isNotEmpty) {
          _results = DiscoverySearchResults(anime: anime);
          _applyHits(
            const DiscoverySearchResults(),
            anime: anime,
            audios: audios,
          );
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

  void _applyHits(
    DiscoverySearchResults results, {
    required List<Anime> anime,
    required List<ReelAudio> audios,
  }) {
    _allHits = SearchHit.dedupe(<SearchHit?>[
      // Only a query that *is* a hashtag gets the tag destination. A plain
      // word must not be turned into one.
      if (_query.trim().startsWith('#')) SearchHit.hashtag(_query),
      ...SearchHit.fromDiscovery(
        DiscoverySearchResults(
          groups: results.groups,
          people: results.people,
          events: results.events,
          anime: anime,
          fanWorks: results.fanWorks,
          characters: results.characters,
          reels: results.reels,
        ),
        hiddenUserIds: _hiddenUserIds,
      ),
      for (final audio in audios) SearchHit.audio(audio),
    ]);
    _rebuildView();
    _state = _allHits.isEmpty ? LoadingState.empty : LoadingState.loaded;
  }

  /// Applies the entity filter, then ranks locally.
  ///
  /// Ranking **reorders but never drops** server hits: discovery may match on a
  /// field the title does not contain (a description, a creator name), and
  /// silently removing those would look like the result was never found.
  void _rebuildView() {
    final source = _filter == null
        ? _allHits
        : <SearchHit>[
            for (final hit in _allHits)
              if (hit.type == _filter) hit,
          ];
    if (!SearchQuery.isRunnable(_query)) {
      _view = source;
      return;
    }
    final ranked = SearchRank.rank(source, _query, (hit) => hit.title);
    final matched = <String>{for (final hit in ranked) hit.key};
    _view = <SearchHit>[
      ...ranked,
      for (final hit in source)
        if (!matched.contains(hit.key)) hit,
    ];
  }

  void _onHistoryChanged() => _safeNotify();

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _history.removeListener(_onHistoryChanged);
    super.dispose();
  }
}
