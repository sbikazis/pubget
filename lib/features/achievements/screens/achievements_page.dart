import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/achievement_models.dart';
import '../providers/achievement_provider.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({this.highlightId, super.key});

  final String? highlightId;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _opened = false;
  String? _openedForUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    if (_opened && _openedForUser == uid) return;
    _opened = true;
    _openedForUser = uid;
    final achievements = context.read<AchievementProvider>();
    Future<void>.microtask(() => achievements.open(uid));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AchievementProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: PubgetLoadingStateView(
        state: state.state,
        onRetry: uid == null
            ? null
            : () => context.read<AchievementProvider>().open(uid),
        empty: const PubgetEmptyState(
          title: 'No achievements yet',
          message: 'Play, create, and gather your circle. Unlocks appear here.',
        ),
        error: PubgetErrorState(
          message: state.failure?.message ?? 'Achievements could not load.',
          onRetry: uid == null
              ? null
              : () => context.read<AchievementProvider>().open(uid),
        ),
        offline: const PubgetOfflineState(),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = state.items[index];
            return _AchievementTile(
              item: item,
              highlighted: item.id == widget.highlightId,
            );
          },
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item, required this.highlighted});

  final AchievementItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: ListTile(
        selected: highlighted,
        leading: Icon(
          item.unlocked ? Icons.emoji_events_outlined : Icons.lock_outline,
        ),
        title: Text(item.title),
        subtitle: Text(
          [
            item.description,
            if (item.isSeasonal) 'Season ${item.seasonId}',
            if (item.unlocked && item.unlockedAt != null)
              'Unlocked ${item.unlockedAt!.toLocal().toIso8601String().split('T').first}',
            if (item.rewardCoins > 0) '${item.rewardCoins} coins',
          ].join('\n'),
        ),
        trailing: PubgetBadge(label: item.statusLabel),
      ),
    );
  }
}
