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

enum HomeGroupFinish { gold, silver, rising }

class HomeSquareGroupCard extends StatelessWidget {
  const HomeSquareGroupCard({
    required this.group,
    required this.finish,
    super.key,
  });

  final Group group;
  final HomeGroupFinish finish;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = switch (finish) {
      HomeGroupFinish.gold => const <Color>[
        Color(0xFFFFF4C2),
        AppColors.goldLight,
        AppColors.gold,
      ],
      HomeGroupFinish.silver => const <Color>[
        Color(0xFFF7F7FB),
        Color(0xFFD5D8E2),
        Color(0xFF8E95A8),
      ],
      HomeGroupFinish.rising => const <Color>[
        AppColors.royalPurplePale,
        AppColors.royalPurpleLight,
        AppColors.royalPurple,
      ],
    };
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppNavigation.go(context, '/group?groupId=${group.id}'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: group.imageUrl == null || group.imageUrl!.isEmpty
                          ? ColoredBox(
                              color: theme.colorScheme.surface,
                              child: const Icon(Icons.groups_outlined),
                            )
                          : AppImageLoader(
                              imageUrl: group.imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 420,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B1028),
                    ),
                  ),
                  Text(
                    copy.membersCount(group.membersCount),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF3B2A18),
                    ),
                  ),
                  Text(
                    copy.groupTypeLabel(group.type.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B2A18),
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

class HomePersonCard extends StatelessWidget {
  const HomePersonCard({required this.person, super.key});

  final PublicProfile person;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final name = person.primaryName(fallback: copy.pubgetUser);
    final handle = person.distinctHandle;
    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              AppNavigation.go(context, '/profile?uid=${person.uid}'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFE8FFFB),
                  Color(0xFF9EE8DC),
                  Color(0xFF4EC4B4),
                ],
              ),
              border: Border.all(color: const Color(0xFFD9FFF8)),
            ),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF083832),
                  ),
                ),
                if (handle != null)
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF0F4C46),
                    ),
                  ),
                Text(
                  copy.fansCount(person.fansCount),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F4C46),
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

class HomeEditPreviewCard extends StatefulWidget {
  const HomeEditPreviewCard({required this.edit, super.key});

  final Edit edit;

  @override
  State<HomeEditPreviewCard> createState() => _HomeEditPreviewCardState();
}

class _HomeEditPreviewCardState extends State<HomeEditPreviewCard> {
  VideoPlayerController? _player;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final url = widget.edit.videoUrl.trim();
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    controller.setVolume(0);
    controller.setLooping(false);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      controller.play();
      controller.addListener(_clipFirstSecond);
    }).catchError((_) {
      if (mounted) setState(() => _ready = false);
    });
  }

  void _clipFirstSecond() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (player.value.position >= const Duration(seconds: 1)) {
      player.pause();
      player.seekTo(Duration.zero);
      player.play();
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_clipFirstSecond);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    final title = edit.caption.trim().isNotEmpty
        ? edit.caption
        : edit.animeTag.trim().isNotEmpty
        ? edit.animeTag
        : AppStrings.of(context).sectionEdits;
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppNavigation.go(context, '/edits'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (_ready && _player != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _player!.value.size.width,
                      height: _player!.value.size.height,
                      child: VideoPlayer(_player!),
                    ),
                  )
                else if (edit.thumbnailUrl.isNotEmpty)
                  AppImageLoader(
                    imageUrl: edit.thumbnailUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                  )
                else
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.movie_filter_outlined),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Color(0xCC140C22),
                      ],
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
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
