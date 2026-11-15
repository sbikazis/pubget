import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../loading/loading_state.dart';
import '../network/network_service.dart';
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
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  /// All copy resolves from [AppStrings] so an Arabic screen never renders an
  /// English default (spec §1.4). Callers may still override any field.
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final retry = retryLabel ?? copy.tryAgain;
    return _StateLayout(
      icon: Icons.error_outline,
      title: title ?? copy.couldNotLoad,
      message: message ?? copy.tryAgainShort,
      iconColor: Theme.of(context).colorScheme.error,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: retry,
              child: Text(retry),
            ),
    );
  }
}

class PubgetOfflineState extends StatelessWidget {
  const PubgetOfflineState({
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final retry = retryLabel ?? copy.retry;
    return _StateLayout(
      icon: Icons.cloud_off_outlined,
      title: title ?? copy.offlineShowingSaved,
      message: message ?? copy.discoveryOffline,
      iconColor: Theme.of(context).colorScheme.secondary,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: retry,
              child: Text(retry),
            ),
    );
  }
}

/// Axis Zero: the third verdict. A backend outage is not a missing
/// connection, and saying "check your internet" for it destroys trust.
class PubgetServiceUnavailableState extends StatelessWidget {
  const PubgetServiceUnavailableState({
    this.onRetry,
    this.loading = false,
    super.key,
  });

  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return _StateLayout(
      icon: Icons.cloud_sync_outlined,
      title: copy.serviceUnavailableTitle,
      message: copy.serviceUnavailableMessage,
      iconColor: Theme.of(context).colorScheme.tertiary,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: loading ? null : onRetry,
              loading: loading,
              semanticLabel: copy.retryConnection,
              child: Text(copy.retryConnection),
            ),
    );
  }
}

/// One honest surface for all three connectivity verdicts, with a retry that
/// actually does something: it re-verifies the link through [NetworkService]
/// *and* re-runs the failed action. A button that only changes a label is not
/// a retry.
class PubgetConnectionStateView extends StatefulWidget {
  const PubgetConnectionStateView({
    required this.onRetry,
    this.isServiceFailure = false,
    super.key,
  });

  /// Re-runs the failed operation after the link has been re-verified.
  final Future<void> Function() onRetry;

  /// True when the failure came from the backend (`UnavailableError`,
  /// `TimeoutError`) rather than from the platform reporting no link.
  final bool isServiceFailure;

  @override
  State<PubgetConnectionStateView> createState() =>
      _PubgetConnectionStateViewState();
}

class _PubgetConnectionStateViewState
    extends State<PubgetConnectionStateView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      // Refreshing first means a user who just reconnected is not told
      // "no internet" a second time by a stale offline verdict.
      await context.read<NetworkService>().refresh();
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final status = context.select<NetworkService, NetworkStatus>(
      (network) => network.status,
    );

    if (status == NetworkStatus.offline && !widget.isServiceFailure) {
      return PubgetOfflineState(
        title: copy.connectionOfflineTitle,
        message: copy.connectionOfflineMessage,
        onRetry: _retry,
        retryLabel: copy.retryConnection,
      );
    }

    if (widget.isServiceFailure || status == NetworkStatus.unknown) {
      return PubgetServiceUnavailableState(
        onRetry: _retry,
        loading: _retrying,
      );
    }

    // Online and the operation still failed: a generic, retryable error.
    return PubgetErrorState(
      onRetry: _retry,
      retryLabel: copy.retryConnection,
    );
  }
}

/// Inline banner for content that is cached and still readable while the ranked
/// signal cannot be refreshed. Home uses this instead of replacing a whole
/// section with an error, which would hide real content the user can act on.
class PubgetStaleBanner extends StatelessWidget {
  const PubgetStaleBanner({
    this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    super.key,
  });

  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: message ?? copy.offlineShowingSaved,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message ?? copy.offlineShowingSaved,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: scheme.primary,
                ),
                child: Text(copy.retry),
              ),
            ],
          ],
        ),
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
              title: AppStrings.of(context).nothingHereYet,
              message: AppStrings.of(context).newContentAppearsLater,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.md : AppSpacing.xxl,
                ),
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
                      SizedBox(
                        height: compact ? AppSpacing.sm : AppSpacing.xl,
                      ),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
