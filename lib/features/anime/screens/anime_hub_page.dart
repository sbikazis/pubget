import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_models.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_widgets.dart';

class AnimeHubPage extends StatefulWidget {
  const AnimeHubPage({super.key});

  @override
  State<AnimeHubPage> createState() => _AnimeHubPageState();
}

class _AnimeHubPageState extends State<AnimeHubPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hub = context.read<AnimeHubProvider>();
    Future<void>.microtask(hub.load);
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
    final searching = list.isSearching || _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text(AnimeStrings.hubTitle),
        actions: <Widget>[
          PubgetTextButton(
            onPressed: () => AppNavigation.go(context, '/anime/library'),
            semanticLabel: AnimeStrings.libraryTitle,
            child: const Text(AnimeStrings.libraryTitle),
          ),
        ],
      ),
      body: searching ? _searchBody(hub, list) : _hubBody(hub, network, list),
    );
  }

  Widget _searchBody(AnimeHubProvider hub, AnimeListProvider list) {
    return Column(
      children: <Widget>[
        _searchField(list),
        _filters(hub, list),
        Expanded(child: _searchResults(list)),
      ],
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final type in AnimeTypeFilter.values) ...<Widget>[
                  PubgetSelectionChip(
                    label: type.name.toUpperCase(),
                    selected: filter.type == type,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        type: type,
                        clearType: filter.type == type,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                for (final season in AnimeSeason.values) ...<Widget>[
                  PubgetSelectionChip(
                    label: season.label,
                    selected: filter.season == season,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        season: season,
                        year: filter.year ?? DateTime.now().year,
                        clearSeason: filter.season == season,
                        clearYear: filter.season == season,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                for (final year in years) ...<Widget>[
                  PubgetSelectionChip(
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
                  const SizedBox(width: AppSpacing.sm),
                ],
                for (final genre in hub.genres.take(16)) ...<Widget>[
                  PubgetSelectionChip(
                    label: genre.name,
                    selected: filter.genreId == genre.id,
                    onSelected: (_) => list.applyFilter(
                      filter.copyWith(
                        genreId: genre.id,
                        clearGenre: filter.genreId == genre.id,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
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

  Widget _hubBody(
    AnimeHubProvider hub,
    NetworkService network,
    AnimeListProvider list,
  ) {
    return RefreshIndicator(
      onRefresh: () => hub.load(refresh: true),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _searchField(list)),
          SliverToBoxAdapter(child: _filters(hub, list)),
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
            for (final kind in AnimeCatalogKind.hubHome)
              SliverToBoxAdapter(
                child: AnimeHorizontalStrip(
                  title: kind.label,
                  items: hub.section(kind).items,
                  state: hub.section(kind).state,
                  failure: hub.section(kind).failure?.message,
                  posterWidth: 156,
                  highlightFirst: kind == AnimeCatalogKind.thisSeason,
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
