import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../providers/fan_work_providers.dart';
import '../repositories/fan_work_repository.dart';
import '../widgets/fan_work_widgets.dart';

/// Full list of one creator's published Fan Works, opened from the profile.
class ProfileFanWorksPage extends StatefulWidget {
  const ProfileFanWorksPage({this.userId, super.key});

  final String? userId;

  @override
  State<ProfileFanWorksPage> createState() => _ProfileFanWorksPageState();
}

class _ProfileFanWorksPageState extends State<ProfileFanWorksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scroll = ScrollController();
  final _items = <FanWork>[];
  FanWork? _cursor;
  var _hasMore = true;
  var _loading = false;
  var _loaded = false;
  String? _failure;
  FanWorkAnalyticsProvider? _analyticsProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scroll.addListener(_maybeLoadMore);
    final repository = context.read<FanWorkRepository>();
    final uid = widget.userId ?? '';
    Future<void>.microtask(() {
      _loadMore();
      if (uid.isNotEmpty) {
        _analyticsProvider = FanWorkAnalyticsProvider(repository: repository);
        _analyticsProvider!.load(uid);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _tabController.dispose();
    _analyticsProvider?.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _failure != null) return;
    final uid = widget.userId ?? '';
    if (uid.isEmpty) return;
    FanWorkRepository repository;
    try {
      repository = context.read<FanWorkRepository>();
    } on ProviderNotFoundException {
      setState(() {
        _loaded = true;
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    final result = await repository.getCreatorWorks(
      creatorId: uid,
      after: _cursor,
      limit: 12,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loaded = true;
      final failure = result.failureOrNull;
      if (failure != null) {
        _failure = failure.message;
        return;
      }
      final page = result.valueOrNull;
      if (page != null) {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      }
    });
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) unawaited(_loadMore());
  }

  void _retry() {
    setState(() {
      _failure = null;
      _loaded = false;
    });
    unawaited(_loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == widget.userId;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(FanWorkStrings.feedTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Works'),
            if (isOwner) const Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SafeArea(
            child: Builder(
              builder: (context) {
                if (_failure != null) {
                  return PubgetErrorState(
                    message: 'Could not load fan works.',
                    onRetry: _retry,
                  );
                }
                if (!_loaded && _items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_loaded && _items.isEmpty) {
                  return PubgetEmptyState(
                    icon: Icons.brush_outlined,
                    title: isOwner ? 'No fan works yet' : 'No fan works to show',
                    message: isOwner
                        ? 'Share a drawing, manga page, or story.'
                        : 'This creator has not shared works yet.',
                  );
                }
                return GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return FanWorkPreviewCard(work: _items[index]);
                  },
                );
              },
            ),
          ),
          if (isOwner && _analyticsProvider != null)
            _FanWorkAnalyticsDashboard(provider: _analyticsProvider!)
          else if (isOwner)
            const Center(child: CircularProgressIndicator())
          else
            const Center(child: Text('Analytics available for your own works')),
        ],
      ),
    );
  }
}

class _FanWorkAnalyticsDashboard extends StatelessWidget {
  const _FanWorkAnalyticsDashboard({required this.provider});

  final FanWorkAnalyticsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Consumer<FanWorkAnalyticsProvider>(
      builder: (context, provider, _) {
        if (provider.state == LoadingState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.state == LoadingState.error) {
          return PubgetErrorState(
            message: provider.failure?.message ?? 'Could not load analytics.',
            onRetry: () => provider.load(provider.creatorId ?? ''),
          );
        }
        if (provider.state == LoadingState.offline) {
          return PubgetOfflineState(onRetry: () => provider.load(provider.creatorId ?? ''));
        }
        final analytics = provider.analytics;
        if (analytics == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StatsGrid(analytics: analytics),
              const SizedBox(height: AppSpacing.lg),
              _WorksByTypeChart(analytics: analytics),
              const SizedBox(height: AppSpacing.lg),
              _TopWorksSection(analytics: analytics),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.analytics});

  final FanWorkAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        _StatCard(label: 'Total Works', value: '${analytics.totalWorks}', icon: Icons.auto_awesome),
        _StatCard(label: 'Published', value: '${analytics.publishedWorks}', icon: Icons.publish),
        _StatCard(label: 'Drafts', value: '${analytics.draftWorks}', icon: Icons.drafts),
        _StatCard(label: 'Total Likes', value: '${analytics.totalLikes}', icon: Icons.favorite),
        _StatCard(label: 'Total Saves', value: '${analytics.totalBookmarks}', icon: Icons.bookmark),
        _StatCard(label: 'Total Comments', value: '${analytics.totalComments}', icon: Icons.comment),
        _StatCard(label: 'Avg Rating', value: analytics.averageRating.toStringAsFixed(1), icon: Icons.star),
        _StatCard(label: 'Total Views', value: '${analytics.totalViews}', icon: Icons.visibility),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WorksByTypeChart extends StatelessWidget {
  const _WorksByTypeChart({required this.analytics});

  final FanWorkAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = analytics.worksByType.entries.map((entry) {
      final total = analytics.totalWorks;
      final percentage = total > 0 ? entry.value / total : 0.0;
      final label = entry.key;
      final caption =
          '${entry.value} (${(percentage * 100).toStringAsFixed(0)}%)';
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text(caption, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }).toList(growable: false);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Works by Type', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...rows,
        ],
      ),
    );
  }
}

class _TopWorksSection extends StatelessWidget {
  const _TopWorksSection({required this.analytics});

  final FanWorkAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.topWorks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Works', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...analytics.topWorks.map((work) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: work.coverPath.isNotEmpty
                ? SizedBox(
                    width: 48,
                    height: 64,
                    child: AppImageLoader(imageUrl: work.coverPath, fit: BoxFit.cover),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 40),
            title: Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${FanWorkTypeCatalog.label(work.type)} · ${work.creatorName}'),
            onTap: () => FanWorkLinks.open(context, work.id),
          )),
        ],
      ),
    );
  }
}