import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({this.label = 'or', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Expanded(
      child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.28)),
    );
    return Row(
      children: <Widget>[
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        line,
      ],
    );
  }
}
