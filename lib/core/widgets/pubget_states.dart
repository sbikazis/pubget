import 'package:flutter/material.dart';

import '../loading/loading_state.dart';
import '../theme/app_spacing.dart';
import 'pubget_buttons.dart';
import 'pubget_skeleton.dart';

class PubgetEmptyState extends StatelessWidget {
  const PubgetEmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateLayout(
      icon: icon,
      title: title,
      message: message,
      action: action,
      compact: compact,
      iconColor: theme.colorScheme.primary,
    );
  }
}

class PubgetErrorState extends StatelessWidget {
  const PubgetErrorState({
    this.title = 'Something went wrong',
    this.message = 'Please try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: Icons.error_outline,
      title: title,
      message: message,
      iconColor: Theme.of(context).colorScheme.error,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: retryLabel,
              child: Text(retryLabel),
            ),
    );
  }
}

class PubgetOfflineState extends StatelessWidget {
  const PubgetOfflineState({
    this.title = 'You are offline',
    this.message = 'Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: Icons.cloud_off_outlined,
      title: title,
      message: message,
      iconColor: Theme.of(context).colorScheme.secondary,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: retryLabel,
              child: Text(retryLabel),
            ),
    );
  }
}

class PubgetLoadingStateView extends StatelessWidget {
  const PubgetLoadingStateView({
    required this.state,
    required this.child,
    this.skeleton,
    this.empty,
    this.error,
    this.offline,
    this.loadingMoreIndicator,
    this.onRetry,
    super.key,
  });

  final LoadingState state;
  final Widget child;
  final Widget? skeleton;
  final Widget? empty;
  final Widget? error;
  final Widget? offline;
  final Widget? loadingMoreIndicator;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      LoadingState.initial || LoadingState.loading =>
        skeleton ?? const PubgetSkeleton.card(width: double.infinity),
      LoadingState.empty =>
        empty ??
            PubgetEmptyState(
              title: 'Nothing here yet',
              message: 'New content will appear here when it is available.',
            ),
      LoadingState.error => error ?? PubgetErrorState(onRetry: onRetry),
      LoadingState.offline => offline ?? PubgetOfflineState(onRetry: onRetry),
      LoadingState.refreshing => Stack(
        children: <Widget>[
          child,
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
        ],
      ),
      LoadingState.loadingMore => Stack(
        children: <Widget>[
          child,
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: AppSpacing.sm,
            child:
                loadingMoreIndicator ??
                const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      LoadingState.loaded => child,
    };
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: compact ? 28 : 48, color: iconColor),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
            Text(
              title,
              style: compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
