import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/widgets/pubget_states.dart';
import '../data/kirari_repository.dart';
import '../l10n/kirari_copy.dart';

/// Server-authoritative creator dashboard for published Kirari reels.
///
/// Every number comes from `getKirariCreatorAnalytics`; metrics the locked
/// spec asks for but the schema does not persist are disclosed, never faked.
class KirariAnalyticsPage extends StatefulWidget {
  const KirariAnalyticsPage({super.key});

  @override
  State<KirariAnalyticsPage> createState() => _KirariAnalyticsPageState();
}

class _KirariAnalyticsPageState extends State<KirariAnalyticsPage> {
  LoadingState _state = LoadingState.loading;
  KirariAnalytics? _data;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _state = _data == null ? LoadingState.loading : LoadingState.refreshing;
    });
    try {
      final data = await context.read<KirariRepository>().getCreatorAnalytics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _state = data.overview.reelCount == 0
            ? LoadingState.empty
            : LoadingState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = LoadingState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.analyticsTitle),
        actions: [
          IconButton(
            tooltip: copy.analyticsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: _state,
        onRetry: () => unawaited(_load()),
        retryLabel: copy.retry,
        empty: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(copy.analyticsNoData, textAlign: TextAlign.center),
          ),
        ),
        error: PubgetFailureStateView(
          title: copy.analyticsTitle,
          message: copy.analyticsLoadError,
          retryLabel: copy.retry,
          onRetry: _load,
        ),
        child: data == null
            ? const SizedBox.shrink()
            : _AnalyticsContent(data: data),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.data});

  final KirariAnalytics data;

  @override
  Widget build(BuildContext context) {
    final copy = KirariCopy.of(context);
    final overview = data.overview;
    final scope = data.scopeTruncated
        ? copy.analyticsScopeTruncated
        : '${copy.analyticsScope} · ${data.scopeReelCount}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(scope, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(
          copy.analyticsOverview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricCard(
              label: copy.analyticsViews,
              value: _compact(overview.views),
            ),
            _MetricCard(
              label: copy.analyticsQualifiedViews,
              value: _compact(overview.qualifiedViews),
            ),
            _MetricCard(
              label: copy.analyticsImpressions,
              value: _compact(overview.impressions),
            ),
            _MetricCard(
              label: copy.analyticsWatchTime,
              value: _seconds(overview.watchSeconds),
            ),
            _MetricCard(
              label: copy.analyticsAverageWatch,
              value: _seconds(overview.averageWatchSeconds),
            ),
            _MetricCard(
              label: copy.analyticsCompletionRate,
              value: _percent(overview.completionRate),
            ),
            _MetricCard(
              label: copy.analyticsReplayRate,
              value: _percent(overview.replayRate),
            ),
            _MetricCard(
              label: copy.analyticsEngagementRate,
              value: _percent(overview.engagementRate),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MetricList(
          title: copy.analyticsLikes,
          rows: [
            _RowValue(copy.analyticsLikes, overview.likes),
            _RowValue(copy.analyticsComments, overview.comments),
            _RowValue(copy.analyticsSaves, overview.saves),
            _RowValue(copy.analyticsShares, overview.shares),
            _RowValue(copy.analyticsEarlySkips, overview.earlySkips),
          ],
        ),
        const SizedBox(height: 16),
        _ReelList(
          title: copy.analyticsTopReels,
          reels: data.topReels,
          emptyCaption: copy.analyticsNoData,
          copy: copy,
        ),
        _ReelList(
          title: copy.analyticsTrending,
          reels: data.trending,
          emptyCaption: copy.analyticsNoData,
          copy: copy,
        ),
        _TagList(
          title: copy.analyticsTopHashtags,
          tags: data.topHashtags,
          copy: copy,
        ),
        _TagList(
          title: copy.analyticsTopAnime,
          tags: data.topAnime,
          copy: copy,
        ),
        _TagList(
          title: copy.analyticsTopCharacters,
          tags: data.topCharacters,
          copy: copy,
        ),
        _TagList(
          title: copy.analyticsTopAudio,
          tags: data.topAudio,
          copy: copy,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              copy.analyticsNotTracked,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  static String _compact(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.round().toString();
  }

  static String _seconds(num value) {
    if (value >= 60) return '${(value / 60).toStringAsFixed(1)}m';
    return '${value.toStringAsFixed(1)}s';
  }

  static String _percent(num value) => '${value.toStringAsFixed(1)}%';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowValue {
  const _RowValue(this.label, this.value);

  final String label;
  final int value;
}

class _MetricList extends StatelessWidget {
  const _MetricList({required this.title, required this.rows});

  final String title;
  final List<_RowValue> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: rows
                  .map(
                    (row) => Text(
                      '${row.label}: ${_AnalyticsContent._compact(row.value)}',
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelList extends StatelessWidget {
  const _ReelList({
    required this.title,
    required this.reels,
    required this.emptyCaption,
    required this.copy,
  });

  final String title;
  final List<KirariAnalyticsReel> reels;
  final String emptyCaption;
  final KirariCopy copy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (reels.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(emptyCaption),
            )
          else
            ...reels.map(
              (reel) => ListTile(
                title: Text(
                  reel.caption.isEmpty ? copy.analyticsReels : reel.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${copy.analyticsViews}: ${_AnalyticsContent._compact(reel.views)}'
                  ' · ${copy.analyticsCompletionRate}: '
                  '${_AnalyticsContent._percent(reel.completionRate)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  const _TagList({required this.title, required this.tags, required this.copy});

  final String title;
  final List<KirariAnalyticsTag> tags;
  final KirariCopy copy;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...tags.map(
            (tag) => ListTile(
              title: Text(tag.label),
              trailing: Text(
                '${tag.reels} ${copy.analyticsReels} · '
                '${_AnalyticsContent._compact(tag.views)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
