import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/achievement_models.dart';
import 'achievement_badge_widget.dart';

/// Full-screen unlock celebration (1–2s). Shown once per unlock id.
abstract final class AchievementCelebration {
  static Future<void> show(
    BuildContext context, {
    required AchievementItem item,
    required bool arabic,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'achievement-celebration',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, anim, secondary) {
        return _CelebrationBody(item: item, arabic: arabic, anim: anim);
      },
    );
  }
}

class _CelebrationBody extends StatefulWidget {
  const _CelebrationBody({
    required this.item,
    required this.arabic,
    required this.anim,
  });

  final AchievementItem item;
  final bool arabic;
  final Animation<double> anim;

  @override
  State<_CelebrationBody> createState() => _CelebrationBodyState();
}

class _CelebrationBodyState extends State<_CelebrationBody> {
  @override
  void initState() {
    super.initState();
    final rarity = widget.item.rarity;
    final ms = switch (rarity) {
      AchievementRarity.common => 1100,
      AchievementRarity.uncommon || AchievementRarity.rare => 1500,
      AchievementRarity.epic => 1700,
      AchievementRarity.legendary || AchievementRarity.mythic => 2000,
    };
    Future<void>.delayed(Duration(milliseconds: ms), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: widget.anim, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(parent: widget.anim, curve: Curves.easeOut);
    final sparkle = widget.item.rarity.index >= AchievementRarity.epic.index;
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.royalPurple.withValues(alpha: 0.95),
                        const Color(0xFF12081F),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                    boxShadow: sparkle
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 28,
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.arabic ? 'إنجاز جديد!' : 'Achievement unlocked!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AchievementBadgeWidget(
                          item: widget.item,
                          size: 148,
                          animate: true,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          widget.item.definition.name(widget.arabic),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.item.definition.name(!widget.arabic),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.item.definition.meaning(widget.arabic),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RarityChip(rarity: widget.item.rarity),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});
  final AchievementRarity rarity;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (rarity) {
      AchievementRarity.common => ('Common', Colors.blueGrey),
      AchievementRarity.uncommon => ('Uncommon', Colors.teal),
      AchievementRarity.rare => ('Rare', Colors.indigo),
      AchievementRarity.epic => ('Epic', Colors.deepPurple),
      AchievementRarity.legendary => ('Legendary', Colors.amber.shade800),
      AchievementRarity.mythic => ('Mythic', const Color(0xFFE040FB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
