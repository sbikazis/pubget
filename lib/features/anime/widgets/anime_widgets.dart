import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_providers.dart';

abstract final class AnimeLinks {
  static String hubPath() => '/anime';

  static String detailsPath(String animeId) => PubgetLinks.animePath(animeId);

  static String canonical(String animeId) => PubgetLinks.anime(animeId);

  static String catalogPath(AnimeCatalogKind kind) =>
      '/anime/browse?kind=${Uri.encodeComponent(kind.routeValue)}';

  static String genrePath(String genreId, {String? name}) {
    final encoded = Uri.encodeComponent(genreId);
    if (name == null || name.isEmpty) return '/anime/genre?genreId=$encoded';
    return '/anime/genre?genreId=$encoded&name=${Uri.encodeComponent(name)}';
  }

  static String seasonPath(int year, AnimeSeason season) =>
      '/anime/season?year=$year&season=${Uri.encodeComponent(season.name)}';

  static void openHub(BuildContext context) =>
      AppNavigation.go(context, hubPath());

  static void openDetails(BuildContext context, String animeId) =>
      AppNavigation.go(context, detailsPath(animeId));

  static void openCatalog(BuildContext context, AnimeCatalogKind kind) =>
      AppNavigation.go(context, catalogPath(kind));

  static void openGenre(BuildContext context, AnimeGenre genre) =>
      AppNavigation.go(context, genrePath(genre.id, name: genre.name));

  static void openSeason(
    BuildContext context, {
    required int year,
    required AnimeSeason season,
  }) => AppNavigation.go(context, seasonPath(year, season));

  static Future<void> copyCanonical(BuildContext context, String animeId) =>
      PubgetLinks.copy(
        context,
        canonical(animeId),
        type: 'anime',
        message: AnimeStrings.copied,
      );

  static Future<void> share(
    BuildContext context,
    String animeId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(animeId),
    title: title,
    type: 'anime',
  );

  static Future<void> copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    PubgetSnackbars.showInfo(context, AnimeStrings.copied);
  }
}

class AnimeCachedBanner extends StatelessWidget {
  const AnimeCachedBanner({this.offline = false, super.key});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: PubgetCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.cached_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                offline ? AnimeStrings.offlineCached : AnimeStrings.cachedBanner,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimePoster extends StatelessWidget {
  const AnimePoster({
    required this.images,
    this.width,
    this.height,
    this.memCacheWidth = 240,
    this.fit = BoxFit.cover,
    super.key,
  });

  final AnimeImages images;
  final double? width;
  final double? height;
  final int memCacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = images.thumbnailUrl ?? images.largeUrl ?? '';
    final radius = BorderRadius.circular(AppRadius.md);
    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: const Icon(Icons.movie_filter_outlined),
      );
    }
    return AppImageLoader(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      borderRadius: radius,
    );
  }
}

class AnimePosterCard extends StatelessWidget {
  const AnimePosterCard({
    required this.anime,
    this.width = 128,
    super.key,
  });

  final Anime anime;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: PubgetCard(
        padding: EdgeInsets.zero,
        onTap: () => AnimeLinks.openDetails(context, anime.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: AnimePoster(images: anime.images, memCacheWidth: 320),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: AnimeScoreBadge(
                    malScore: anime.score,
                    community: maybeAnimeHubSocial(context)?.statsFor(anime.id),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _meta(anime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
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

class AnimeResultTile extends StatelessWidget {
  const AnimeResultTile({required this.anime, super.key});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetCard(
        padding: EdgeInsets.zero,
        onTap: () => AnimeLinks.openDetails(context, anime.id),
        child: SizedBox(
          height: 112,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 80,
                child: AnimePoster(images: anime.images, memCacheWidth: 160),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _meta(anime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          AnimeScoreBadge(
                            malScore: anime.score,
                            community: maybeAnimeHubSocial(
                              context,
                            )?.statsFor(anime.id),
                          ),
                          if (anime.studios.isNotEmpty) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                anime.studios.first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ],
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

class AnimeHorizontalStrip extends StatelessWidget {
  const AnimeHorizontalStrip({
    required this.title,
    required this.items,
    required this.state,
    this.subtitle,
    this.onSeeAll,
    this.onRetry,
    this.failure,
    this.posterWidth = 128,
    this.highlightFirst = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Anime> items;
  final LoadingState state;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRetry;
  final String? failure;
  final double posterWidth;
  final bool highlightFirst;

  double get _stripHeight {
    final width = highlightFirst ? posterWidth + 28 : posterWidth;
    return width * 1.5 + 86;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFFF4D37D),
                        Color(0xFF6C3FC5),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  PubgetTextButton(
                    onPressed: onSeeAll,
                    semanticLabel: AnimeStrings.seeAll,
                    child: const Text(AnimeStrings.seeAll),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state == LoadingState.loading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 180),
            )
          else if (state == LoadingState.error && items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetErrorState(
                title: AnimeStrings.unableToLoad,
                message: failure ?? AnimeStrings.checkConnection,
                onRetry: onRetry,
                retryLabel: AnimeStrings.retry,
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetEmptyState(
                title: AnimeStrings.emptyCatalog,
                icon: Icons.movie_filter_outlined,
              ),
            )
          else
            SizedBox(
              height: _stripHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => AnimePosterCard(
                  anime: items[index],
                  width: highlightFirst && index == 0
                      ? posterWidth + 28
                      : posterWidth,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimeHomeStrip extends StatelessWidget {
  const AnimeHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<AnimeHubProvider>();
    if (hub.state == LoadingState.initial) {
      Future<void>.microtask(hub.load);
    }
    final trending = hub.section(AnimeCatalogKind.thisSeason).items;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PubgetSectionHeader(
            title: AppStrings.of(context).sectionAnime,
            actionLabel: AnimeStrings.seeAll,
            onAction: () => AnimeLinks.openHub(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hub.state == LoadingState.loading && trending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 180),
            )
          else if (trending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetCard(
                onTap: () => AnimeLinks.openHub(context),
                child: const Text('Open Anime Hub to discover titles.'),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: trending.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    AnimePosterCard(anime: trending[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class AnimePaginatedList extends StatelessWidget {
  const AnimePaginatedList({required this.list, super.key});

  final AnimeListProvider list;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >
            notification.metrics.maxScrollExtent - 420) {
          list.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: list.items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            if (!list.fromCache) return const SizedBox.shrink();
            return AnimeCachedBanner(
              offline: list.state == LoadingState.offline,
            );
          }
          if (index == list.items.length + 1) {
            if (list.state == LoadingState.loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (list.pageFailure != null) {
              return PubgetErrorState(
                title: AnimeStrings.unableToLoad,
                message: list.pageFailure!.message,
                onRetry: list.retryLoadMore,
                retryLabel: AnimeStrings.retry,
              );
            }
            if (!list.hasNextPage && list.items.isNotEmpty) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: Text(AnimeStrings.endOfList)),
              );
            }
            return const SizedBox.shrink();
          }
          return AnimeResultTile(anime: list.items[index - 1]);
        },
      ),
    );
  }
}

class AnimeScoreBadge extends StatelessWidget {
  const AnimeScoreBadge({
    this.malScore,
    this.community,
    this.large = false,
    super.key,
  });

  final double? malScore;
  final AnimeCommunityStats? community;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final score = AnimeDisplayedScore.resolve(
      malScore: malScore,
      community: community,
    );
    if (score == null) return const SizedBox.shrink();
    final isApp = score.source == AnimeScoreSource.app;
    final theme = Theme.of(context);
    return DecoratedBox(
      key: Key(isApp ? 'score-badge-app' : 'score-badge-mal'),
      decoration: BoxDecoration(
        color: AppColors.royalNight.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isApp ? AppColors.goldSheen : const Color(0xFF2E51A2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 8,
          vertical: large ? 5 : 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: large ? 18 : 16,
              height: large ? 18 : 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isApp ? AppColors.gold : const Color(0xFF2E51A2),
                shape: BoxShape.circle,
              ),
              child: Text(
                score.badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: large ? 11 : 10,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              score.value.toStringAsFixed(1),
              style: (large
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.labelSmall)
                  ?.copyWith(
                    color: AppColors.goldPale,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _meta(Anime anime) {
  final parts = <String>[
    if (anime.type != null && anime.type!.isNotEmpty) anime.type!,
    if (anime.status != null && anime.status!.isNotEmpty) anime.status!,
    if (anime.year != null) '${anime.year}',
    if (anime.season != null) anime.season!.label,
  ];
  return parts.join(' · ');
}
