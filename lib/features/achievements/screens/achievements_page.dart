import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/achievement_copy.dart';
import '../models/achievement_models.dart';
import '../providers/achievement_provider.dart';
import '../widgets/achievement_badge_widget.dart';
import '../widgets/achievement_celebration.dart';

/// Single achievements list screen (profile + drawer).
/// Toggle [progressMode] via the top-start "Progress" control to show all 10.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({
    this.highlightId,
    this.userId,
    this.displayName,
    this.isOwner = true,
    super.key,
  });

  final String? highlightId;
  final String? userId;
  final String? displayName;
  final bool isOwner;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _opened = false;
  String? _openedForUser;
  var _progressMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authId = context.read<AuthProvider>().currentUser?.id;
    final target = widget.userId ?? authId;
    if (target == null) return;
    if (_opened && _openedForUser == target) return;
    _opened = true;
    _openedForUser = target;
    final achievements = context.read<AchievementProvider>();
    Future<void>.microtask(() async {
      await achievements.open(target);
      if (!mounted) return;
      _maybeCelebrate();
    });
  }

  void _maybeCelebrate() {
    final provider = context.read<AchievementProvider>();
    final next = provider.takePendingCelebration();
    if (next == null) return;
    final arabic = AchievementCopy.of(context).isArabic;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AchievementCelebration.show(context, item: next, arabic: arabic)
          .whenComplete(() {
        if (mounted) _maybeCelebrate();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AchievementProvider>();
    final copy = AchievementCopy.of(context);
    final authId = context.watch<AuthProvider>().currentUser?.id;
    final target = widget.userId ?? authId;
    final title = copy.entryLabel(
      isOwner: widget.isOwner,
      displayName: widget.displayName ?? '',
    );

    final unlocked = state.unlocked;
    final visible = _progressMode ? state.items : unlocked;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0714),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: AppBackButton.maybeOf(context),
        title: Text(title),
      ),
      body: PubgetAtmosphere(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('achievements-progress-toggle'),
                  onPressed: () =>
                      setState(() => _progressMode = !_progressMode),
                  icon: Icon(
                    _progressMode
                        ? Icons.emoji_events_outlined
                        : Icons.insights_outlined,
                  ),
                  label: Text(
                    _progressMode ? copy.showUnlockedOnly : copy.progressRatio,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PubgetLoadingStateView(
                state: state.state == LoadingState.initial
                    ? LoadingState.loading
                    : state.state,
                onRetry: target == null
                    ? null
                    : () => context.read<AchievementProvider>().open(target),
                empty: PubgetEmptyState(
                  title: copy.unlockedEmptyTitle,
                  message: copy.unlockedEmptyBody,
                  icon: Icons.emoji_events_outlined,
                  action: TextButton(
                    onPressed: () => setState(() => _progressMode = true),
                    child: Text(copy.progressRatio),
                  ),
                ),
                error: PubgetErrorState(
                  message: state.failure?.message ?? copy.loadFailed,
                  onRetry: target == null
                      ? null
                      : () => context.read<AchievementProvider>().open(target),
                  retryLabel: copy.retry,
                ),
                offline: PubgetOfflineState(
                  message: copy.loadFailed,
                  onRetry: target == null
                      ? null
                      : () => context.read<AchievementProvider>().open(target),
                ),
                child: visible.isEmpty && !_progressMode
                    ? PubgetEmptyState(
                        title: copy.unlockedEmptyTitle,
                        message: copy.unlockedEmptyBody,
                        icon: Icons.emoji_events_outlined,
                        action: TextButton(
                          key: const Key('achievements-open-progress-empty'),
                          onPressed: () =>
                              setState(() => _progressMode = true),
                          child: Text(copy.progressRatio),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: <Widget>[
                            for (var index = 0; index < visible.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == visible.length - 1
                                      ? 0
                                      : AppSpacing.md,
                                ),
                                child: _AchievementCard(
                                  item: visible[index],
                                  highlighted: visible[index].id ==
                                      widget.highlightId,
                                  progressMode: _progressMode,
                                  arabic: copy.isArabic,
                                  copy: copy,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.item,
    required this.highlighted,
    required this.progressMode,
    required this.arabic,
    required this.copy,
  });

  final AchievementItem item;
  final bool highlighted;
  final bool progressMode;
  final bool arabic;
  final AchievementCopy copy;

  @override
  Widget build(BuildContext context) {
    final rarityColor = switch (item.rarity) {
      AchievementRarity.common => Colors.blueGrey,
      AchievementRarity.uncommon => Colors.teal,
      AchievementRarity.rare => const Color(0xFF5C6BC0),
      AchievementRarity.epic => const Color(0xFF7E57C2),
      AchievementRarity.legendary => const Color(0xFFFFB300),
      AchievementRarity.mythic => const Color(0xFFE040FB),
    };
    final unlockedAt = item.unlockedAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.royalPurple.withValues(alpha: highlighted ? 0.55 : 0.32),
            const Color(0xFF160B24),
          ],
        ),
        border: Border.all(
          color: rarityColor.withValues(alpha: item.unlocked ? 0.75 : 0.28),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AchievementBadgeWidget(
                  key: Key('achievement-badge-${item.id}'),
                  item: item,
                  size: kAchievementListBadgeSize,
                  animate: item.unlocked,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.definition.name(arabic),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        item.definition.name(!arabic),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Text(
                          copy.rarityLabel(item.rarity),
                          style: TextStyle(
                            color: rarityColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (item.unlocked && unlockedAt != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${copy.unlockedOn}: ${_formatDate(unlockedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.gold,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              item.unlocked
                  ? item.definition.meaning(arabic)
                  : item.definition.description(arabic),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                  ),
            ),
            if (progressMode || !item.unlocked) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                copy.conditions,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...item.effectiveConditions.map((condition) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ConditionRow(
                    condition: condition,
                    arabic: arabic,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition, required this.arabic});

  final AchievementConditionProgress condition;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final met = condition.met;
    final target = condition.target;
    final current = condition.current;
    final showBar = target > 1;
    final ratio = target <= 0
        ? 0.0
        : (current / target).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: met ? Colors.lightGreenAccent : Colors.white54,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                condition.label(arabic),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
            if (showBar)
              Text(
                '${_trim(current)}/${_trim(target)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
          ],
        ),
        if (showBar) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.white12,
              color: met ? Colors.lightGreenAccent : AppColors.gold,
            ),
          ),
        ],
      ],
    );
  }

  String _trim(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
