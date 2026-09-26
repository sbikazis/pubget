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
import '../widgets/anime_widgets.dart';
import 'anime_search_page.dart';

/// The hub is a browse page: curated rows, seasons, and community picks.
/// Searching is a separate screen so the landing page keeps its shape.
class AnimeHubPage extends StatefulWidget {
  const AnimeHubPage({super.key});

  @override
  State<AnimeHubPage> createState() => _AnimeHubPageState();
}

class _AnimeHubPageState extends State<AnimeHubPage> {
  @override
  void initState() {
    super.initState();
    final hub = context.read<AnimeHubProvider>();
    Future<void>.microtask(hub.load);
    final social = maybeAnimeHubSocial(context, listen: false);
    if (social != null) {
      Future<void>.microtask(social.loadTopRated);
      Future<void>.microtask(social.loadMostListed);
      Future<void>.microtask(social.loadPopularCharacters);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<AnimeHubProvider>();
    final network = context.watch<NetworkService>();
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
      ),
      body: PubgetAtmosphere(child: _hubBody(hub, network)),
    );
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AnimeSearchPage()));
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
                semanticLabel: AnimeCopy.of(context).openSearch,
                leadingIcon: Icons.search,
                child: Text(AnimeCopy.of(context).openSearch),
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
                title: AnimeCopy.of(context).unableToLoad,
                message:
                    hub.failure?.message ??
                    AnimeCopy.of(context).checkConnection,
                onRetry: hub.retry,
                retryLabel: AnimeCopy.of(context).retry,
              ),
            )
          else if (hub.state == LoadingState.offline && !_hubHasContent(hub))
            SliverToBoxAdapter(
              child: PubgetOfflineState(
                onRetry: hub.retry,
                message: AnimeCopy.of(context).checkConnection,
              ),
            )
          else if (hub.state == LoadingState.empty)
            SliverToBoxAdapter(
              child: PubgetEmptyState(
                title: AnimeCopy.of(context).emptyCatalog,
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
                  title: AnimeCopy.of(context).catalog(kind),
                  subtitle: kind == AnimeCatalogKind.thisSeason
                      ? AnimeCopy.of(context).thisSeasonSubtitle
                      : AnimeCopy.of(context).popularSubtitle,
                  items: hub.section(kind).items,
                  state: hub.section(kind).state,
                  failure: hub.section(kind).failure?.message,
                  posterWidth: 168,
                  highlightFirst: true,
                  onSeeAll: () => AnimeLinks.openCatalog(context, kind),
                  onRetry: hub.retry,
                ),
              ),
            SliverToBoxAdapter(child: _communitySection(context)),
            SliverToBoxAdapter(child: _recommendationsSection(context)),
          ],
        ],
      ),
    );
  }

  bool _hubHasContent(AnimeHubProvider hub) => AnimeCatalogKind.hubHome.any(
    (kind) => hub.section(kind).items.isNotEmpty,
  );
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
