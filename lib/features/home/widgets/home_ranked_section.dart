import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';

/// Renders one of the ranked sections served by `getHomeSections`.
///
/// Design rules this section exists to enforce:
///
/// * A section with no real signal shows an honest empty state. It is never
///   padded with unrelated rows, and the title never claims a personal
///   recommendation the server did not make.
/// * Loading and failure are per-section, so one broken section cannot blank
///   the rest of Home.
/// * The server's `reason` is rendered as-is. When the server gives no reason,
///   no reason label is shown rather than inventing one.
class HomeRankedSection extends StatelessWidget {
  const HomeRankedSection({
    required this.kind,
    required this.title,
    this.seeMorePath,
    super.key,
  });

  final HomeSectionKind kind;
  final String title;

  /// Where "See more" goes. Null hides the action, which is what a section
  /// without a real listing page must do instead of linking somewhere unrelated.
  final String? seeMorePath;

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final copy = AppStrings.of(context);
    final state = home.section(kind);
    void onRetry() => home.retrySection(kind);

    Widget child;
    if (state.state == LoadingState.loading && !state.hasContent) {
      child = const _RankedSkeleton();
    } else if (state.state == LoadingState.error && !state.hasContent) {
      child = PubgetErrorState(
        title: copy.sectionFailed,
        message: _failureMessage(context, state),
        onRetry: onRetry,
      );
    } else if (state.items.isEmpty) {
      child = PubgetEmptyState(
        compact: true,
        title: copy.nothingHereYet,
        message: copy.newContentAppearsLater,
      );
    } else {
      child = _RankedStrip(items: state.items, seeMorePath: seeMorePath);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PubgetSectionHeader(title: title),
          // A refresh that failed keeps the rows the user can already act on, so
          // the section is marked stale instead of being replaced by an error.
          if (state.state == LoadingState.offline && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: PubgetStaleBanner(onRetry: onRetry),
            ),
          child,
        ],
      ),
    );
  }

  /// Failures are surfaced through the shared localised copy rather than the
  /// raw exception text, which is English-only.
  String _failureMessage(BuildContext context, HomeSectionState state) {
    final copy = AppStrings.of(context);
    return switch (state.failure) {
      NetworkError() => copy.discoveryOffline,
      PermissionError() => copy.discoverySignInRequired,
      _ => copy.discoveryUnavailable,
    };
  }
}

class _RankedStrip extends StatelessWidget {
  const _RankedStrip({required this.items, this.seeMorePath});

  final List<DiscoveryItem> items;
  final String? seeMorePath;

  @override
  Widget build(BuildContext context) {
    final count = items.length + (seeMorePath == null ? 0 : 1);
    return SizedBox(
      height: 150,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _SeeMoreCard(path: seeMorePath!);
          }
          return HomeRankedCard(item: HomeRankedItem.fromItem(items[index]));
        },
      ),
    );
  }
}

class HomeRankedCard extends StatelessWidget {
  const HomeRankedCard({required this.item, super.key});

  final HomeRankedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final copy = AppStrings.of(context);
    final reason = _reasonLabel(copy);
    final semantic = reason == null ? item.title : '${item.title}, $reason';

    return SizedBox(
      width: 210,
      child: Semantics(
        label: semantic,
        button: true,
        child: Material(
          color: scheme.surfaceContainer,
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _KindIcon(type: item.type),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Only a reason the server actually sent is shown, so the
                  // card never claims a recommendation it cannot justify.
                  if (reason != null)
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _reasonLabel(AppStrings copy) => switch (item.reason) {
    'this_week' => copy.reasonThisWeek,
    'community' => copy.reasonCommunity,
    'favourites' => copy.reasonFavourites,
    'rising' => copy.reasonRisingCreator,
    'social' => copy.reasonFriends,
    'recency' => copy.reasonFresh,
    _ => null,
  };

  void _open(BuildContext context) {
    final id = item.targetId;
    if (id == null || id.isEmpty) return;
    final path = switch (item.type) {
      'anime' => '/anime/details?animeId=$id',
      'character' => '/anime/character?characterId=$id',
      'creator' => '/profile?uid=$id',
      'groupJoin' => '/group?groupId=$id',
      'event' => '/event?eventId=$id',
      'edit' => '/reel?editId=$id',
      'fanWork' => '/fan-work?workId=$id',
      _ => null,
    };
    if (path != null) AppNavigation.go(context, path);
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(_iconFor(type), size: 18, color: scheme.onPrimaryContainer),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'anime' => Icons.movie_outlined,
    'character' => Icons.face_retouching_natural_outlined,
    'creator' => Icons.auto_awesome_outlined,
    'groupJoin' => Icons.groups_outlined,
    'event' => Icons.celebration_outlined,
    'edit' => Icons.movie_filter_outlined,
    'fanWork' => Icons.brush_outlined,
    _ => Icons.auto_awesome_outlined,
  };
}

class _SeeMoreCard extends StatelessWidget {
  const _SeeMoreCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Semantics(
        button: true,
        label: copy.seeMore,
        child: Material(
          color: scheme.primaryContainer,
          child: InkWell(
            onTap: () => AppNavigation.go(context, path),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: scheme.primaryContainer,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.arrow_forward, color: scheme.onPrimaryContainer),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      copy.seeMore,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankedSkeleton extends StatelessWidget {
  const _RankedSkeleton();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (_, _) =>
          const SizedBox(width: 210, child: PubgetSkeleton.card(height: 150)),
    ),
  );
}
