import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../repositories/anime_repository.dart';

/// View model behind "My list".
///
/// Owns the five status tabs, the search box, the grid/network toggle, the
/// sort order, the format chips and the per-tab scroll offsets. The list
/// entries themselves stay in [AnimeLibraryProvider]; this only hydrates the
/// catalog metadata (poster, year, format) needed to render them, so a
/// member's own titles render with the same cards as the catalog.
final class AnimeMyListProvider extends ChangeNotifier {
  AnimeMyListProvider({
    required AnimeRepository repository,
    required Iterable<AnimeListEntry> Function() entries,
  }) : _repository = repository,
       _entries = entries;

  final AnimeRepository _repository;
  final Iterable<AnimeListEntry> Function() _entries;

  final Map<String, Anime> _summaries = <String, Anime>{};
  final Map<AnimeListStatus, double> _scrollOffsets =
      <AnimeListStatus, double>{};
  final Set<String> _requested = <String>{};

  AnimeListStatus _tab = AnimeListStatus.wantToWatch;
  AnimeListView _view = AnimeListView.grid;
  AnimeListSort _sort = AnimeListSort.recentlyUpdated;
  AnimeListFormatFilter _format = AnimeListFormatFilter.all;
  String _query = '';
  LoadingState _catalogState = LoadingState.initial;
  Failure? _catalogFailure;
  bool _hydrating = false;
  bool _disposed = false;
  int _hydrateGeneration = 0;

  AnimeListStatus get tab => _tab;
  AnimeListView get view => _view;
  AnimeListSort get sort => _sort;
  AnimeListFormatFilter get format => _format;
  String get query => _query;
  bool get hydrating => _hydrating;
  LoadingState get catalogState => _catalogState;
  Failure? get catalogFailure => _catalogFailure;

  bool get hasActiveFilters =>
      _query.trim().isNotEmpty || _format != AnimeListFormatFilter.all;

  void selectTab(AnimeListStatus status) {
    if (_tab == status) return;
    _tab = status;
    notifyListeners();
  }

  void setView(AnimeListView value) {
    if (_view == value) return;
    _view = value;
    notifyListeners();
  }

  void toggleView() => setView(
    _view == AnimeListView.grid ? AnimeListView.network : AnimeListView.grid,
  );

  void setSort(AnimeListSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void setFormat(AnimeListFormatFilter value) {
    if (_format == value) return;
    _format = value;
    notifyListeners();
  }

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  double scrollOffsetFor(AnimeListStatus status) => _scrollOffsets[status] ?? 0;

  void rememberScrollOffset(AnimeListStatus status, double offset) {
    if ((_scrollOffsets[status] ?? 0) == offset) return;
    _scrollOffsets[status] = offset;
  }

  void resetScrollOffsets() {
    if (_scrollOffsets.isEmpty) return;
    _scrollOffsets.clear();
    notifyListeners();
  }

  Anime? animeFor(String animeId) => _summaries[animeId];

  /// Entries for [status] after search, format filtering and sorting.
  List<AnimeListEntry> entriesFor(AnimeListStatus status) {
    final term = _query.toLowerCase();
    final items = _entries()
        .where((entry) => entry.status == status)
        .where((entry) => _matchesFormat(entry))
        .where((entry) {
          if (term.isEmpty) return true;
          final title = entry.title.toLowerCase();
          if (title.contains(term)) return true;
          return (_summaries[entry.animeId]?.title ?? '')
              .toLowerCase()
              .contains(term);
        })
        .toList(growable: false);
    return _sorted(items);
  }

  int countFor(AnimeListStatus status) => entriesFor(status).length;

  int get totalCount => _entries().length;

  bool _matchesFormat(AnimeListEntry entry) {
    if (_format == AnimeListFormatFilter.all) return true;
    final summary = _summaries[entry.animeId];
    if (summary == null) return false;
    if (_format.isAiringState) {
      final status = (summary.status ?? '').toLowerCase();
      return status.contains('airing') && !status.contains('not yet');
    }
    return (summary.type ?? '').trim().toLowerCase() ==
        _format.wireValue.toLowerCase();
  }

  List<AnimeListEntry> _sorted(List<AnimeListEntry> items) {
    final sorted = List<AnimeListEntry>.of(items);
    int byRating(AnimeListEntry entry) => entry.rating ?? 0;
    sorted.sort((a, b) {
      final primary = _compare(a, b, byRating);
      // A stable secondary key keeps the order from flickering between rebuilds
      // when two entries tie on the chosen sort.
      if (primary != 0) return primary;
      return a.animeId.compareTo(b.animeId);
    });
    return sorted;
  }

  int _compare(
    AnimeListEntry a,
    AnimeListEntry b,
    int Function(AnimeListEntry) byRating,
  ) {
    switch (_sort) {
      case AnimeListSort.recentlyUpdated:
        // Deliberately the member's own edit time, not when the title landed
        // in the catalog, so re-starring an entry floats it back to the top.
        final left = a.updatedAt;
        final right = b.updatedAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      case AnimeListSort.titleAsc:
        return _title(a).compareTo(_title(b));
      case AnimeListSort.titleDesc:
        return _title(b).compareTo(_title(a));
      case AnimeListSort.ratingDesc:
        return byRating(b).compareTo(byRating(a));
      case AnimeListSort.ratingAsc:
        return byRating(a).compareTo(byRating(b));
      case AnimeListSort.popularityDesc:
        return (_popularity(b) ?? -1).compareTo(_popularity(a) ?? -1);
      case AnimeListSort.yearDesc:
        return (_year(b) ?? -1).compareTo(_year(a) ?? -1);
      case AnimeListSort.yearAsc:
        return (_year(a) ?? 1 << 30).compareTo(_year(b) ?? 1 << 30);
    }
  }

  String _title(AnimeListEntry entry) {
    final summary = _summaries[entry.animeId];
    if (summary != null && summary.title.isNotEmpty) {
      return summary.title.toLowerCase();
    }
    return entry.title.toLowerCase();
  }

  int? _year(AnimeListEntry entry) => _summaries[entry.animeId]?.year;

  int? _popularity(AnimeListEntry entry) =>
      _summaries[entry.animeId]?.popularity;

  /// Fetches catalog metadata for anything the list references but does not
  /// have yet. Safe to call repeatedly; already-resolved ids are skipped.
  Future<void> hydrate({bool force = false}) async {
    final missing = <String>[
      for (final entry in _entries())
        if (force || !_summaries.containsKey(entry.animeId)) entry.animeId,
    ].where((id) => !_requested.contains(id) || force).toList(growable: false);
    if (missing.isEmpty) {
      if (_catalogState == LoadingState.initial) {
        _catalogState = LoadingState.loaded;
        _safeNotify();
      }
      return;
    }
    missing.forEach(_requested.add);
    final generation = ++_hydrateGeneration;
    _hydrating = true;
    _catalogState = _summaries.isEmpty
        ? LoadingState.loading
        : LoadingState.refreshing;
    _safeNotify();

    final result = await _repository.getAnimeSummaries(missing);
    if (_disposed || generation != _hydrateGeneration) return;
    result.fold(
      onSuccess: (items) {
        for (final anime in items) {
          _summaries[anime.id] = anime;
        }
        _catalogState = LoadingState.loaded;
        _catalogFailure = null;
      },
      onFailure: (failure) {
        _catalogFailure = failure;
        _catalogState = _summaries.isEmpty
            ? LoadingState.offline
            : LoadingState.loaded;
      },
    );
    _hydrating = false;
    _safeNotify();
  }

  Future<void> retry() async {
    _requested.clear();
    _hydrateGeneration += 1;
    await hydrate(force: true);
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

AnimeMyListProvider? maybeAnimeMyList(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<AnimeMyListProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
