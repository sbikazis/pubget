import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

class PubgetCard extends StatelessWidget {
  const PubgetCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.elevation = 1,
    this.color,
    this.borderRadius,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double elevation;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final shadows = highlighted
        ? AppShadows.goldGlow(theme.brightness)
        : theme.brightness == Brightness.dark
        ? AppShadows.darkCard
        : AppShadows.lightCard;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: radius,
        boxShadow: elevation > 0 ? shadows : null,
        border: Border.all(
          color: highlighted
              ? AppColors.gold.withValues(alpha: 0.55)
              : theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
