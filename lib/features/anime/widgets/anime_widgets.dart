import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_models.dart';
import '../providers/anime_providers.dart';

abstract final class AnimeLinks {
  static String hubPath() => '/anime';

  static String detailsPath(String animeId) =>
      '/anime/${Uri.encodeComponent(animeId)}';

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
    super.key,
  });

  final AnimeImages images;
  final double? width;
  final double? height;
  final int memCacheWidth;

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
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
      borderRadius: radius,
    );
  }
}

class AnimePosterCard extends StatelessWidget {
  const AnimePosterCard({required this.anime, this.width = 128, super.key});

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
            AspectRatio(
              aspectRatio: 2 / 3,
              child: AnimePoster(images: anime.images, memCacheWidth: 280),
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
                    style: theme.textTheme.titleSmall,
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
    return ListTile(
      onTap: () => AnimeLinks.openDetails(context, anime.id),
      leading: SizedBox(
        width: 48,
        height: 64,
        child: AnimePoster(images: anime.images, memCacheWidth: 96),
      ),
      title: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _meta(anime),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class AnimeHorizontalStrip extends StatelessWidget {
  const AnimeHorizontalStrip({
    required this.title,
    required this.items,
    required this.state,
    this.onSeeAll,
    this.onRetry,
    this.failure,
    super.key,
  });

  final String title;
  final List<Anime> items;
  final LoadingState state;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRetry;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
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
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    AnimePosterCard(anime: items[index]),
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
    final trending = hub.section(AnimeCatalogKind.trending).items;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AnimeStrings.hubTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AnimeLinks.openHub(context),
                  semanticLabel: AnimeStrings.seeAll,
                  child: const Text(AnimeStrings.seeAll),
                ),
              ],
            ),
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

String _meta(Anime anime) {
  final parts = <String>[
    if (anime.type != null && anime.type!.isNotEmpty) anime.type!,
    if (anime.status != null && anime.status!.isNotEmpty) anime.status!,
    if (anime.year != null) '${anime.year}',
    if (anime.season != null) anime.season!.label,
    if (anime.score != null) anime.score!.toStringAsFixed(1),
  ];
  return parts.join(' · ');
}
