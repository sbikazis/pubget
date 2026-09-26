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
import '../widgets/anime_widgets.dart';

/// Dedicated search surface for the anime hub: a name field, the shared
/// filter chips, and an infinite grid of results. Pushed by the hub so the
/// landing page stays a browse page instead of a search form.
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
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        centerTitle: true,
        title: Text(copy.openSearch),
      ),
      body: PubgetAtmosphere(
        child: Column(
          children: <Widget>[
            _searchField(list),
            _filters(hub, list),
            Expanded(child: _searchResults(list)),
          ],
        ),
      ),
    );
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

  Widget _filters(AnimeHubProvider hub, AnimeListProvider list) {
    final filter = list.filter;
    final years = hub.seasons.take(8).map((item) => item.year).toList();
    final seasonYear =
        filter.year ?? hub.seasons.firstOrNull?.year ?? DateTime.now().year;
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
          _chipRow(
            label: AnimeCopy.of(context).filterType,
            children: <Widget>[
              for (final type in AnimeTypeFilter.values)
                PubgetSelectionChip(
                  key: Key('filter-type-${type.name}'),
                  label: AnimeCopy.of(context).typeFilter(type),
                  selected: filter.type == type,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(type: type, clearType: filter.type == type),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _chipRow(
            label: AnimeCopy.of(context).filterSeason,
            children: <Widget>[
              for (final season in AnimeSeason.values)
                PubgetSelectionChip(
                  key: Key('filter-season-${season.name}'),
                  label: AnimeCopy.of(context).season(season),
                  selected: filter.season == season,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      season: season,
                      year: seasonYear,
                      clearSeason: filter.season == season,
                      clearYear: filter.season == season,
                    ),
                  ),
                ),
              for (final year in years)
                PubgetSelectionChip(
                  key: Key('filter-year-$year'),
                  label: '$year',
                  selected: filter.year == year,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      year: year,
                      season:
                          filter.season ?? AnimeSeason.fromDate(DateTime.now()),
                      clearYear: filter.year == year,
                      clearSeason: filter.year == year,
                    ),
                  ),
                ),
            ],
          ),
          if (hub.genres.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _chipRow(
              label: AnimeCopy.of(context).filterGenre,
              children: <Widget>[
                for (final genre in hub.genres.take(16))
                  PubgetSelectionChip(
                    key: Key('filter-genre-${genre.id}'),
                    label: AnimeCopy.of(context).genre(genre.name),
                    selected: filter.genreId == genre.id,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        genreId: genre.id,
                        clearGenre: filter.genreId == genre.id,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (hub.studios.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _chipRow(
              label: AnimeCopy.of(context).filterStudio,
              children: <Widget>[
                for (final studio in hub.studios.take(16))
                  PubgetSelectionChip(
                    key: Key('filter-studio-${studio.id}'),
                    label: studio.name,
                    selected: filter.studioId == studio.id,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        studioId: studio.id,
                        clearStudio: filter.studioId == studio.id,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _chipRow(
            label: AnimeCopy.of(context).filterStatus,
            children: <Widget>[
              for (final status in AnimeAiringFilter.values)
                PubgetSelectionChip(
                  key: Key('filter-status-${status.name}'),
                  label: AnimeCopy.of(context).statusFilter(status),
                  selected: filter.airing == status,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      airing: status,
                      clearAiring: filter.airing == status,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _chipRow(
            label: AnimeCopy.of(context).filterAgeRating,
            children: <Widget>[
              for (final age in AnimeAgeFilter.values)
                PubgetSelectionChip(
                  key: Key('filter-age-${age.name}'),
                  label: AnimeCopy.of(context).ageFilter(age),
                  selected: filter.ageRating == age,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      ageRating: age,
                      clearAgeRating: filter.ageRating == age,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipRow({required String label, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.goldSheen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, index) => children[index],
          ),
        ),
      ],
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
            subtitle: 'Anime',
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
