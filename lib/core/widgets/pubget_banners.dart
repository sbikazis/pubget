import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'pubget_buttons.dart';

class PubgetInlineBanner extends StatelessWidget {
  const PubgetInlineBanner({
    required this.title,
    required this.message,
    required this.icon,
    this.color,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? color;
  final VoidCallback? onRetry;
  final String retryLabel;

  factory PubgetInlineBanner.error({
    required String message,
    String title = 'Something went wrong',
    VoidCallback? onRetry,
  }) {
    return PubgetInlineBanner(
      title: title,
      message: message,
      icon: Icons.error_outline,
      onRetry: onRetry,
    );
  }

  factory PubgetInlineBanner.offline({
    String title = 'You are offline',
    String message = 'Reconnect to continue.',
    VoidCallback? onRetry,
  }) {
    return PubgetInlineBanner(
      title: title,
      message: message,
      icon: Icons.cloud_off_outlined,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone =
        color ??
        (icon == Icons.cloud_off_outlined
            ? theme.colorScheme.secondary
            : theme.colorScheme.error);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: tone, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: tone),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: theme.textTheme.bodySmall),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PubgetTextButton(
                        onPressed: onRetry,
                        semanticLabel: retryLabel,
                        child: Text(retryLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
