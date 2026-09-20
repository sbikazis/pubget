import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

/// Creator Analytics dashboard. Every number is computed server-side from
/// published Reels' real counters — no placeholder or fabricated metrics.
final class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  CreatorAnalytics? _analytics;
  LoadingState _state = LoadingState.loading;
  AnalyticsRepository? _repository;

  @override
  void initState() {
    super.initState();
    _repository = _analyticsRepository(context);
    _load();
  }

  AnalyticsRepository? _analyticsRepository(BuildContext context) {
    try {
      final repository = Provider.of<EditsRepository>(context, listen: false);
      if (repository is AnalyticsRepository) {
        return repository as AnalyticsRepository;
      }
      return null;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() {
        _analytics = null;
        _state = LoadingState.error;
      });
      return;
    }
    setState(() => _state = LoadingState.loading);
    final result = await repository.getCreatorAnalytics(days: 30);
    if (!mounted) return;
    setState(() {
      result.fold(
        onSuccess: (analytics) {
          _analytics = analytics;
          _state = analytics.totals.reels == 0
              ? LoadingState.empty
              : LoadingState.loaded;
        },
        onFailure: (_) {
          _analytics = null;
          _state = LoadingState.error;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return PubgetPageScaffold(
      title: Text(copy.analyticsTitle),
      actions: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Text(
              copy.analyticsDays,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
      body: switch (_state) {
        LoadingState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        LoadingState.error => _ErrorRetry(onRetry: _load),
        LoadingState.empty => const _EmptyAnalytics(),
        _ => _Dashboard(analytics: _analytics!),
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.analytics});

  final CreatorAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final totals = analytics.totals;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(
          copy.analyticsOverview,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            _Stat(label: copy.analyticsViews, value: totals.views),
            _Stat(
              label: copy.analyticsUniqueViewers,
              value: totals.uniqueViewers,
            ),
            _Stat(
              label: copy.analyticsCompletionRate,
              value: totals.completionRate,
              suffix: '%',
            ),
            _Stat(
              label: copy.analyticsWatchTime,
              value: (totals.watchSeconds / 3600).toStringAsFixed(1),
              suffix: ' h',
            ),
            _Stat(label: copy.analyticsLikes, value: totals.likes),
            _Stat(label: copy.analyticsComments, value: totals.comments),
            _Stat(label: copy.analyticsShares, value: totals.shares),
            _Stat(label: copy.analyticsSaves, value: totals.saves),
            _Stat(label: copy.analyticsRespect, value: totals.respectReceived),
            _Stat(
              label: copy.analyticsAvgWatch,
              value: totals.avgWatchSeconds,
              suffix: 's',
            ),
            _Stat(label: copy.analyticsFans, value: analytics.fans),
            _Stat(label: copy.analyticsImpressions, value: totals.impressions),
          ],
        ),
        if (analytics.reels.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsBestReels,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              children: analytics.reels
                  .map((reel) => _ReelRow(reel: reel))
                  .toList(growable: false),
            ),
          ),
        ],
        if (analytics.growth.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsGrowth,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(child: _GrowthChart(points: analytics.growth)),
        ],
        if (analytics.topAnime.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsTopAnime,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GroupList(groups: analytics.topAnime),
        ],
        if (analytics.topCharacters.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsTopCharacters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GroupList(groups: analytics.topCharacters),
        ],
        if (analytics.topHashtags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsTopHashtags,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GroupList(groups: analytics.topHashtags),
        ],
        if (analytics.topAudio.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.analyticsTopAudio,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GroupList(groups: analytics.topAudio),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.suffix = ''});

  final String label;
  final dynamic value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$value$suffix',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReelRow extends StatelessWidget {
  const _ReelRow({required this.reel});

  final AnalyticsReel reel;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return InkWell(
      onTap: () => AppNavigation.go(context, '/edits?highlight='),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reel.caption.isEmpty ? reel.id : reel.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reel.animeTag.isNotEmpty)
                    Text(
                      reel.animeTag,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            _MetricList(
              items: <Widget>[
                Text('${reel.viewsCount} ${copy.analyticsViews.toLowerCase()}'),
                Text(
                  '${reel.uniqueViewers} ${copy.analyticsUniqueViewers.toLowerCase()}',
                ),
                Text('${reel.likesCount} ${copy.analyticsLikes.toLowerCase()}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricList extends StatelessWidget {
  const _MetricList({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: items);
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.points});

  final List<AnalyticsGrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxViews = points.fold<int>(
      0,
      (max, p) => p.views > max ? p.views : max,
    );
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map((point) {
              final factor = maxViews == 0
                  ? 0.06
                  : 0.06 + (point.views / maxViews) * 0.9;
              final showLabel = points.length <= 12;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: factor,
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.royalPurple,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                        ),
                      ),
                      if (showLabel)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            point.day.substring(8),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups});

  final List<AnalyticsGroup> groups;

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return PubgetCard(
      child: Column(
        children: groups
            .map((group) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        group.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${group.views} ${copy.analyticsViews.toLowerCase()}'),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              PhosphorIconsRegular.chartBar,
              size: 48,
              color: AppColors.royalPurpleLight,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(copy.analyticsNoData, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}
