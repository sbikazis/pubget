import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PubgetBadge extends StatelessWidget {
  const PubgetBadge({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final padding = compact
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 14 : 16,
                color: foregroundColor ?? scheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor ?? scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
