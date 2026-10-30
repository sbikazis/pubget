import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../../../core/widgets/pubget_card.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';

/// Small pill used for every Reel metadata token.
class ReelChip extends StatelessWidget {
  const ReelChip({
    required this.label,
    this.icon,
    this.onTap,
    this.onDark = false,
    this.highlighted = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool onDark;
  final bool highlighted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = highlighted
        ? AppColors.gold.withValues(alpha: onDark ? 0.92 : 0.16)
        : onDark
        ? Colors.white.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = highlighted && onDark
        ? AppColors.royalNight
        : onDark
        ? Colors.white
        : theme.colorScheme.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Semantics(
          label: semanticLabel ?? label,
          button: onTap != null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hashtags that route to `/hashtag/:tag`.
class ReelHashtagChips extends StatelessWidget {
  const ReelHashtagChips({
    required this.hashtags,
    this.onDark = false,
    this.limit = 8,
    super.key,
  });

  final List<String> hashtags;
  final bool onDark;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final tags = hashtags
        .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), ''))
        .where((tag) => tag.isNotEmpty)
        .take(limit)
        .toList(growable: false);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final tag in tags)
          ReelChip(
            key: ValueKey<String>('reel-hashtag-$tag'),
            label: '#$tag',
            onDark: onDark,
            onTap: () =>
                AppNavigation.go(context, PubgetLinks.hashtagPath(tag)),
            semanticLabel: '#$tag',
          ),
      ],
    );
  }
}

/// `@handle` tokens — already public text, never user ids.
class ReelMentionChips extends StatelessWidget {
  const ReelMentionChips({
    required this.mentions,
    this.onDark = false,
    super.key,
  });

  final List<String> mentions;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final handles = mentions
        .map((handle) => handle.trim().replaceFirst(RegExp(r'^@+'), ''))
        .where((handle) => handle.isNotEmpty)
        .take(6)
        .toList(growable: false);
    if (handles.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final handle in handles)
          ReelChip(
            key: ValueKey<String>('reel-mention-$handle'),
            label: '@$handle',
            icon: Icons.alternate_email,
            onDark: onDark,
          ),
      ],
    );
  }
}

/// Audio attribution — the entry point into `/audio/:audioId`.
class ReelAudioAttribution extends StatelessWidget {
  const ReelAudioAttribution({
    required this.edit,
    this.creatorName,
    this.onDark = false,
    this.dense = false,
    super.key,
  });

  final Edit edit;
  final String? creatorName;
  final bool onDark;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (edit.audioId.trim().isEmpty) return const SizedBox.shrink();
    final copy = EditCopy.of(context);
    final name = (creatorName ?? '').trim();
    final subtitle = name.isEmpty
        ? copy.originalAudio
        : '${copy.originalAudio} · $name';
    final foreground = onDark ? Colors.white : null;
    return Material(
      color: onDark
          ? Colors.black.withValues(alpha: 0.28)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('reel-audio-attribution'),
        borderRadius: BorderRadius.circular(999),
        onTap: () =>
            AppNavigation.go(context, PubgetLinks.audioPath(edit.audioId)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 4 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.music_note,
                size: dense ? 14 : 18,
                color: onDark ? Colors.white : AppColors.royalPurple,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: dense ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!dense)
                Icon(Icons.chevron_right, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Remix availability, read straight from `allowRemix`.
class ReelRemixBadge extends StatelessWidget {
  const ReelRemixBadge({
    required this.allowRemix,
    this.onDark = false,
    super.key,
  });

  final bool allowRemix;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return ReelChip(
      key: const Key('reel-remix-badge'),
      label: allowRemix ? copy.remixEnabled : copy.remixDisabled,
      icon: allowRemix ? Icons.repeat : Icons.repeat_on_outlined,
      onDark: onDark,
      highlighted: allowRemix,
    );
  }
}

/// Engagement counters already present on the Reel document.
class ReelEngagementCounters extends StatelessWidget {
  const ReelEngagementCounters({
    required this.edit,
    this.onDark = false,
    super.key,
  });

  final Edit edit;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final color = onDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    Widget item(IconData icon, int value, String semantic) => Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
      child: Semantics(
        label: semantic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              copy.compactCount(value),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return Wrap(
      children: <Widget>[
        item(Icons.favorite_border, edit.likesCount, copy.like),
        item(Icons.mode_comment_outlined, edit.commentsCount, copy.comment),
        item(Icons.ios_share, edit.counters.shares, copy.share),
        item(
          Icons.play_circle_outline,
          edit.viewsCount,
          copy.views(edit.viewsCount),
        ),
      ],
    );
  }
}

/// Thumbnail tile that opens the canonical `/reel/:id` route.
class ReelThumbnailTile extends StatelessWidget {
  const ReelThumbnailTile({
    required this.edit,
    this.width = 112,
    this.height = 150,
    super.key,
  });

  final Edit edit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: PubgetCard(
        key: ValueKey<String>('reel-tile-${edit.id}'),
        padding: EdgeInsets.zero,
        onTap: () => AppNavigation.go(context, PubgetLinks.reelPath(edit.id)),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AppImageLoader(imageUrl: edit.thumbnailUrl, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0xCC07060C)],
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.play_circle_outline,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      EditCopy.of(context).compactCount(edit.viewsCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
