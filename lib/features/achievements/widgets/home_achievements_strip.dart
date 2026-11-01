import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/achievement_copy.dart';
import '../models/achievement_models.dart';
import '../providers/achievement_provider.dart';
import 'achievement_badge_widget.dart';

/// Progress strip for Master Spec §5.3 ("إنجازات / تقدم").
///
/// Shows the achievements closest to completion so the user can see the next
/// milestone, which is the point of the section. It never invents progress: the
/// numbers come straight from the achievement catalogue the server sends.
class HomeAchievementsStrip extends StatelessWidget {
  const HomeAchievementsStrip({required this.onSeeAll, super.key});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthProvider, String?>(
      (auth) => auth.currentUser?.id,
    );
    if (uid == null) return const SizedBox.shrink();
    final provider = context.watch<AchievementProvider>();
    final copy = AchievementCopy.of(context);

    if (provider.state == LoadingState.loading && provider.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: PubgetSkeleton.card(height: 108),
      );
    }
    if (provider.state == LoadingState.error && provider.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: PubgetEmptyState(
          compact: true,
          title: copy.unlockedEmptyTitle,
          message: copy.unlockedEmptyBody,
          action: PubgetTextButton(
            onPressed: () => provider.open(provider.userId ?? uid),
            semanticLabel: copy.retry,
            child: Text(copy.retry),
          ),
        ),
      );
    }

    final upcoming = _nearestMilestones(provider);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == upcoming.length) {
                  return _SeeAllTile(
                    label: copy.myAchievements,
                    onTap: onSeeAll,
                  );
                }
                return _AchievementProgressTile(item: upcoming[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The achievements the user is closest to finishing, so the strip always
  /// shows an actionable next step rather than a wall of locked rows.
  List<AchievementItem> _nearestMilestones(AchievementProvider provider) {
    final locked = provider.items
        .where((item) => !item.unlocked && item.targetValue > 0)
        .toList();
    locked.sort((a, b) => b.progressRatio.compareTo(a.progressRatio));
    final next = locked.take(6).toList();
    // A recently unlocked achievement outranks a locked one at 5%.
    final latest = provider.unlocked.take(2).toList();
    return <AchievementItem>[...latest, ...next];
  }
}

class _AchievementProgressTile extends StatelessWidget {
  const _AchievementProgressTile({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    final copy = AchievementCopy.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progressRatio.clamp(0.0, 1.0);
    final unlocked = item.unlocked == true;
    return SizedBox(
      width: 190,
      child: Semantics(
        label: <String>[
          copy.isArabic ? item.definition.nameAr : item.definition.nameEn,
          copy.isArabic
              ? item.definition.descriptionAr
              : item.definition.descriptionEn,
          unlocked ? copy.unlockedOn : '${(progress * 100).round()}%',
        ].join(', '),
        child: Material(
          color: scheme.surfaceContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AchievementBadgeWidget(item: item, size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          copy.isArabic
                              ? item.definition.nameAr
                              : item.definition.nameEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    copy.isArabic
                        ? item.definition.descriptionAr
                        : item.definition.descriptionEn,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${(progress * 100).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: unlocked
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Semantics(
        button: true,
        label: AppStrings.of(context).seeMore,
        child: Material(
          color: scheme.primaryContainer,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: scheme.primaryContainer,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.military_tech_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
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
