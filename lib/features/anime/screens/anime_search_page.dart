import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../home/models/home_models.dart';
import '../../home/repositories/home_repository.dart';
import '../../search/search_hit.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_hub_drawer.dart';
import '../widgets/anime_widgets.dart';

/// Dedicated search surface for the anime hub: a name field, a filter sheet,
/// removable active-filter chips, and an infinite grid of results. Pushed by
/// the hub so the landing page stays a browse page instead of a search form.
class AnimeSearchPage extends StatefulWidget {
  const AnimeSearchPage({super.key});

  @override
  State<AnimeSearchPage> createState() => _AnimeSearchPageState();
}

class _AnimeSearchPageState extends State<AnimeSearchPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Seeding the filter metadata keeps the chips populated on first open.
    Future<void>.microtask(() {
      if (mounted) context.read<AnimeHubProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final hub = context.watch<AnimeHubProvider>();
    final list = context.watch<AnimeListProvider>();
    final activeCount = _activeFilterCount(list.filter);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        centerTitle: true,
        title: Text(copy.openSearch),
        actions: <Widget>[
          IconButton(
            key: const Key('anime-search-filter'),
            tooltip: copy.filters,
            onPressed: () => _openFilterSheet(hub, list),
            icon: Badge.count(
              count: activeCount,
              isLabelVisible: activeCount > 0,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      drawer: AnimeHubDrawer(current: '/anime/search'),
      body: PubgetAtmosphere(
        child: Column(
          children: <Widget>[
            _searchField(list),
            _activeFilterChips(list),
            Expanded(child: _searchResults(list)),
          ],
        ),
      ),
    );
  }

  /// Number of non-text constraints currently applied, surfaced on the filter
  /// action so the user can see filters are active without opening the sheet.
  static int _activeFilterCount(AnimeSearchFilter filter) {
    var count = 0;
    if (filter.type != null) count++;
    if (filter.genreId != null && filter.genreId!.isNotEmpty) count++;
    if (filter.studioId != null && filter.studioId!.isNotEmpty) count++;
    if (filter.season != null && filter.year != null) count++;
    if (filter.airing != null) count++;
    if (filter.ageRating != null) count++;
    if (filter.hasScoreRange) count++;
    return count;
  }

  Future<void> _openFilterSheet(
    AnimeHubProvider hub,
    AnimeListProvider list,
  ) async {
    final result = await PubgetBottomSheet.show<AnimeSearchFilter>(
      context,
      isScrollControlled: true,
      title: AnimeCopy.of(context).filters,
      child: _SearchFilterSheet(initial: list.filter, hub: hub),
    );
    if (result == null || !mounted) return;
    list.applyFilter(result);
  }

  /// Removable chips summarising the active constraints. Removing one re-runs
  /// the search immediately, without a full page reload.
  Widget _activeFilterChips(AnimeListProvider list) {
    final filter = list.filter;
    final copy = AnimeCopy.of(context);
    final chips = <Widget>[
      if (filter.type != null)
        _activeChip(copy.typeFilter(filter.type!), () {
          list.applyFilter(filter.copyWith(clearType: true));
        }, 'type'),
      if (filter.genreId != null && filter.genreId!.isNotEmpty)
        _activeChip(_genreName(filter.genreId!), () {
          list.applyFilter(filter.copyWith(clearGenre: true));
        }, 'genre'),
      if (filter.studioId != null && filter.studioId!.isNotEmpty)
        _activeChip(_studioName(filter.studioId!), () {
          list.applyFilter(filter.copyWith(clearStudio: true));
        }, 'studio'),
      if (filter.season != null && filter.year != null)
        _activeChip('${copy.season(filter.season!)} ${filter.year}', () {
          list.applyFilter(filter.copyWith(clearSeason: true, clearYear: true));
        }, 'season'),
      if (filter.airing != null)
        _activeChip(copy.statusFilter(filter.airing!), () {
          list.applyFilter(filter.copyWith(clearAiring: true));
        }, 'status'),
      if (filter.ageRating != null)
        _activeChip(copy.ageFilter(filter.ageRating!), () {
          list.applyFilter(filter.copyWith(clearAgeRating: true));
        }, 'age'),
      if (filter.hasScoreRange)
        _activeChip(
          copy.scoreRangeLabel(
            filter.minScore?.toStringAsFixed(1) ?? '0',
            filter.maxScore?.toStringAsFixed(1) ?? '10',
          ),
          () {
            list.applyFilter(
              filter.copyWith(clearMinScore: true, clearMaxScore: true),
            );
          },
          'score',
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: chips,
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove, String dim) {
    return InputChip(
      key: Key('anime-active-filter-$dim'),
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }

  String _genreName(String id) {
    final hub = context.read<AnimeHubProvider>();
    for (final genre in hub.genres) {
      if (genre.id == id) return AnimeCopy.of(context).genre(genre.name);
    }
    return id;
  }

  String _studioName(String id) {
    final hub = context.read<AnimeHubProvider>();
    for (final studio in hub.studios) {
      if (studio.id == id) return studio.name;
    }
    return id;
  }

  Widget _searchField(AnimeListProvider list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetSearchField(
        key: const Key('anime-hub-search'),
        controller: _search,
        hint: AnimeCopy.of(context).searchHint,
        onChanged: (value) {
          setState(() {});
          list.searchChanged(value);
        },
        onSubmitted: (value) {
          setState(() {});
          list.searchSubmitted(value);
        },
        onClear: () {
          _search.clear();
          list.clearSearch();
          setState(() {});
        },
      ),
    );
  }

  Widget _searchResults(AnimeListProvider list) {
    if (!list.filter.hasNonTextConstraints &&
        _search.text.trim().length < list.minQueryLength) {
      return PubgetEmptyState(
        title: AnimeCopy.of(context).searchFiltersHint,
        message: AnimeCopy.of(context).searchFiltersHint,
        icon: Icons.search,
      );
    }
    if (list.state == LoadingState.loading ||
        list.state == LoadingState.initial) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: PubgetSkeleton.card(height: 180),
      );
    }
    if (list.state == LoadingState.error) {
      return PubgetErrorState(
        title: AnimeCopy.of(context).unableToLoad,
        message: list.failure?.message ?? AnimeCopy.of(context).checkConnection,
        onRetry: list.retrySearch,
        retryLabel: AnimeCopy.of(context).retry,
      );
    }
    if (list.state == LoadingState.offline && list.items.isEmpty) {
      return PubgetOfflineState(
        message: AnimeCopy.of(context).checkConnection,
        onRetry: list.retrySearch,
        retryLabel: AnimeCopy.of(context).retry,
      );
    }
    if (list.state == LoadingState.empty || list.items.isEmpty) {
      return PubgetEmptyState(
        title: AnimeCopy.of(context).nothingFound,
        message: AnimeCopy.of(context).nothingFoundMessage,
        icon: Icons.movie_filter_outlined,
      );
    }
    return AnimePaginatedList(
      list: list,
      header: _AggregatedSearchStrip(query: _search.text),
    );
  }
}

/// Modal sheet holding every non-text constraint. It edits a *draft* copy of
/// the filter so nothing is committed until the user taps Apply; Reset clears
/// every constraint in place (keeping the typed query) before Apply.
class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.initial, required this.hub});

  final AnimeSearchFilter initial;
  final AnimeHubProvider hub;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late AnimeSearchFilter _draft = widget.initial;

  static const _labelColor = AppColors.goldSheen;

  void _update(AnimeSearchFilter next) => setState(() => _draft = next);

  AnimeSearchFilter get _cleared => _draft.copyWith(
    clearType: true,
    clearSeason: true,
    clearYear: true,
    clearGenre: true,
    clearStudio: true,
    clearAiring: true,
    clearAgeRating: true,
    clearMinScore: true,
    clearMaxScore: true,
  );

  double get _minScore => _draft.minScore ?? 0;
  double get _maxScore => _draft.maxScore ?? 10;

  void _applyScoreRange(RangeValues values) {
    final min = values.start;
    final max = values.end;
    _update(
      _draft.copyWith(
        minScore: min <= 0 ? null : min,
        clearMinScore: min <= 0,
        maxScore: max >= 10 ? null : max,
        clearMaxScore: max >= 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final hub = widget.hub;
    final years = hub.seasons.take(8).map((item) => item.year).toList();
    final seasonYear =
        _draft.year ?? hub.seasons.firstOrNull?.year ?? DateTime.now().year;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _section(copy.filterType, <Widget>[
            for (final type in AnimeTypeFilter.values)
              PubgetSelectionChip(
                key: Key('filter-type-${type.name}'),
                label: copy.typeFilter(type),
                selected: _draft.type == type,
                onSelected: (_) => _update(
                  _draft.copyWith(type: type, clearType: _draft.type == type),
                ),
              ),
          ]),
          _section(copy.filterSeason, <Widget>[
            for (final season in AnimeSeason.values)
              PubgetSelectionChip(
                key: Key('filter-season-${season.name}'),
                label: copy.season(season),
                selected: _draft.season == season,
                onSelected: (_) => _update(
                  _draft.copyWith(
                    season: season,
                    year: seasonYear,
                    clearSeason: _draft.season == season,
                    clearYear: _draft.season == season,
                  ),
                ),
              ),
            for (final year in years)
              PubgetSelectionChip(
                key: Key('filter-year-$year'),
                label: '$year',
                selected: _draft.year == year,
                onSelected: (_) => _update(
                  _draft.copyWith(
                    year: year,
                    season:
                        _draft.season ?? AnimeSeason.fromDate(DateTime.now()),
                    clearYear: _draft.year == year,
                    clearSeason: _draft.year == year,
                  ),
                ),
              ),
          ]),
          if (hub.genres.isNotEmpty)
            _section(copy.filterGenre, <Widget>[
              for (final genre in hub.genres.take(16))
                PubgetSelectionChip(
                  key: Key('filter-genre-${genre.id}'),
                  label: copy.genre(genre.name),
                  selected: _draft.genreId == genre.id,
                  onSelected: (_) => _update(
                    _draft.copyWith(
                      genreId: genre.id,
                      clearGenre: _draft.genreId == genre.id,
                    ),
                  ),
                ),
            ]),
          if (hub.studios.isNotEmpty)
            _section(copy.filterStudio, <Widget>[
              for (final studio in hub.studios.take(16))
                PubgetSelectionChip(
                  key: Key('filter-studio-${studio.id}'),
                  label: studio.name,
                  selected: _draft.studioId == studio.id,
                  onSelected: (_) => _update(
                    _draft.copyWith(
                      studioId: studio.id,
                      clearStudio: _draft.studioId == studio.id,
                    ),
                  ),
                ),
            ]),
          _section(copy.filterStatus, <Widget>[
            for (final status in AnimeAiringFilter.values)
              PubgetSelectionChip(
                key: Key('filter-status-${status.name}'),
                label: copy.statusFilter(status),
                selected: _draft.airing == status,
                onSelected: (_) => _update(
                  _draft.copyWith(
                    airing: status,
                    clearAiring: _draft.airing == status,
                  ),
                ),
              ),
          ]),
          _section(copy.filterAgeRating, <Widget>[
            for (final age in AnimeAgeFilter.values)
              PubgetSelectionChip(
                key: Key('filter-age-${age.name}'),
                label: copy.ageFilter(age),
                selected: _draft.ageRating == age,
                onSelected: (_) => _update(
                  _draft.copyWith(
                    ageRating: age,
                    clearAgeRating: _draft.ageRating == age,
                  ),
                ),
              ),
          ]),
          _scoreSection(copy),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const Key('filter-reset'),
                  onPressed: () => _update(_cleared),
                  child: Text(copy.resetFilters),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('filter-apply'),
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text(copy.applyFilters),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreSection(AnimeCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.filterScore,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(copy.filterScoreMin),
            Expanded(
              child: RangeSlider(
                key: const Key('filter-score-slider'),
                min: 0,
                max: 10,
                divisions: 20,
                values: RangeValues(_minScore, _maxScore),
                labels: RangeLabels(
                  _minScore.toStringAsFixed(1),
                  _maxScore.toStringAsFixed(1),
                ),
                onChanged: _applyScoreRange,
              ),
            ),
            Text(copy.filterScoreMax),
          ],
        ),
      ],
    );
  }

  Widget _section(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _AggregatedSearchStrip extends StatefulWidget {
  const _AggregatedSearchStrip({required this.query});

  final String query;

  @override
  State<_AggregatedSearchStrip> createState() => _AggregatedSearchStripState();
}

class _AggregatedSearchStripState extends State<_AggregatedSearchStrip> {
  List<SearchHit> _hits = const <SearchHit>[];

  HomeRepository? _repositoryOf(BuildContext context) {
    try {
      return context.read<HomeRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant _AggregatedSearchStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final copy = AnimeCopy.of(context);
    final query = widget.query.trim();
    final repository = _repositoryOf(context);
    if (query.length < 2 || repository == null) return;
    final list = context.read<AnimeListProvider>();
    final animeHits = <SearchHit>[
      for (final anime in list.items)
        if (anime.id.isNotEmpty)
          SearchHit(
            type: SearchHitType.anime,
            id: anime.id,
            title: anime.title,
            subtitle: copy.entityAnime,
            imageUrl: anime.images.displayUrl,
            route: AnimeLinks.detailsPath(anime.id),
            canonicalUrl: PubgetLinks.anime(anime.id),
          ),
    ];
    final result = await repository.search(query);
    if (!mounted || query != widget.query.trim()) return;
    final discoveryHits = SearchHit.fromDiscovery(
      result.valueOrNull ?? const DiscoverySearchResults(),
    ).where((hit) => hit.type != SearchHitType.user).toList(growable: false);
    final hits = _uniqueHits([
      ...animeHits,
      ...discoveryHits,
    ]).take(8).toList(growable: false);
    setState(() => _hits = hits);
  }

  static List<SearchHit> _uniqueHits(List<SearchHit> hits) {
    final seen = <String>{};
    final unique = <SearchHit>[];
    for (final hit in hits) {
      if (hit.id.isEmpty || hit.route.isEmpty || !seen.add(hit.key)) continue;
      unique.add(hit);
    }
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    if (_hits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AnimeCopy.of(context).aggregatedResults,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.goldSheen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _hits.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _AggregatedHitTile(hit: _hits[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AggregatedHitTile extends StatelessWidget {
  const _AggregatedHitTile({required this.hit});

  final SearchHit hit;

  String _typeLabel(BuildContext context) {
    final copy = AnimeCopy.of(context);
    return switch (hit.type) {
      SearchHitType.group => copy.entityGroup,
      SearchHitType.user => copy.entityPerson,
      SearchHitType.event => copy.entityEvent,
      SearchHitType.anime => copy.entityAnime,
      SearchHitType.fanWork => copy.entityFanWork,
      SearchHitType.character => copy.entityCharacter,
      SearchHitType.reel => copy.entityReel,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: PubgetCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        onTap: () => hit.open(context),
        child: Row(
          children: <Widget>[
            PubgetAvatar(
              imageUrl: hit.imageUrl,
              name: hit.title,
              size: PubgetAvatarSize.small,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _typeLabel(context),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
