import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../../../core/theme/app_spacing.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../providers/anime_providers.dart';
import '../theme/anime_hub_colors.dart';
import 'anime_hub_widgets.dart';
import 'anime_widgets.dart';

/// The single ranked anime card.
///
/// Both ranking pages (MAL top rated and the Pubget community rating) render
/// this one component. Previously each page hand-rolled its own row, so the two
/// rankings looked like different products and disagreed on the badge, the
/// score colour and the caption.
class AnimeRankedCard extends StatelessWidget {
  const AnimeRankedCard({
    required this.rank,
    required this.title,
    required this.imageUrl,
    this.score,
    this.scoreLabel,
    this.caption,
    this.heroTag,
    this.onTap,
    super.key,
  });

  /// One-based position in the ranking.
  final int rank;
  final String title;
  final String imageUrl;

  /// The score this page ranks by, 0-10.
  final double? score;

  /// The source the score came from, e.g. MAL or Pubget.
  final String? scoreLabel;

  /// Secondary line, already localized by the caller.
  final String? caption;
  final Object? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final hub = AnimeHubColors.of(context);
    final name = title.isEmpty ? copy.unnamedAnime : title;

    return Semantics(
      button: true,
      label: '$rank. $name',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _RankBadge(rank: rank),
              const SizedBox(width: AppSpacing.md),
              Hero(
                tag: heroTag ?? animePosterHeroTag(name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 64,
                    child: AnimePoster(
                      images: AnimeImages(thumbnailUrl: imageUrl),
                      memCacheWidth: 140,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (score != null)
                      Text(
                        scoreLabel == null
                            ? score!.toStringAsFixed(1)
                            : '$scoreLabel ${score!.toStringAsFixed(1)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: hub.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (caption != null && caption!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The medal-style position marker. The leader gets gold, the rest the hub
/// purple, so the top of a ranking reads at a glance.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final hub = AnimeHubColors.of(context);
    final theme = Theme.of(context);
    final top = rank <= 3;
    final color = top ? hub.gold : hub.royalPurple;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: top ? 1.6 : 1),
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.labelLarge?.copyWith(
          color: top ? hub.gold : hub.royalPurple,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Paginated ranked grid for the MAL ranking, which reads the paged catalog
/// provider rather than a single community snapshot.
class AnimeRankedPaginatedGrid extends StatelessWidget {
  const AnimeRankedPaginatedGrid({required this.list, super.key});

  final AnimeListProvider list;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    return AnimePaginatedList(
      list: list,
      header: null,
      // The ranked list is a list, not a poster wall, so the shared paginated
      // scroller is reused with a list-shaped grid delegate.
      itemBuilder: (context, index) {
        final anime = list.items[index];
        return AnimeRankedCard(
          rank: index + 1,
          title: anime.title,
          imageUrl: anime.images.largeUrl ?? anime.images.thumbnailUrl ?? '',
          score: anime.score,
          scoreLabel: copy.malScore,
          heroTag: animePosterHeroTag(anime.id),
          onTap: () => AnimeLinks.openDetails(context, anime.id),
        );
      },
    );
  }
}

/// The community ranking, driven by the member-rated snapshot.
class AnimeCommunityRankedList extends StatelessWidget {
  const AnimeCommunityRankedList({required this.items, super.key});

  final List<AnimeCommunityStats> items;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return AnimeRankedCard(
          rank: index + 1,
          title: item.title,
          imageUrl: item.imageUrl ?? '',
          score: item.hasRatings ? item.averageScore : null,
          scoreLabel: copy.communityScore,
          caption: copy.ratingsCount(item.ratingCount),
          heroTag: animePosterHeroTag(item.animeId),
          onTap: () => AnimeLinks.openDetails(context, item.animeId),
        );
      },
    );
  }
}

/// The single ranked character card.
///
/// Shared by the popular-characters page and the favourites page so a member
/// sees the same card whichever door they came in by.
class AnimeRankedCharacterCard extends StatelessWidget {
  const AnimeRankedCharacterCard({
    required this.name,
    required this.imageUrl,
    this.rank,
    this.likes,
    this.heroTag,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String name;
  final String imageUrl;

  /// One-based position, or null on the favourites page where order is by
  /// when the member added them.
  final int? rank;
  final int? likes;
  final Object? heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final hub = AnimeHubColors.of(context);
    final label = name.isEmpty ? copy.unnamedCharacter : name;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: animeHubPosterRadius,
                    child: Hero(
                      tag: heroTag ?? animeCharacterHeroTag(label),
                      child: imageUrl.isEmpty
                          ? ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.person_outline),
                            )
                          : AppImageLoader(
                              imageUrl: imageUrl,
                              memCacheWidth: 360,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (rank != null)
                    PositionedDirectional(
                      top: AppSpacing.xs,
                      start: AppSpacing.xs,
                      child: _RankBadge(rank: rank!),
                    ),
                  if (likes != null)
                    PositionedDirectional(
                      bottom: AppSpacing.xs,
                      start: 0,
                      end: 0,
                      child: Center(
                        child: _CharacterLikes(count: likes!, gold: hub.gold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
            if (likes != null)
              Text(
                copy.likesCount(likes!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Heart-plus-count pill shown over a character portrait.
class _CharacterLikes extends StatelessWidget {
  const _CharacterLikes({required this.count, required this.gold});

  final int count;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.favorite, size: 12, color: gold),
          const SizedBox(width: 4),
          Text(
            AnimeCopy.of(context).compactCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
