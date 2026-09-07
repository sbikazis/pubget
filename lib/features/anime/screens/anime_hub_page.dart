import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_widgets.dart';

class AnimeHubPage extends StatefulWidget {
  const AnimeHubPage({super.key});

  @override
  State<AnimeHubPage> createState() => _AnimeHubPageState();
}

class _AnimeHubPageState extends State<AnimeHubPage> {
  final _search = TextEditingController();
  var _searchOpen = false;

  @override
  void initState() {
    super.initState();
    final hub = context.read<AnimeHubProvider>();
    Future<void>.microtask(hub.load);
    final social = maybeAnimeHubSocial(context, listen: false);
    if (social != null) {
      Future<void>.microtask(social.loadTopRated);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<AnimeHubProvider>();
    final list = context.watch<AnimeListProvider>();
    final network = context.watch<NetworkService>();
    return Scaffold(
      appBar: AppBar(
        leading: _searchOpen
            ? IconButton(
                key: const Key('hub-close-search'),
                tooltip: AnimeStrings.closeSearch,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _closeSearch(list),
              )
            : AppBackButton.maybeOf(context),
        title: Text(
          _searchOpen ? AnimeStrings.openSearch : AnimeStrings.hubTitle,
        ),
        actions: <Widget>[
          if (!_searchOpen)
            IconButton(
              key: const Key('hub-open-search'),
              tooltip: AnimeStrings.openSearch,
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
            ),
          PubgetTextButton(
            onPressed: () => AppNavigation.go(context, '/anime/library'),
            semanticLabel: AnimeStrings.libraryTitle,
            child: const Text(AnimeStrings.libraryTitle),
          ),
        ],
      ),
      body: PubgetAtmosphere(
        child: _searchOpen
            ? Column(
                children: <Widget>[
                  _searchField(list),
                  _filters(hub, list),
                  Expanded(child: _searchResults(list)),
                ],
              )
            : _hubBody(hub, network),
      ),
    );
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
  }

  void _closeSearch(AnimeListProvider list) {
    _search.clear();
    list.clearSearch();
    setState(() => _searchOpen = false);
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
        hint: AnimeStrings.searchHint,
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
            label: AnimeStrings.filterType,
            children: <Widget>[
              for (final type in AnimeTypeFilter.values)
                PubgetSelectionChip(
                  key: Key('filter-type-${type.name}'),
                  label: type.name.toUpperCase(),
                  selected: filter.type == type,
                  onSelected: (_) => list.applyFilter(
                    filter.copyWith(
                      type: type,
                      clearType: filter.type == type,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _chipRow(
            label: AnimeStrings.filterSeason,
            children: <Widget>[
              for (final season in AnimeSeason.values)
                PubgetSelectionChip(
                  key: Key('filter-season-${season.name}'),
                  label: season.label,
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
                      season: filter.season ??
                          AnimeSeason.fromDate(DateTime.now()),
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
              label: AnimeStrings.filterGenre,
              children: <Widget>[
                for (final genre in hub.genres.take(16))
                  PubgetSelectionChip(
                    key: Key('filter-genre-${genre.id}'),
                    label: genre.name,
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
      return const PubgetEmptyState(
        title: AnimeStrings.searchFiltersHint,
        message: AnimeStrings.searchFiltersHint,
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
    if (list.state == LoadingState.empty) {
      return const PubgetEmptyState(
        title: AnimeStrings.nothingFound,
        message: AnimeStrings.nothingFoundMessage,
        icon: Icons.movie_filter_outlined,
      );
    }
    if (list.state == LoadingState.error) {
      return PubgetErrorState(
        title: AnimeStrings.unableToLoad,
        message: list.failure?.message ?? AnimeStrings.checkConnection,
        onRetry: list.retrySearch,
        retryLabel: AnimeStrings.retry,
      );
    }
    if (list.state == LoadingState.offline && list.items.isEmpty) {
      return PubgetOfflineState(
        message: AnimeStrings.checkConnection,
        onRetry: list.retrySearch,
      );
    }
    return AnimePaginatedList(list: list);
  }

  Widget _hubBody(AnimeHubProvider hub, NetworkService network) {
    return RefreshIndicator(
      onRefresh: () => hub.load(refresh: true),
      child: CustomScrollView(
        cacheExtent: 800,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: PubgetPrimaryButton(
                key: const Key('hub-search-cta'),
                onPressed: _openSearch,
                semanticLabel: AnimeStrings.openSearch,
                leadingIcon: Icons.search,
                child: const Text(AnimeStrings.openSearch),
              ),
            ),
          ),
          if (hub.fromCache)
            SliverToBoxAdapter(
              child: AnimeCachedBanner(offline: !network.isOnline),
            ),
          if (hub.state == LoadingState.initial ||
              hub.state == LoadingState.loading && !_hubHasContent(hub))
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: PubgetSkeleton.card(height: 220),
              ),
            )
          else if (hub.state == LoadingState.error && !_hubHasContent(hub))
            SliverToBoxAdapter(
              child: PubgetErrorState(
                title: AnimeStrings.unableToLoad,
                message: hub.failure?.message ?? AnimeStrings.checkConnection,
                onRetry: hub.retry,
                retryLabel: AnimeStrings.retry,
              ),
            )
          else if (hub.state == LoadingState.offline && !_hubHasContent(hub))
            SliverToBoxAdapter(
              child: PubgetOfflineState(
                onRetry: hub.retry,
                message: AnimeStrings.checkConnection,
              ),
            )
          else if (hub.state == LoadingState.empty)
            const SliverToBoxAdapter(
              child: PubgetEmptyState(
                title: AnimeStrings.emptyCatalog,
                icon: Icons.movie_filter_outlined,
              ),
            )
          else ...[
            if (hub.section(AnimeCatalogKind.thisSeason).items.isNotEmpty)
              SliverToBoxAdapter(
                child: _SeasonHero(
                  anime: hub.section(AnimeCatalogKind.thisSeason).items.first,
                ),
              ),
            for (final kind in AnimeCatalogKind.hubHome)
              SliverToBoxAdapter(
                child: AnimeHorizontalStrip(
                  title: kind.label,
                  subtitle: kind == AnimeCatalogKind.thisSeason
                      ? AnimeStrings.thisSeasonSubtitle
                      : AnimeStrings.popularSubtitle,
                  items: hub.section(kind).items,
                  state: hub.section(kind).state,
                  failure: hub.section(kind).failure?.message,
                  posterWidth: 168,
                  highlightFirst: true,
                  onSeeAll: () => AnimeLinks.openCatalog(context, kind),
                  onRetry: hub.retry,
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _hubHasContent(AnimeHubProvider hub) => AnimeCatalogKind.hubHome.any(
    (kind) => hub.section(kind).items.isNotEmpty,
  );
}

class _SeasonHero extends StatelessWidget {
  const _SeasonHero({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: PubgetCard(
        padding: EdgeInsets.zero,
        onTap: () => AnimeLinks.openDetails(context, anime.id),
        child: SizedBox(
          height: 196,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 132,
                child: AnimePoster(
                  images: anime.images,
                  memCacheWidth: 360,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AnimeCatalogKind.thisSeason.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.goldSheen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AnimeScoreBadge(
                        malScore: anime.score,
                        community: maybeAnimeHubSocial(
                          context,
                        )?.statsFor(anime.id),
                        large: true,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          if (anime.subtitle.isNotEmpty) anime.subtitle,
                          if (anime.studios.isNotEmpty) anime.studios.first,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        anime.synopsis ?? AnimeStrings.thisSeasonSubtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
