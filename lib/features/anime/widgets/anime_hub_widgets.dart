import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../../../core/widgets/pubget_skeleton.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_rating_models.dart';
import '../theme/anime_hub_colors.dart';

/// The hub's own backdrop, so the Anime Hub keeps its identity without
/// changing the palette of the rest of the app.
class AnimeHubBackdrop extends StatelessWidget {
  const AnimeHubBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hub = AnimeHubColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hub.gradient,
        ),
      ),
      child: child,
    );
  }
}

/// The signature "Anime Hub" wordmark used in the header.
class AnimeHubWordmark extends StatelessWidget {
  const AnimeHubWordmark({this.subtitle, super.key});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final hub = AnimeHubColors.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 18, color: hub.gold),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AnimeCopy.of(context).hubTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: hub.royalPurple,
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A marquee that scrolls a long title inside the available width.
class AnimeMarquee extends StatefulWidget {
  const AnimeMarquee({
    required this.text,
    this.style,
    this.maxWidth,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final double? maxWidth;

  @override
  State<AnimeMarquee> createState() => _AnimeMarqueeState();
}

class _AnimeMarqueeState extends State<AnimeMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _controller.repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.titleMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = widget.text;
        if (text.isEmpty) return const SizedBox.shrink();
        final painter = _MarqueePainter(
          text: text,
          style: style ?? const TextStyle(fontSize: 16),
          scroll: _controller,
          direction: Directionality.of(context),
        );
        return ClipRect(
          child: CustomPaint(
            painter: painter,
            size: Size(
              widget.maxWidth ??
                  (constraints.maxWidth.isFinite ? constraints.maxWidth : 0),
              painter.height,
            ),
          ),
        );
      },
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({
    required this.text,
    required this.style,
    required this.scroll,
    required this.direction,
  }) : _layout = _resolveLayout(text, style);

  final String text;
  final TextStyle style;
  final Animation<double> scroll;
  final TextDirection direction;
  final TextPainter? _layout;

  static TextPainter? _resolveLayout(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter;
  }

  double get height => (_layout?.height ?? 0) + style.fontSize! * 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _layout;
    if (layout == null || size.width <= 0) return;
    if (layout.width <= size.width) {
      layout.paint(canvas, Offset.zero);
      return;
    }
    final offset = size.width - (scroll.value * (layout.width + 48));
    final rtl = direction == TextDirection.rtl;
    layout.paint(canvas, Offset(rtl ? offset : offset, 0));
  }

  @override
  bool shouldRepaint(_MarqueePainter old) =>
      old.text != text || old.style != style || old.scroll != scroll;
}

/// The hub's 3-column poster grid used by the catalog, search, library and
/// character screens.
class AnimeHubGrid extends StatelessWidget {
  const AnimeHubGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xxl,
    ),
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.56,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Shared hero tag so a poster keeps its identity from grid to details page.
String animePosterHeroTag(String animeId) => 'anime-poster-$animeId';

/// Shared hero tag for a character portrait moving from a grid to its page.
String animeCharacterHeroTag(String characterId) =>
    'anime-character-$characterId';

/// Three-column shimmer placeholder that matches [AnimeHubGrid].
class AnimeHubGridSkeleton extends StatelessWidget {
  const AnimeHubGridSkeleton({this.itemCount = 9, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AnimeHubGrid(
      itemCount: itemCount,
      itemBuilder: (_, _) =>
          const PubgetSkeleton.card(width: double.infinity, height: 210),
    );
  }
}

/// Poster card used across the hub.
///
/// [year] is painted on the poster, [rating] is the member's own Pubget
/// rating, and [statusLabel] is the personal state badge. Nothing here is an
/// episode or a watch action: Pubget is a catalog and social app.
class AnimeHubPosterCard extends StatelessWidget {
  const AnimeHubPosterCard({
    required this.title,
    required this.imageUrl,
    this.year,
    this.subtitle,
    this.rating,
    this.statusLabel,
    this.favorite = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.heroTag,
    super.key,
  });

  final String title;
  final String imageUrl;
  final int? year;
  final String? subtitle;
  final int? rating;
  final String? statusLabel;
  final bool favorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final poster = AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: animeHubPosterRadius,
        child: imageUrl.isEmpty
            ? ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.movie_filter_outlined)),
              )
            : AppImageLoader(imageUrl: imageUrl, memCacheWidth: 360),
      ),
    );

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: animeHubPosterRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                heroTag == null ? poster : Hero(tag: heroTag!, child: poster),
                if (year != null)
                  PositionedDirectional(
                    start: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _PosterPill(label: '${year!}'),
                  ),
                if (rating != null)
                  PositionedDirectional(
                    end: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _PosterPill(
                      label: '${rating!}',
                      background: hub.royalPurple,
                      foreground: Colors.white,
                      icon: Icons.star_rounded,
                    ),
                  ),
                if (favorite)
                  PositionedDirectional(
                    end: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Icon(
                      Icons.favorite,
                      size: 18,
                      color: hub.gold,
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                if (trailing != null)
                  PositionedDirectional(
                    start: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: trailing!,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (statusLabel != null && statusLabel!.isNotEmpty)
              Text(
                statusLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hub.royalPurple,
                ),
              ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _PosterPill extends StatelessWidget {
  const _PosterPill({
    required this.label,
    this.background,
    this.foreground,
    this.icon,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 12,
              color: foreground ?? theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Network (list) layout: a rounded poster thumbnail with the title and the
/// personal state on the trailing side.
class AnimeHubNetworkTile extends StatelessWidget {
  const AnimeHubNetworkTile({
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.trailingLabel,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String title;
  final String imageUrl;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(animeHubTileRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(animeHubTileRadius),
              child: SizedBox(
                width: 56,
                height: 74,
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie_filter_outlined),
                      )
                    : AppImageLoader(imageUrl: imageUrl, memCacheWidth: 160),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (trailingLabel != null && trailingLabel!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: hub.royalPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailingLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: hub.royalPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const double animeHubTileRadius = 14;

/// Description that shows a few lines and expands on tap, then collapses back.
class AnimeExpandableText extends StatefulWidget {
  const AnimeExpandableText({
    required this.text,
    this.collapsedLines = 4,
    this.style,
    this.selectable = false,
    super.key,
  });

  final String text;
  final int collapsedLines;
  final TextStyle? style;

  /// Selectable body text, for bios the member may want to copy.
  final bool selectable;

  @override
  State<AnimeExpandableText> createState() => _AnimeExpandableTextState();
}

class _AnimeExpandableTextState extends State<AnimeExpandableText> {
  bool _expanded = false;

  /// Laid out at the real width, font and reading direction, so the toggle
  /// appears for text that is genuinely cut off and stays away for text that
  /// fits. The width comes from the incoming constraints because the size of
  /// this render object is not known during build.
  ///
  /// The direction matters: Arabic wraps at different points than English, so
  /// measuring left-to-right would offer "show more" for a paragraph that
  /// already fits in four RTL lines, and hide it for one that does not.
  bool _isClipped(double maxWidth, TextStyle? style, TextDirection direction) {
    if (!maxWidth.isFinite) return false;
    final painter = TextPainter(
      text: TextSpan(text: widget.text.trim(), style: style),
      maxLines: widget.collapsedLines,
      textDirection: direction,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final style = widget.style ?? theme.textTheme.bodyMedium;
    // `_expanded` is intentionally sticky: a parent rebuild must not slam the
    // text the member just opened back to a few lines.
    return LayoutBuilder(
      builder: (context, constraints) {
        final clipped = _isClipped(constraints.maxWidth, style, direction);
        // The toggle stays put once expanded so the text can be folded back
        // up. Disappearing on expand left a member who opened a long bio
        // stuck reading it with no way back.
        final showToggle = clipped || _expanded;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.selectable)
              SelectableText(
                text,
                maxLines: _expanded ? null : widget.collapsedLines,
                style: style,
              )
            else
              Text(
                text,
                maxLines: _expanded ? null : widget.collapsedLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: style,
              ),
            if (showToggle) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('anime-expandable-toggle'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_expanded ? copy.showLess : copy.showMore),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 1–10 vote distribution, drawn from community data only.
///
/// Each row is a gradient bar and tappable, so the bar and the donut above it
/// stay two views of the same numbers: tapping a score reports it upward, and
/// the caller decides what to do with it. The bars themselves stay presentational
/// so the histogram remains readable even where the tap is not wired.
class AnimeVoteDistribution extends StatelessWidget {
  const AnimeVoteDistribution({
    required this.counts,
    this.onScoreTapped,
    this.selectedScore,
    super.key,
  });

  /// Index 0 holds the votes for score 1, index 9 for score 10.
  final List<int> counts;

  /// Fired with the 1-based score the member tapped.
  final ValueChanged<int>? onScoreTapped;

  /// The score currently in focus, highlighted in the bars and the donut.
  final int? selectedScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final total = counts.fold<int>(0, (sum, value) => sum + value);
    final tappable = onScoreTapped != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < counts.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkWell(
              onTap: tappable ? () => onScoreTapped!(index + 1) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: selectedScore == index + 1
                              ? FontWeight.w900
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _GradientBar(
                        value: total == 0 ? 0 : counts[index] / total,
                        // Gold for the scores that mean "worth watching".
                        accent: index + 1 >= 8 ? hub.gold : hub.royalPurple,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${counts[index]}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: selectedScore == index + 1
                              ? FontWeight.w900
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single distribution bar filled with a horizontal gradient so the
/// histogram reads as one continuous shape rather than ten flat rectangles.
class _GradientBar extends StatelessWidget {
  const _GradientBar({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: <Widget>[
          Container(
            height: 8,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[accent.withValues(alpha: 0.55), accent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A slice of [data] drawn as a donut, used for the following-status
/// breakdown on the statistics tab.
class AnimeDonutChart extends StatelessWidget {
  const AnimeDonutChart({
    required this.slices,
    required this.centerLabel,
    this.size = 168,
    super.key,
  });

  final List<AnimeDonutSlice> slices;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices),
        child: Center(
          child: Text(
            centerLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class AnimeDonutSlice {
  const AnimeDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<AnimeDonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.32;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0x22000000),
      );
      return;
    }
    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        math.max(sweep - 0.02, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

/// Legend rows that pair a donut slice with its label and count.
class AnimeDonutLegend extends StatelessWidget {
  const AnimeDonutLegend({required this.slices, super.key});

  final List<AnimeDonutSlice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(slice.label, style: theme.textTheme.bodySmall),
                ),
                Text('${slice.value}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// Score pill that shows the Pubget rating and the MAL rating stacked, with
/// the hub gold reserved for the member-facing rating.
class AnimeHubScorePair extends StatelessWidget {
  const AnimeHubScorePair({required this.malScore, this.community, super.key});

  final double? malScore;
  final AnimeCommunityStats? community;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final appScore = community != null && community!.hasRatings
        ? community!.averageScore
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (appScore != null)
          _ScoreChip(
            badge: 'A',
            value: appScore.toStringAsFixed(1),
            color: hub.royalPurple,
            semanticsLabel: AnimeCopy.of(context).communityScore,
          ),
        if (appScore != null && malScore != null)
          const SizedBox(width: AppSpacing.sm),
        if (malScore != null)
          _ScoreChip(
            badge: 'M',
            value: malScore!.toStringAsFixed(1),
            color: hub.gold,
            semanticsLabel: AnimeCopy.of(context).malScore,
            textColor: hub.readableGold,
          ),
        if (appScore == null && malScore == null)
          Text('—', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.badge,
    required this.value,
    required this.color,
    required this.semanticsLabel,
    this.textColor,
  });

  final String badge;
  final String value;
  final Color color;
  final Color? textColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticsLabel $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            badge,
            style: TextStyle(
              color: textColor ?? color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: textColor ?? color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled chip row used for the anime detail chips and the library
/// format filters.
class AnimeHubChipRow extends StatelessWidget {
  const AnimeHubChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
  }
}

/// Square character portrait: 220×220 with a 32 radius.
class AnimeCharacterPortrait extends StatelessWidget {
  const AnimeCharacterPortrait({
    required this.imageUrl,
    this.name = '',
    this.size = animeHubPortraitSize,
    super.key,
  });

  final String imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: animeHubPortraitRadius,
        child: imageUrl.isEmpty
            ? ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.person_outline, size: 48),
                ),
              )
            : AppImageLoader(imageUrl: imageUrl, memCacheWidth: 480),
      ),
    );
  }
}

/// One key/value row of the adaptive anime or character fact grid.
class AnimeHubFactTile extends StatelessWidget {
  const AnimeHubFactTile({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hub.royalPurple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: hub.royalPurple),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid of [AnimeHubFactTile]s that only renders the facts it is given, so
/// a sparse API payload never produces empty rows.
class AnimeHubFactGrid extends StatelessWidget {
  const AnimeHubFactGrid({required this.facts, super.key});

  final List<AnimeHubFactTile> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.1,
      ),
      itemCount: facts.length,
      itemBuilder: (context, index) => facts[index],
    );
  }
}

/// Banner explaining that the title carries sensitive content.
class AnimeSensitiveContentNotice extends StatelessWidget {
  const AnimeSensitiveContentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AnimeCopy.of(context);
    final hub = AnimeHubColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hub.royalPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hub.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: hub.gold, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.sensitiveContent,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  copy.sensitiveContentBody,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
