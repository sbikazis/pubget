import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'pubget_torii_mark.dart';

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    required this.title,
    required this.subtitle,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAtmosphere = AppColors.goldPale;
    final markSize = compact ? 64.0 : 84.0;
    return Column(
      children: <Widget>[
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.90, end: 1),
          duration: const Duration(milliseconds: 640),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: PubgetToriiMark(size: markSize),
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        Text(
          'PUBGET',
          style: theme.textTheme.titleSmall?.copyWith(
            letterSpacing: 7,
            fontWeight: FontWeight.w700,
            color: onAtmosphere,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Premium Anime Community',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            color: AppColors.goldSheen.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 42,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.goldSheen,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style:
              (compact
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(color: AppColors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.goldPale.withValues(alpha: 0.86),
          ),
        ),
      ],
    );
  }
}
