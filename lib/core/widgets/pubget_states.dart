import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../errors/failure.dart';
import '../l10n/app_strings.dart';
import '../loading/loading_state.dart';
import '../network/network_service.dart';
import '../theme/app_spacing.dart';
import 'pubget_buttons.dart';
import 'pubget_skeleton.dart';

// ────────────────────────────────────────────────────────────────────────────
// Axis 02 §2.1 / §2.2 — one honest verdict for every screen.
//
// Axis Zero built a truthful NetworkService but only one screen consumed it.
// The rest of the app still rendered "check your internet" for backend
// outages. The classifier below is the single place that decides what a
// failure actually means; every state surface routes through it.
// ────────────────────────────────────────────────────────────────────────────

/// The five verdicts a failed screen may legitimately present.
enum PubgetFailureKind {
  offline,
  serviceUnavailable,
  permissionDenied,
  expired,
  generic,
}

/// Pure, unit-testable classification. [linkStatus] is null when no
/// [NetworkService] is in the tree (isolated widgets and most widget tests):
/// in that case we preserve the legacy verdict rather than inventing one.
///
/// [offlineHint] is set by `LoadingState.offline`, where some providers expose
/// no [Failure] object at all. A stale offline flag while the platform reports
/// a healthy link must be presented as "service unavailable", never as
/// "no internet".
PubgetFailureKind classifyPubgetFailure(
  Failure? failure, {
  NetworkStatus? linkStatus,
  bool offlineHint = false,
}) {
  if (failure is PermissionError) {
    return PubgetFailureKind.permissionDenied;
  }
  if (failure is NotFoundError) return PubgetFailureKind.expired;
  if (failure is UnavailableError ||
      failure is TimeoutError ||
      failure is RateLimitedError) {
    return PubgetFailureKind.serviceUnavailable;
  }
  if (failure is NetworkError) {
    // A broken transport is only "no internet" when the platform agrees.
    // If the link is up, this is the service failing — not the user's Wi-Fi.
    return linkStatus == NetworkStatus.online
        ? PubgetFailureKind.serviceUnavailable
        : PubgetFailureKind.offline;
  }
  if (failure == null && offlineHint) {
    return linkStatus == null || linkStatus == NetworkStatus.offline
        ? PubgetFailureKind.offline
        : PubgetFailureKind.serviceUnavailable;
  }
  return PubgetFailureKind.generic;
}

/// Reads the live link verdict when one is available. Widget trees that do not
/// provide [NetworkService] (widget tests, the design-system showcase) get
/// `null` instead of a `ProviderNotFoundException`.
NetworkStatus? readNetworkStatus(BuildContext context) {
  try {
    return context.select<NetworkService, NetworkStatus>(
      (network) => network.status,
    );
  } on ProviderNotFoundException {
    return null;
  }
}

NetworkService? readNetworkService(BuildContext context) {
  try {
    return context.read<NetworkService>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// A static, animation-free page skeleton. An indeterminate progress
/// indicator schedules a frame forever and makes `pumpAndSettle` in widget
/// tests diverge; these bars are real layout placeholders with no controller.
class PubgetPageLoading extends StatelessWidget {
  const PubgetPageLoading({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = AppStrings.of(context);
    return Semantics(
      label: copy.loadingContentLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _bar(scheme, width: compact ? 120 : 190, height: 18),
              const SizedBox(height: AppSpacing.sm),
              _bar(scheme, width: compact ? 160 : 240, height: compact ? 60 : 110),
              const SizedBox(height: AppSpacing.sm),
              _bar(scheme, width: compact ? 90 : 140, height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(ColorScheme scheme, {required double width, required double height}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

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
    this.failure,
    super.key,
  });

  /// All copy resolves from [AppStrings] so an Arabic screen never renders an
  /// English default (spec §1.4). Callers may still override any field.
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  /// When a screen knows the typed [Failure], the error surface escalates to
  /// the honest verdict instead of flattening everything into "try again".
  /// Raw `failure.message` must never be passed as [message].
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final retry = retryLabel ?? copy.tryAgain;
    final typed = failure;
    if (typed != null) {
      final kind = classifyPubgetFailure(
        typed,
        linkStatus: readNetworkStatus(context),
      );
      switch (kind) {
        case PubgetFailureKind.permissionDenied:
          return PubgetPermissionDeniedState(
            title: title,
            message: message,
            onRetry: onRetry,
          );
        case PubgetFailureKind.expired:
          return PubgetExpiredState(
            title: title,
            message: message,
            onRetry: onRetry,
          );
        case PubgetFailureKind.serviceUnavailable:
          return PubgetServiceUnavailableState(
            title: title,
            message: message,
            onRetry: onRetry,
          );
        case PubgetFailureKind.offline:
          return PubgetOfflineState(
            forceOffline: true,
            title: title,
            message: message,
            onRetry: onRetry,
            retryLabel: retryLabel,
          );
        case PubgetFailureKind.generic:
          break;
      }
    }
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
    this.failure,
    this.forceOffline = false,
    super.key,
  });

  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final Failure? failure;

  /// Set by the resolver (and by the design-system showcase) once the offline
  /// verdict has already been proven. It prevents a delegation loop.
  final bool forceOffline;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final retry = retryLabel ?? copy.retry;

    // Axis 02: ~40 legacy call sites construct this widget unconditionally
    // whenever a provider flips to `LoadingState.offline`. That flag is not
    // evidence that the device lost its link — Firebase can be unreachable
    // while Wi-Fi is fine. Heal those call sites at the source instead of
    // chasing them one screen at a time.
    if (!forceOffline) {
      final status = readNetworkStatus(context);
      if (status == NetworkStatus.online || status == NetworkStatus.unknown) {
        return PubgetServiceUnavailableState(onRetry: onRetry);
      }
      if (failure != null) {
        final kind = classifyPubgetFailure(failure, linkStatus: status);
        if (kind == PubgetFailureKind.permissionDenied) {
          return PubgetPermissionDeniedState(onRetry: onRetry);
        }
        if (kind == PubgetFailureKind.expired) {
          return PubgetExpiredState(onRetry: onRetry);
        }
        if (kind == PubgetFailureKind.serviceUnavailable) {
          return PubgetServiceUnavailableState(onRetry: onRetry);
        }
      }
    }
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

/// Axis Zero / Axis 02: the third verdict. A backend outage is not a missing
/// connection, and saying "check your internet" for it destroys trust.
class PubgetServiceUnavailableState extends StatelessWidget {
  const PubgetServiceUnavailableState({
    this.onRetry,
    this.loading = false,
    this.title,
    this.message,
    super.key,
  });

  final VoidCallback? onRetry;
  final bool loading;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return _StateLayout(
      icon: Icons.cloud_sync_outlined,
      title: title ?? copy.serviceUnavailableTitle,
      message: message ?? copy.serviceUnavailableMessage,
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

/// Spec §2.1 — "Permission Denied" is its own verdict, not a generic error.
class PubgetPermissionDeniedState extends StatelessWidget {
  const PubgetPermissionDeniedState({
    this.onRetry,
    this.title,
    this.message,
    super.key,
  });

  final VoidCallback? onRetry;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return _StateLayout(
      icon: Icons.lock_outline,
      title: title ?? copy.permissionDeniedTitle,
      message: message ?? copy.permissionDeniedMessage,
      iconColor: Theme.of(context).colorScheme.error,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: copy.tryAgain,
              child: Text(copy.tryAgain),
            ),
    );
  }
}

/// Spec §2.1 — "Expired" (deleted content, stale link) is its own verdict.
class PubgetExpiredState extends StatelessWidget {
  const PubgetExpiredState({
    this.onRetry,
    this.title,
    this.message,
    super.key,
  });

  final VoidCallback? onRetry;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return _StateLayout(
      icon: Icons.history_toggle_off,
      title: title ?? copy.expiredTitle,
      message: message ?? copy.expiredMessage,
      iconColor: Theme.of(context).colorScheme.tertiary,
      action: onRetry == null
          ? null
          : PubgetSecondaryButton(
              onPressed: onRetry,
              semanticLabel: copy.tryAgain,
              child: Text(copy.tryAgain),
            ),
    );
  }
}

/// The single honest surface for every failed screen.
///
/// It classifies the typed [Failure] against the live link verdict, then
/// renders exactly one of the five states above. Retry is real: it re-verifies
/// the link through [NetworkService] (when one is in the tree) and only then
/// re-runs the failed action. A double tap cannot start two retries, so a
/// reconnected user cannot accidentally duplicate a write (§2.2).
class PubgetFailureStateView extends StatefulWidget {
  const PubgetFailureStateView({
    this.failure,
    this.offlineHint = false,
    this.title,
    this.message,
    this.onRetry,
    super.key,
  });

  final Failure? failure;

  /// Set by `LoadingState.offline`, where the provider exposes no [Failure].
  final bool offlineHint;

  /// Localized, domain-specific copy overrides. Never pass a raw backend
  /// message here — that is the contract of the whole error taxonomy.
  final String? title;
  final String? message;
  final Future<void> Function()? onRetry;

  @override
  State<PubgetFailureStateView> createState() =>
      _PubgetFailureStateViewState();
}

class _PubgetFailureStateViewState extends State<PubgetFailureStateView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying || widget.onRetry == null) return;
    setState(() => _retrying = true);
    try {
      final service = readNetworkService(context);
      if (service != null) {
        // Refreshing first means a user who just reconnected is not told
        // "no internet" a second time by a stale offline verdict.
        await service.refresh();
      }
      await widget.onRetry!();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  VoidCallback? get _retryCallback {
    if (widget.onRetry == null) return null;
    return () {
      unawaited(_retry());
    };
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final kind = classifyPubgetFailure(
      widget.failure,
      linkStatus: readNetworkStatus(context),
      offlineHint: widget.offlineHint,
    );
    final retry = _retryCallback;
    return switch (kind) {
      // The two connectivity verdicts own their copy unconditionally. A domain
      // override like "check your connection" must never be able to turn a
      // backend outage back into a false "no internet" claim.
      PubgetFailureKind.offline => PubgetOfflineState(
        forceOffline: true,
        title: copy.connectionOfflineTitle,
        message: copy.connectionOfflineMessage,
        onRetry: retry,
        retryLabel: copy.retryConnection,
      ),
      PubgetFailureKind.serviceUnavailable =>
        PubgetServiceUnavailableState(
          onRetry: retry,
          loading: _retrying,
        ),
      PubgetFailureKind.permissionDenied => PubgetPermissionDeniedState(
        title: widget.title,
        message: widget.message,
        onRetry: retry,
      ),
      PubgetFailureKind.expired => PubgetExpiredState(
        title: widget.title,
        message: widget.message,
        onRetry: retry,
      ),
      PubgetFailureKind.generic => PubgetErrorState(
        title: widget.title,
        message: widget.message,
        onRetry: retry,
        retryLabel: copy.retryConnection,
      ),
    };
  }
}

/// Backwards-compatible entry point used by the Edits feed. All verdict logic
/// now lives in [PubgetFailureStateView]; this only translates the old boolean
/// into a typed failure.
class PubgetConnectionStateView extends StatelessWidget {
  const PubgetConnectionStateView({
    required this.onRetry,
    this.isServiceFailure = false,
    super.key,
  });

  final Future<void> Function() onRetry;
  final bool isServiceFailure;

  @override
  Widget build(BuildContext context) {
    return PubgetFailureStateView(
      failure: isServiceFailure
          ? const UnavailableError()
          : const NetworkError(),
      onRetry: onRetry,
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
    this.failure,
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

  /// The typed failure behind `error`/`offline`. Passing it upgrades the
  /// default surfaces from a flat message to the honest verdict (§2.1).
  final Failure? failure;

  Future<void> Function()? get _retryAction {
    final callback = onRetry;
    if (callback == null) return null;
    return () async {
      callback();
    };
  }

  @override
  Widget build(BuildContext context) {
    final retry = _retryAction;
    return switch (state) {
      LoadingState.initial || LoadingState.loading =>
        skeleton ?? const PubgetSkeleton.card(width: double.infinity),
      LoadingState.empty =>
        empty ??
            PubgetEmptyState(
              title: AppStrings.of(context).nothingHereYet,
              message: AppStrings.of(context).newContentAppearsLater,
            ),
      LoadingState.error =>
        error ??
            PubgetFailureStateView(failure: failure, onRetry: retry),
      LoadingState.offline =>
        offline ??
            PubgetFailureStateView(
              failure: failure,
              offlineHint: true,
              onRetry: retry,
            ),
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
