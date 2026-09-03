import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final searching = _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AnimeStrings.hubTitle),
        actions: <Widget>[
          PubgetTextButton(
            onPressed: () => AppNavigation.go(context, '/anime/library'),
            semanticLabel: AnimeStrings.libraryTitle,
            child: const Text(AnimeStrings.libraryTitle),
          ),
        ],
      ),
      body: searching ? _searchBody(list) : _hubBody(hub, network),
    );
  }

  Widget _searchBody(AnimeListProvider list) {
    return Column(
      children: <Widget>[
        _searchField(list),
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
        onClear: () {
          _search.clear();
          list.clearSearch();
          setState(() {});
        },
      ),
    );
  }

  Widget _searchResults(AnimeListProvider list) {
    if (_search.text.trim().length < list.minQueryLength) {
      return const PubgetEmptyState(
        title: 'Keep typing',
        message: 'Enter at least 2 characters to search anime.',
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
        slivers: <Widget>[
          SliverToBoxAdapter(child: _searchField(context.read<AnimeListProvider>())),
          if (hub.fromCache)
            SliverToBoxAdapter(
              child: AnimeCachedBanner(offline: !network.isOnline),
            ),
          if (hub.state == LoadingState.initial ||
              hub.state == LoadingState.loading && !_hubHasContent(hub))
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: PubgetSkeleton.card(height: 180),
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
            for (final kind in AnimeCatalogKind.values)
              SliverToBoxAdapter(
                child: AnimeHorizontalStrip(
                  title: kind.label,
                  items: hub.section(kind).items,
                  state: hub.section(kind).state,
                  failure: hub.section(kind).failure?.message,
                  onSeeAll: () => AnimeLinks.openCatalog(context, kind),
                  onRetry: hub.retry,
                ),
              ),
            SliverToBoxAdapter(child: _GenresWrap(hub: hub)),
            SliverToBoxAdapter(child: _SeasonsList(hub: hub)),
          ],
        ],
      ),
    );
  }

  bool _hubHasContent(AnimeHubProvider hub) => AnimeCatalogKind.values.any(
    (kind) => hub.section(kind).items.isNotEmpty,
  );
}

class _GenresWrap extends StatelessWidget {
  const _GenresWrap({required this.hub});
  final AnimeHubProvider hub;

  @override
  Widget build(BuildContext context) {
    final genres = hub.genres.take(24).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              AnimeStrings.genresTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hub.genresState == LoadingState.loading && genres.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 72),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final genre in genres)
                    PubgetSelectionChip(
                      label: genre.name,
                      selected: false,
                      onSelected: (_) => AnimeLinks.openGenre(context, genre),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SeasonsList extends StatelessWidget {
  const _SeasonsList({required this.hub});
  final AnimeHubProvider hub;

  @override
  Widget build(BuildContext context) {
    final years = hub.seasons.take(8).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              AnimeStrings.seasonsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hub.seasonsState == LoadingState.loading && years.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 72),
            )
          else
            for (final year in years)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: PubgetCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${year.year}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final season in year.seasons)
                            PubgetSelectionChip(
                              label: season.label,
                              selected: false,
                              onSelected: (_) => AnimeLinks.openSeason(
                                context,
                                year: year.year,
                                season: season,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
