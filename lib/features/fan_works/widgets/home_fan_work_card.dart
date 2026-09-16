import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/fan_work_models.dart';
import 'fan_work_widgets.dart';

class HomeFanWorkCard extends StatelessWidget {
  const HomeFanWorkCard({required this.work, super.key});

  final FanWork work;

  static Color typeColor(FanWorkType type) => switch (type) {
    FanWorkType.manga => const Color(0xFF3B82F6),
    FanWorkType.drawing => const Color(0xFFE37AA8),
    FanWorkType.story => AppColors.royalPurpleLight,
    FanWorkType.character || FanWorkType.aiCharacter => const Color(0xFF3FAE6A),
    FanWorkType.worldbuilding => AppColors.gold,
    FanWorkType.other => const Color(0xFF8E95A8),
  };

  static IconData typeIcon(FanWorkType type) => switch (type) {
    FanWorkType.manga => Icons.menu_book_outlined,
    FanWorkType.drawing => Icons.brush_outlined,
    FanWorkType.story => Icons.edit_note_outlined,
    FanWorkType.character || FanWorkType.aiCharacter => Icons.theater_comedy_outlined,
    FanWorkType.worldbuilding => Icons.public_outlined,
    FanWorkType.other => Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final characterName = work.content.name.trim().isNotEmpty
        ? work.content.name
        : work.title;
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FanWorkLinks.open(context, work.id),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Cover(work: work),
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: typeColor(work.type),
                          child: Icon(
                            typeIcon(work.type),
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (work.isAiAssisted)
                        const PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: _AiBadge(),
                        ),
                      if (work.type == FanWorkType.manga &&
                          work.content.pages.isNotEmpty)
                        PositionedDirectional(
                          bottom: 8,
                          end: 8,
                          child: _MiniChip(
                            label: copy.pagesCount(work.content.pages.length),
                          ),
                        ),
                      if (work.type == FanWorkType.story)
                        PositionedDirectional(
                          bottom: 8,
                          end: 8,
                          child: _MiniChip(
                            label: copy.readMinutes(
                              ((work.content.body.length / 900).ceil()).clamp(
                                1,
                                40,
                              ),
                            ),
                          ),
                        ),
                      if (work.type == FanWorkType.character ||
                          work.type == FanWorkType.aiCharacter)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Color(0xCC140C22),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                characterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: work.creatorSnapshot.avatarUrl,
                    name: work.creatorSnapshot.username,
                    size: PubgetAvatarSize.small,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      work.creatorSnapshot.username.isEmpty
                          ? copy.pubgetUser
                          : work.creatorSnapshot.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              Text(
                work.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (work.type == FanWorkType.worldbuilding)
                Text(
                  copy.worldDepth(
                    work.content.characters.length,
                    work.content.locations.length,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              Row(
                children: <Widget>[
                  const Icon(Icons.favorite, size: 13, color: Color(0xFFFF8A9B)),
                  const SizedBox(width: 4),
                  Text('${work.likesCount}', style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeFanWorksSeeAllCard extends StatelessWidget {
  const HomeFanWorksSeeAllCard({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return SizedBox(
      width: 148,
      child: InkWell(
        key: const Key('home-fan-works-more'),
        onTap: () => AppNavigation.go(context, '/fan-works'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.arrow_forward_rounded, size: 28),
              const SizedBox(height: 8),
              Text(copy.seeAll, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.work});

  final FanWork work;

  @override
  Widget build(BuildContext context) {
    final path = work.cover?.path ?? '';
    if (path.isNotEmpty) {
      return AppImageLoader(imageUrl: path, fit: BoxFit.cover, memCacheWidth: 420);
    }
    if (work.type == FanWorkType.story) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[AppColors.royalPurple, AppColors.gold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              work.title,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }
    if (work.type == FanWorkType.worldbuilding) {
      return const ColoredBox(
        color: Color(0xFF1A1028),
        child: Center(
          child: Icon(Icons.public, color: AppColors.gold, size: 42),
        ),
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.insert_drive_file_outlined)),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC140C22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.goldSheen),
      ),
      child: const Text(
        '✦ AI',
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC140C22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

List<FanWork> diversifyFanWorks(List<FanWork> input, {int limit = 6}) {
  if (input.length <= limit) return input;
  final picked = <FanWork>[];
  final seen = <FanWorkType>{};
  for (final work in input) {
    if (picked.length == limit) break;
    if (seen.add(work.type) || seen.length >= 2) {
      picked.add(work);
    }
  }
  for (final work in input) {
    if (picked.length == limit) break;
    if (!picked.contains(work)) picked.add(work);
  }
  return picked;
}
