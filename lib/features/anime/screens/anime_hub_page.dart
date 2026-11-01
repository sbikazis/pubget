import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_providers.dart';
import '../widgets/anime_hub_drawer.dart';
import '../widgets/anime_widgets.dart';
import 'anime_search_page.dart';

/// The hub is organised by destination: the landing view is the newest-first
/// catalog, and seasonal, popular, and community discovery each keep their own
/// tab instead of being collapsed into one long feed.
class AnimeHubPage extends StatefulWidget {
  const AnimeHubPage({super.key});

  @override
  State<AnimeHubPage> createState() => _AnimeHubPageState();
}

class _AnimeHubPageState extends State<AnimeHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: AnimeHubDestination.values.length,
      vsync: this,
    );
    _tabs.addListener(_onTabChanged);
    Future<void>.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final catalogs = context.read<AnimeHubCatalogProvider>();
    // Only the landing destination fetches eagerly; the rest wait for the tab.
    await catalogs.openLanding();
    if (!mounted) return;
    final social = maybeAnimeHubSocial(context, listen: false);
    if (social != null) {
      await Future.wait(<Future<void>>[
        social.loadTopRated(),
        social.loadMostListed(),
        social.loadPopularCharacters(),
      ]);
    }
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (!mounted) return;
    context.read<AnimeHubCatalogProvider>().open(
      AnimeHubDestination.values[_tabs.index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = context.watch<AnimeHubCatalogProvider>();
    final copy = AnimeCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        centerTitle: true,
        title: Text(copy.hubTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('hub-open-search'),
            tooltip: copy.openSearch,
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          PubgetTextButton(
            onPressed: () => AppNavigation.go(context, '/anime/library'),
            semanticLabel: copy.libraryTitle,
            child: Text(copy.libraryTitle),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            for (final destination in AnimeHubDestination.values)
              Tab(text: copy.hubDestination(destination)),
          ],
        ),
      ),
      drawer: AnimeHubDrawer(current: '/anime'),
      body: PubgetAtmosphere(child: _hubBody(catalogs)),
    );
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AnimeSearchPage()));
  }

  Widget _hubBody(AnimeHubCatalogProvider catalogs) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: PubgetPrimaryButton(
            key: const Key('hub-search-cta'),
            onPressed: _openSearch,
            semanticLabel: AnimeCopy.of(context).openSearch,
            leadingIcon: Icons.search,
            child: Text(AnimeCopy.of(context).openSearch),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              for (final destination in AnimeHubDestination.values)
                _destinationView(catalogs, destination),
            ],
          ),
        ),
      ],
    );
  }

  Widget _destinationView(
    AnimeHubCatalogProvider catalogs,
    AnimeHubDestination destination,
  ) {
    if (!destination.isCatalog) return const _CommunityDestination();
    return _catalogBody(destination, catalogs.catalog(destination));
  }

  Widget _catalogBody(AnimeHubDestination destination, AnimeListProvider catalog) {
    return RefreshIndicator(
      onRefresh: catalog.retry,
      child: PubgetLoadingStateView(
        state: _visibleState(catalog),
        onRetry: catalog.retry,
        empty: PubgetEmptyState(
          title: AnimeCopy.of(context).emptyCatalog,
          message: AnimeCopy.of(context).nothingFoundMessage,
          icon: Icons.movie_filter_outlined,
        ),
        error: PubgetErrorState(
          title: AnimeCopy.of(context).unableToLoad,
          message: catalog.failure?.message ?? AnimeCopy.of(context).checkConnection,
          onRetry: catalog.retry,
          retryLabel: AnimeCopy.of(context).retry,
        ),
        offline: PubgetOfflineState(
          message: AnimeCopy.of(context).checkConnection,
          onRetry: catalog.retry,
        ),
        child: AnimePaginatedList(
          key: Key('hub-${destination.name}-grid'),
          list: catalog,
          header: _destinationHeader(destination, catalog),
        ),
      ),
    );
  }

  /// The season highlight stays above the seasonal grid, and the cached banner
  /// stays honest about where the rows came from.
  Widget? _destinationHeader(
    AnimeHubDestination destination,
    AnimeListProvider catalog,
  ) {
    if (catalog.fromCache) {
      final network = context.watch<NetworkService>();
      return AnimeCachedBanner(offline: !network.isOnline);
    }
    if (destination != AnimeHubDestination.thisSeason) return null;
    if (catalog.items.isEmpty) return null;
    return _SeasonHero(anime: catalog.items.first);
  }


  /// Paging and refresh keep the loaded rows on screen instead of flashing the
  /// skeleton over content the member is already reading.
  LoadingState _visibleState(AnimeListProvider catalog) => switch (catalog.state) {
    LoadingState.loadingMore || LoadingState.refreshing => LoadingState.loaded,
    final state => state,
  };
}

/// Community rankings and personalised recommendations, kept as their own hub
/// destination because a paginated catalog grid cannot carry them.
class _CommunityDestination extends StatelessWidget {
  const _CommunityDestination();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        _communitySection(context),
        _recommendationsSection(context),
      ],
    );
  }
}


Widget _communitySection(BuildContext context) {
  final social = maybeAnimeHubSocial(context);
  final copy = AnimeCopy.of(context);
  final mostListed = social?.mostListed ?? const <AnimeCommunityStats>[];
  final characters =
      social?.popularCharacters ?? const <CharacterCommunityStats>[];
  if (mostListed.isEmpty && characters.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            copy.communityStats,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (mostListed.isNotEmpty)
          _CommunityAnimeStrip(
            title: copy.mostListed,
            items: mostListed,
            countLabel: copy.listedCount,
          ),
        if (characters.isNotEmpty)
          _CommunityCharacterStrip(
            title: copy.seasonalCharacters,
            items: characters,
            countLabel: copy.characterFavoritesCount,
          ),
      ],
    ),
  );
}

Widget _recommendationsSection(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final userId = auth.currentUser?.id;
  if (userId == null) return const SizedBox.shrink();
  final copy = AnimeCopy.of(context);
  return Consumer<AnimeRecommendationProvider>(
    builder: (context, provider, _) {
      if (provider.state == LoadingState.initial ||
          provider.state == LoadingState.loading) {
        return const SizedBox.shrink();
      }
      if (provider.recommendations.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                copy.recommendedForYou,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: provider.recommendations.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final rec = provider.recommendations[index];
                  final anime = rec.anime;
                  return SizedBox(
                    width: 132,
                    child: InkWell(
                      onTap: () => AnimeLinks.openDetails(context, anime.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AnimePoster(
                              images: anime.images,
                              memCacheWidth: 264,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            anime.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (anime.score != null && anime.score! > 0)
                            AnimeScoreBadge(
                              malScore: anime.score!,
                              large: false,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CommunityAnimeStrip extends StatelessWidget {
  const _CommunityAnimeStrip({
    required this.title,
    required this.items,
    required this.countLabel,
  });

  final String title;
  final List<AnimeCommunityStats> items;
  final String Function(int count) countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CommunityHeader(title: title, subtitle: null),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 132,
                  child: InkWell(
                    onTap: () => AnimeLinks.openDetails(context, item.animeId),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AnimePoster(
                            images: AnimeImages(thumbnailUrl: item.imageUrl),
                            memCacheWidth: 264,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.title.isEmpty ? item.animeId : item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          countLabel(item.listedCount),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCharacterStrip extends StatelessWidget {
  const _CommunityCharacterStrip({
    required this.title,
    required this.items,
    required this.countLabel,
  });

  final String title;
  final List<CharacterCommunityStats> items;
  final String Function(int count) countLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CommunityHeader(title: title, subtitle: null),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 132,
                child: InkWell(
                  onTap: () =>
                      AnimeLinks.openCharacter(context, item.characterId),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AnimePoster(
                          images: AnimeImages(thumbnailUrl: item.imageUrl),
                          memCacheWidth: 264,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.name.isEmpty ? item.characterId : item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        countLabel(item.favoritesCount),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
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
                child: AnimePoster(images: anime.images, memCacheWidth: 360),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AnimeCopy.of(
                          context,
                        ).catalog(AnimeCatalogKind.thisSeason),
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
                          if (AnimeCopy.of(context).subtitle(anime).isNotEmpty)
                            AnimeCopy.of(context).subtitle(anime),
                          if (anime.studios.isNotEmpty) anime.studios.first,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        anime.synopsis ??
                            AnimeCopy.of(context).thisSeasonSubtitle,
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
