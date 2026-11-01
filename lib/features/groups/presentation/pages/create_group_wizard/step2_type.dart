import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step2Type extends StatelessWidget {
  const Step2Type({
    required this.onSelected,
    required this.currentType,
    this.animeTitle,
    this.characterName,
    this.onPickAnime,
    this.onPickCharacter,
    super.key,
  });

  final ValueChanged<GroupType> onSelected;
  final GroupType? currentType;
  final String? animeTitle;
  final String? characterName;
  final VoidCallback? onPickAnime;
  final VoidCallback? onPickCharacter;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.chooseType,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.typeSelectionHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final type in GroupType.values) ...<Widget>[
            _TypeTile(
              type: type,
              selected: currentType == type,
              onTap: () => onSelected(type),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (currentType == GroupType.animeRoleplay) ...<Widget>[
            PubgetSecondaryButton(
              key: const Key('group-create-pick-anime'),
              onPressed: onPickAnime,
              semanticLabel: copy.selectAnime,
              child: Text(animeTitle ?? copy.selectAnime),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (currentType == GroupType.openRoleplay ||
              (currentType == GroupType.animeRoleplay &&
                  animeTitle != null)) ...<Widget>[
            PubgetSecondaryButton(
              key: const Key('group-create-pick-character'),
              onPressed: onPickCharacter,
              semanticLabel: copy.selectCharacter,
              child: Text(characterName ?? copy.selectCharacter),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final GroupType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A0F2E) : const Color(0xFFF5F0FA);
    final borderColor = selected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            color: surfaceColor,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: selected
                        ? [AppColors.gold, AppColors.goldDark]
                        : [
                            AppColors.royalPurple.withValues(alpha: 0.5),
                            AppColors.royalPurple.withValues(alpha: 0.2),
                          ],
                  ),
                ),
                child: Icon(
                  _icon(type),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.typeLabel(type),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected ? AppColors.gold : Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.typeHint(type),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.gold,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(GroupType type) => switch (type) {
        GroupType.public => Icons.public_outlined,
        GroupType.animeRoleplay => Icons.theater_comedy_outlined,
        GroupType.openRoleplay => Icons.auto_awesome_outlined,
      };
}