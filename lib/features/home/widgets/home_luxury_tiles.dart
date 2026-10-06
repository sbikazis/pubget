import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../edits/models/edit_models.dart';
import '../../groups/models/group_models.dart';
import '../../social/models/public_profile.dart';

/// How a group section is presented. Each finish is a genuinely different card
/// — Master Spec §5.3 forbids "one card with only the title changed".
enum HomeGroupFinish { gold, silver, rising }

/// Themed gradient for each card treatment.
///
/// Colours come from the palette and the active `ColorScheme` rather than
/// fixed literals, so light and dark are each designed instead of one being
/// an inversion of the other (spec §1.3).
({List<Color> colors, Color text, Color mutedText, Color border}) _groupFinish(
  HomeGroupFinish finish,
  ColorScheme scheme,
) {
  return switch (finish) {
    HomeGroupFinish.gold => (
      colors: <Color>[AppColors.goldPale, AppColors.goldLight, AppColors.gold],
      text: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      border: AppColors.goldSheen,
    ),
    HomeGroupFinish.silver => (
      colors: <Color>[
        scheme.surfaceContainerHighest,
        scheme.surfaceContainerHigh,
        scheme.outlineVariant,
      ],
      text: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      border: scheme.outlineVariant,
    ),
    HomeGroupFinish.rising => (
      colors: <Color>[
        AppColors.royalPurplePale,
        AppColors.royalPurpleLight,
        AppColors.royalPurple,
      ],
      text: AppColors.royalNight,
      mutedText: AppColors.royalNight,
      border: AppColors.royalPurpleDark,
    ),
  };
}

/// Branded stand-in used whenever a group has no usable image.
///
/// A generic `Icons.broken_image_outlined` or a bare box is forbidden by the
/// brief; this shows the group's initial on the card's own gradient.
class _GroupImageFallback extends StatelessWidget {
  const _GroupImageFallback({required this.group, required this.seed});

  final Group group;
  final Color seed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = group.name.trim().isEmpty
        ? '?'
        : group.name.trim().characters.first.toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            seed.withValues(alpha: 0.18),
            scheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Promoted / recommended / rising group card.
///
/// The three `HomeGroupFinish` values share layout but not styling, and the
/// reason chip states the real signal instead of a decorative label.
class HomeSquareGroupCard extends StatelessWidget {
  const HomeSquareGroupCard({
    required this.group,
    required this.finish,
    this.reasonLabel,
    super.key,
  });

  final Group group;
  final HomeGroupFinish finish;
  final String? reasonLabel;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _groupFinish(finish, scheme);
    final image = group.imageUrl;
    final hasImage = image != null && image.trim().isNotEmpty;
    return SizedBox(
      width: 168,
      child: Semantics(
        button: true,
        label: <String>[
          group.name,
          copy.membersCount(group.membersCount),
          copy.groupTypeLabel(group.type.name),
          ?reasonLabel,
        ].join(', '),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                AppNavigation.go(context, '/group?groupId=${group.id}'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.colors,
                ),
                border: Border.all(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: hasImage
                            ? AppImageLoader(
                                imageUrl: image,
                                fit: BoxFit.cover,
                                memCacheWidth: 420,
                                placeholder: PubgetSkeleton.card(
                                  height: double.infinity,
                                ),
                                errorWidget: _GroupImageFallback(
                                  group: group,
                                  seed: palette.colors.last,
                                ),
                              )
                            : _GroupImageFallback(
                                group: group,
                                seed: palette.colors.last,
                              ),
                      ),
                    ),
                    if (reasonLabel != null) ...<Widget>[
                      const SizedBox(height: 6),
                      _ReasonTag(
                        label: reasonLabel!,
                        accent: palette.colors.last,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      copy.membersCount(group.membersCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill that states why an item is on Home (spec §5.4 requires a real
/// reason, never a decorative one).
class _ReasonTag extends StatelessWidget {
  const _ReasonTag({required this.label, required this.accent});

  final String? label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Text(
          label ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Person card. Uses the theme's surfaces instead of the off-brand mint
/// gradient that previously broke the purple + gold identity.
class HomePersonCard extends StatelessWidget {
  const HomePersonCard({required this.person, this.reasonLabel, super.key});

  final PublicProfile person;
  final String? reasonLabel;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = person.primaryName(fallback: copy.pubgetUser);
    final handle = person.distinctHandle;
    return SizedBox(
      width: 156,
      child: Semantics(
        button: true,
        label: <String>[
          name,
          ?handle,
          copy.fansCount(person.fansCount),
          ?reasonLabel,
        ].join(', '),
        child: Material(
          color: scheme.surfaceContainer,
          child: InkWell(
            onTap: () =>
                AppNavigation.go(context, '/profile?uid=${person.uid}'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: person.avatarUrl,
                    name: name,
                    size: PubgetAvatarSize.medium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (handle != null)
                    Text(
                      handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    copy.fansCount(person.fansCount),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  if (reasonLabel != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    _ReasonTag(label: reasonLabel!, accent: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reel preview card.
///
/// Performance contract (Master Spec §15.14, §25):
///  * the thumbnail paints first and stays up while the clip loads;
///  * a clip is only initialised once the card is genuinely visible, and only
///    while it is the active preview in its strip;
///  * the controller is disposed as soon as the card leaves the viewport.
///
/// The previous implementation created and played one `VideoPlayerController`
/// per built card with no viewport awareness, which meant N simultaneous
/// decoders and a full-clip download for every row.
class HomeEditPreviewCard extends StatefulWidget {
  const HomeEditPreviewCard({
    required this.edit,
    this.active = false,
    super.key,
  });

  final Edit edit;

  /// Whether this card is the one allowed to play in its strip.
  final bool active;

  @override
  State<HomeEditPreviewCard> createState() => HomeEditPreviewCardState();
}

class HomeEditPreviewCardState extends State<HomeEditPreviewCard> {
  VideoPlayerController? _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _prepare();
  }

  @override
  void didUpdateWidget(HomeEditPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _prepare();
    } else {
      _release();
    }
  }

  /// Keep the preview short so a Home rail reads as a teaser, not a playback
  /// surface. Attached only while this card is the active preview.
  void _loopFirstSecond() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (player.value.position < const Duration(seconds: 1)) return;
    player.seekTo(Duration.zero);
    player.play();
  }

  Future<void> _prepare() async {
    if (_player != null) return;
    final url = widget.edit.videoUrl.trim();
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    await controller.setVolume(0);
    await controller.setLooping(false);
    try {
      await controller.initialize();
      if (!mounted || _player != controller) {
        await controller.dispose();
        return;
      }
      controller.addListener(_loopFirstSecond);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } on Object {
      if (_player == controller) {
        _player = null;
        await controller.dispose();
      }
      if (mounted) setState(() => _ready = false);
    }
  }

  Future<void> _release() async {
    final controller = _player;
    _player = null;
    controller?.removeListener(_loopFirstSecond);
    if (!mounted) {
      await controller?.dispose();
      return;
    }
    setState(() => _ready = false);
    await controller?.dispose();
  }

  @override
  void dispose() {
    _player?.removeListener(_loopFirstSecond);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    final copy = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = edit.caption.trim().isNotEmpty
        ? edit.caption
        : edit.animeTag.trim().isNotEmpty
        ? edit.animeTag
        : copy.sectionEdits;
    final thumbnail = edit.thumbnailUrl.trim();
    return SizedBox(
      width: 168,
      child: Semantics(
        button: true,
        label: <String>[title, '${edit.likesCount}'].join(', '),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => AppNavigation.go(context, '/reels'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Thumbnail is the base layer, so it is visible from the first
                  // frame and never flashes while the clip loads.
                  if (thumbnail.isNotEmpty)
                    AppImageLoader(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      memCacheWidth: 480,
                      placeholder: PubgetSkeleton.card(height: double.infinity),
                      errorWidget: ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_filter_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_filter_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (_ready && _player != null)
                    ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _player!.value.size.width,
                          height: _player!.value.size.height,
                          child: VideoPlayer(_player!),
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Color(0xCC140C22)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.favorite,
                              size: 14,
                              color: Color(0xFFFF8A9B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${edit.likesCount}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal rail that activates a single preview at a time.
///
/// Only the card nearest the centre of the viewport is allowed to decode
/// video; every other card shows its thumbnail.
class HomePreviewStrip extends StatefulWidget {
  const HomePreviewStrip({
    required this.items,
    required this.height,
    super.key,
  });

  final List<Edit> items;
  final double height;

  @override
  State<HomePreviewStrip> createState() => HomePreviewStripState();
}

class HomePreviewStripState extends State<HomePreviewStrip> {
  final ScrollController _controller = ScrollController();
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recomputeActive);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeActive());
  }

  void _recomputeActive() {
    if (!_controller.hasClients || widget.items.isEmpty) return;
    final position = _controller.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    // Centre of the viewport in global-ish rail coordinates.
    final centre = position.pixels + viewport / 2;
    final cardWidth = 168 + AppSpacing.sm;
    var best = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < widget.items.length; index++) {
      final cardCentre = index * cardWidth + 168 / 2;
      final distance = (cardCentre - centre).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    if (best != _activeIndex) setState(() => _activeIndex = best);
  }

  @override
  void dispose() {
    _controller.removeListener(_recomputeActive);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => HomeEditPreviewCard(
          edit: widget.items[index],
          active: index == _activeIndex,
        ),
      ),
    );
  }
}

class HomeHorizontalStrip extends StatelessWidget {
  const HomeHorizontalStrip({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final double height;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
