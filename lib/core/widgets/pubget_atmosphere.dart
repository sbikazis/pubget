import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Subtle interior atmosphere. Auth keeps its own richer treatment.
class PubgetAtmosphere extends StatelessWidget {
  const PubgetAtmosphere({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const <Color>[
                  AppColors.royalNight,
                  AppColors.darkBackground,
                  AppColors.royalEmber,
                ]
              : const <Color>[
                  AppColors.royalPurplePale,
                  AppColors.lightBackground,
                  AppColors.lightSurfaceMuted,
                ],
        ),
      ),
      child: child,
    );
  }
}

class PubgetSectionHeader extends StatelessWidget {
  const PubgetSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
