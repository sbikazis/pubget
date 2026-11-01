import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_buttons.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../theme/anime_hub_colors.dart';
import 'anime_hub_widgets.dart';
import 'anime_widgets.dart';

/// The Anime Hub details hero.
///
/// The poster is blown up as a darkened backdrop with a bottom-up gradient and
/// the real cover art floats on top of it as a smaller card. Below the art sit
/// the title, the native title, a chip row, the Pubget rating on gold with the
/// external score demoted to grey, and the two list actions.
class AnimeDetailsHero extends StatelessWidget {
  const AnimeDetailsHero({
    required this.anime,
    required this.onAddToList,
    this.stats,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.busy = false,
    super.key,
  });

  final Anime anime;

  /// Opens the list status sheet. The five statuses never render inline here.
  final VoidCallback onAddToList;

  final AnimeCommunityStats? stats;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final copy = AnimeCopy.of(context);
    final backdrop = anime.images.largeUrl ?? anime.images.thumbnailUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (backdrop.isEmpty)
                ColoredBox(color: hub.gradient.first)
              else
                Image.network(
                  backdrop,
                  fit: BoxFit.cover,
                  // Small decode: this copy is only ever a backdrop.
                  cacheWidth: 480,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: hub.gradient.first),
                ),
              // Darken the art so the overlaid cover card and chips stay
              // legible no matter how bright the key visual is.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      hub.gradient.first.withValues(alpha: 0.5),
                      hub.gradient.first.withValues(alpha: 0.88),
                      hub.gradient.last,
                    ],
                    stops: const <double>[0, 0.55, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: _CoverCard(anime: anime),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                anime.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (anime.titleArabic != null && anime.titleArabic!.isNotEmpty)
                _LabelledTitle(
                  label: copy.titleArabicLabel,
                  value: anime.titleArabic!,
                ),
              if (anime.titleJapanese != null &&
                  anime.titleJapanese!.isNotEmpty)
                _LabelledTitle(
                  label: copy.titleJapaneseLabel,
                  value: anime.titleJapanese!,
                ),
              const SizedBox(height: AppSpacing.md),
              _ChipRow(anime: anime),
              const SizedBox(height: AppSpacing.md),
              _RatingRow(anime: anime, stats: stats),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PubgetSecondaryButton(
                      key: const Key('anime-add-to-list'),
                      onPressed: busy ? null : onAddToList,
                      semanticLabel: copy.addToList,
                      leadingIcon: Icons.add_rounded,
                      child: Text(copy.addToList),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (onToggleFavorite != null)
                    _FavoriteButton(
                      isFavorite: isFavorite,
                      busy: busy,
                      onPressed: onToggleFavorite,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The floating cover-art card, 16dp radius with a drop shadow.
class _CoverCard extends StatelessWidget {
  const _CoverCard({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Hero(
        tag: animePosterHeroTag(anime.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 128,
            child: AnimePoster(
              images: anime.images,
              memCacheWidth: 360,
              width: 128,
            ),
          ),
        ),
      ),
    );
  }
}

/// Status, season and year, episode count and age rating, all through the
/// translation maps.
/// One of an anime's other titles, named so the member knows which language
/// they are looking at.
class _LabelledTitle extends StatelessWidget {
  const _LabelledTitle({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              letterSpacing: 0.4,
            ),
          ),
          // Original-language titles are written right-to-left for Arabic and
          // top-to-bottom for Japanese, so they are laid out in their own
          // direction rather than the app's.
          Text(
            value,
            style: theme.textTheme.bodyMedium,
            textDirection: value.runes.first < 0x0590 &&
                    value.runes.first <= 0x08FF
                ? TextDirection.rtl
                : null,
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final chips = <Widget>[];

    final status = anime.status;
    if (status != null && status.isNotEmpty) {
      final label = copy.status(status);
      if (label.isNotEmpty) {
        // Green while it is still running, grey once it has finished.
        final airing = label.toLowerCase() == status.toLowerCase()
            ? status.toLowerCase().contains('airing') ||
                  status.toLowerCase().contains('currently')
            : false;
        const live = Color(0xFF7BE495);
        const done = Color(0xFFB9B4C7);
        chips.add(
          _MetaChip(
            label: label,
            icon: airing ? Icons.play_arrow_rounded : Icons.check_rounded,
            foreground: airing ? live : done,
            background: (airing ? live : done).withValues(alpha: 0.16),
          ),
        );
      }
    }

    final subtitle = copy.subtitle(anime);
    if (subtitle.isNotEmpty) {
      chips.add(
        _MetaChip(label: subtitle, icon: Icons.calendar_today_outlined),
      );
    }

    final episodes = anime.episodes;
    if (episodes != null) {
      chips.add(
        _MetaChip(
          label: copy.episodeCount(episodes),
          icon: Icons.view_list_outlined,
        ),
      );
    }

    final age = copy.ageRating(anime.rating);
    if (age.isNotEmpty) {
      chips.add(_MetaChip(label: age, icon: Icons.shield_outlined));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }
}

/// Pubget's own rating leads on a gold plate; the external score is a small
/// grey reference beside it.
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.anime, this.stats});

  final Anime anime;
  final AnimeCommunityStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final copy = AnimeCopy.of(context);
    final app = stats;
    final appScore = app != null && app.hasRatings ? app.averageScore : null;
    final external = anime.score;
    if (appScore == null && external == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (appScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hub.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.star_rounded, size: 18, color: Colors.black87),
                const SizedBox(width: 4),
                Text(
                  appScore.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        if (appScore != null && external != null)
          const SizedBox(width: AppSpacing.sm),
        if (external != null)
          Text(
            '${copy.malScore} ${external.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
    this.foreground,
    this.background,
  });

  final String label;
  final IconData icon;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The favourite heart. It is the only place the heart lives on this page, so
/// the tooltip is the accessible label for its state.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
    this.busy = false,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filledTonal(
        key: const Key('favorite-anime'),
        tooltip: isFavorite ? copy.favorited : copy.favorite,
        onPressed: busy ? null : onPressed,
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AnimeHubColors.of(context).gold : null,
        ),
      ),
    );
  }
}
