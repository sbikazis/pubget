import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';
import 'group_join_sheet.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _redirected = false;
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    _requestedLoad = true;
    final provider = context.read<GroupProvider>();
    final members = _members(context);
    Future<void>.microtask(() async {
      await provider.load(groupId: widget.groupId, userId: userId);
      if (members == null) return;
      await members.load(widget.groupId);
      if (provider.isFounder || provider.hasEntryHub) {
        await members.loadRequests(widget.groupId);
      }
    });
  }

  GroupMembersProvider? _members(BuildContext context) {
    try {
      return context.read<GroupMembersProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    final group = provider.group;
    // RŌNIN members skip the control panel entirely and land in the chat.
    if (!_redirected &&
        provider.state == LoadingState.loaded &&
        provider.isMember &&
        !provider.isFounder &&
        !provider.hasEntryHub) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigation.go(context, '/group-chat?groupId=${widget.groupId}');
        }
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankAccent = provider.viewerRank == null
        ? null
        : rankColorResolver(provider.viewerRank!, isDarkMode: isDark);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(
          provider.isFounder || provider.hasEntryHub
              ? GroupCopy.of(context).controlPanel
              : copy.groupDetails,
        ),
        foregroundColor: rankAccent,
        actions: <Widget>[
          PubgetIconButton(
            icon: Icons.share_outlined,
            tooltip: copy.shareGroup,
            onPressed: () => PubgetLinks.share(
              context,
              url: PubgetLinks.group(widget.groupId),
              title: group?.name,
              type: 'group',
            ),
          ),
          PubgetIconButton(
            icon: Icons.copy_outlined,
            tooltip: copy.copyLink,
            onPressed: () => PubgetLinks.copy(
              context,
              PubgetLinks.group(widget.groupId),
              type: 'group',
            ),
          ),
        ],
      ),
      body: PubgetAtmosphere(
        child: SafeArea(
          child: PubgetLoadingStateView(
            state: provider.state,
            onRetry: () => _reload(context),
            error: PubgetErrorState(
              message: provider.failure?.message ?? copy.groupFailed,
              onRetry: () => _reload(context),
            ),
            offline: PubgetOfflineState(onRetry: () => _reload(context)),
            empty: PubgetEmptyState(title: copy.groupUnavailable),
            child: group == null
                ? const SizedBox.shrink()
                : provider.hasEntryHub
                ? _GroupControlPanel(group: group)
                : _VisitorDetails(group: group),
          ),
        ),
      ),
    );
  }

  Future<void> _reload(BuildContext context) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    await context.read<GroupProvider>().load(
      groupId: widget.groupId,
      userId: userId,
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 168,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const ColoredBox(color: AppColors.royalDusk),
                if (group.coverUrl != null && group.coverUrl!.isNotEmpty)
                  AppImageLoader(imageUrl: group.coverUrl!, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x00140C22), Color(0xE6140C22)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          PubgetHeroBanner(
            title: group.name,
            subtitle: group.description.isEmpty
                ? copy.communityFallback
                : group.description,
            leading: PubgetAvatar(
              imageUrl: group.imageUrl,
              name: group.name,
              size: PubgetAvatarSize.large,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorDetails extends StatelessWidget {
  const _VisitorDetails({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    GroupMembersProvider? members;
    try {
      members = context.watch<GroupMembersProvider>();
    } on ProviderNotFoundException {
      members = null;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _IdentityHeader(group: group),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              PubgetBadge(
                label: copy.groupTypeLabel(group.type.name),
                compact: true,
              ),
              PubgetBadge(
                label: copy.membersCount(group.membersCount),
                compact: true,
              ),
              PubgetBadge(
                label: copy.joinPolicyLabel(group.joinPolicy.name),
                compact: true,
              ),
            ],
          ),
          if (group.ruleItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            PubgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    copy.rules,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final rule in group.ruleItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text('• $rule'),
                    ),
                ],
              ),
            ),
          ],
          if (members != null && members.members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              GroupCopy.of(context).memberPreview,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.members.take(8).length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final member = members!.members[index];
                  return PubgetAvatar(
                    name: member.uid,
                    size: PubgetAvatarSize.medium,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (!provider.isMember) _JoinAction(group: group),
        ],
      ),
    );
  }
}

/// Unified GOKENIN+ control panel. Every section renders only when the
/// viewer actually holds the matching permission (Mikado = all).
class _GroupControlPanel extends StatelessWidget {
  const _GroupControlPanel({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    final groupCopy = GroupCopy.of(context);
    GroupMembersProvider? members;
    try {
      members = context.watch<GroupMembersProvider>();
    } on ProviderNotFoundException {
      members = null;
    }
    final pending = members?.requests.length ?? 0;
    final isOwner = provider.isFounder;
    final settingsCan = provider.canManageSettings || isOwner;
    final permissions = provider.viewerPermissions;
    final canRequests = permissions.contains(GroupPermission.manageRequests);
    final canMembers = provider.canManageMembers;
    final canRules = permissions.contains(GroupPermission.manageRoles);
    final canEvents = provider.canManageEvents;
    final canGames = permissions.contains(GroupPermission.manageGames);
    final canBans = provider.canViewBannedMembers;
    final actionCards = <Widget>[
      if (canRequests)
        _AdminActionCard(
          icon: Icons.inbox_outlined,
          title: groupCopy.requestInbox,
          subtitle: groupCopy.pendingCount(pending),
          onTap: () =>
              AppNavigation.go(context, '/group-requests?groupId=${group.id}'),
        ),
      if (canMembers)
        _AdminActionCard(
          icon: Icons.groups_outlined,
          title: copy.manageMembers,
          onTap: () =>
              AppNavigation.go(context, '/group-members?groupId=${group.id}'),
        ),
      if (canRules)
        _AdminActionCard(
          icon: Icons.gavel_outlined,
          title: groupCopy.manageRules,
          onTap: () =>
              AppNavigation.go(context, '/group-settings?groupId=${group.id}'),
        ),
      if (settingsCan)
        _AdminActionCard(
          icon: Icons.tune_outlined,
          title: copy.groupSettings,
          onTap: () =>
              AppNavigation.go(context, '/group-settings?groupId=${group.id}'),
        ),
      if (canEvents)
        _AdminActionCard(
          icon: Icons.event_outlined,
          title: copy.groupEvents,
          subtitle: copy.createEvent,
          onTap: () => AppNavigation.go(
            context,
            '/events?groupId=${Uri.encodeComponent(group.id)}',
          ),
          onSecondaryTap: () => AppNavigation.go(
            context,
            '/events/create?groupId=${Uri.encodeComponent(group.id)}',
          ),
        ),
      if (canGames)
        _AdminActionCard(
          icon: Icons.sports_esports_outlined,
          title: copy.groupGames,
          subtitle: copy.createGame,
          onTap: () => AppNavigation.go(
            context,
            '/games?groupId=${Uri.encodeComponent(group.id)}',
          ),
          onSecondaryTap: () => AppNavigation.go(
            context,
            '/games/create?groupId=${Uri.encodeComponent(group.id)}',
          ),
        ),
      if (canBans)
        _AdminActionCard(
          icon: Icons.block_outlined,
          title: copy.bannedUsers,
          onTap: () =>
              AppNavigation.go(context, '/group-bans?groupId=${group.id}'),
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ControlHero(group: group, rank: provider.viewerRank),
          const SizedBox(height: AppSpacing.md),
          _OpenChatButton(group: group),
          const SizedBox(height: AppSpacing.md),
          _QuickStatsStrip(group: group),
          if (settingsCan) ...[
            const SizedBox(height: AppSpacing.lg),
            _PromotionSection(group: group, provider: provider),
          ],
          if (actionCards.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              groupCopy.overview,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.18,
              children: actionCards,
            ),
          ],
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.xl),
            _DangerZone(group: group, provider: provider),
          ],
        ],
      ),
    );
  }
}

class _ControlHero extends StatelessWidget {
  const _ControlHero({required this.group, required this.rank});

  final Group group;
  final PubgetRank? rank;

  @override
  Widget build(BuildContext context) {
    final resolvedRank = rank ?? PubgetRank.gokenin;
    final copy = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankColor = rankColorResolver(resolvedRank, isDarkMode: isDark);
    final policy = group.joinPolicy;
    final visibility = group.isSearchable
        ? copy.pick('Public', 'عامة')
        : copy.pick('Private', 'خاصة');
    return SizedBox(
      key: const Key('group-details-hero'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const ColoredBox(color: AppColors.royalDusk),
                        if (group.coverUrl != null && group.coverUrl!.isNotEmpty)
                          AppImageLoader(
                            imageUrl: group.coverUrl!,
                            fit: BoxFit.cover,
                          ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x14140C22),
                                Color(0xF2140C22),
                              ],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: AppSpacing.md,
                          start: AppSpacing.md,
                          child: Icon(
                            policy == JoinPolicy.inviteOnly
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    start: AppSpacing.lg,
                    bottom: -AppSpacing.md,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 4,
                        ),
                      ),
                      child: PubgetAvatar(
                        imageUrl: group.imageUrl,
                        name: group.name,
                        size: PubgetAvatarSize.large,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 92,
                  end: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      copy.groupTypeLabel(group.type.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: rankColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                key: const Key('group-hero-badges'),
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: <Widget>[
                    PubgetBadge(
                      label: pubgetRankDisplayName(resolvedRank),
                      icon: Icons.workspace_premium_outlined,
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.white,
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PubgetBadge(
                      label: '${group.membersCount}',
                      icon: Icons.groups_outlined,
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PubgetBadge(
                      label: copy.joinPolicyLabel(policy.name),
                      icon: policy == JoinPolicy.inviteOnly
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      backgroundColor: AppColors.goldPale,
                      foregroundColor: AppColors.goldDark,
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PubgetBadge(
                      label: visibility,
                      icon: group.isSearchable
                          ? Icons.public_outlined
                          : Icons.lock_outline,
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// First and only interactive element right under the hero — full width,
/// primary, with an unread dot when the chat has unseen activity.
class _OpenChatButton extends StatelessWidget {
  const _OpenChatButton({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final button = PubgetPrimaryButton(
      key: const Key('group-details-open-chat'),
      onPressed: () => AppNavigation.go(
        context,
        '/group-chat?groupId=${group.id}',
      ),
      semanticLabel: copy.openChat,
      leadingIcon: Icons.forum_outlined,
      child: Text(copy.openChat),
    );
    if (!group.hasUnread) return button;
    return Badge(
      isLabelVisible: true,
      backgroundColor: AppColors.error,
      child: button,
    );
  }
}

class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final strings = AppStrings.of(context);
    final metrics = group.activityMetrics;
    final stats = <(String, String, IconData)>[
      (copy.growth, '${group.activityScore}', Icons.trending_up_outlined),
      (strings.members, '${group.membersCount}', Icons.groups_outlined),
      (
        copy.chatActivity,
        '${metrics?.recentMessageCount ?? 0}',
        Icons.forum_outlined,
      ),
      (
        copy.newMembersWeek,
        '${metrics?.joinsInWindow ?? 0}',
        Icons.person_add_alt,
      ),
      (
        copy.activeMembers,
        '${metrics?.activeMemberCount ?? group.membersCount}',
        Icons.bolt_outlined,
      ),
    ];
    return SizedBox(
      key: const Key('group-quick-stats'),
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return SizedBox(
            width: 132,
            child: PubgetCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(stat.$3, size: 18, color: AppColors.royalPurple),
                  const Spacer(),
                  Text(
                    stat.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    stat.$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onSecondaryTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.royalPurple.withValues(alpha: 0.14),
            child: Icon(icon, color: AppColors.royalPurple),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: GestureDetector(
                onTap: onSecondaryTap,
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onSecondaryTap == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.royalPurple,
                    fontWeight:
                        onSecondaryTap == null ? null : FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromotionSection extends StatelessWidget {
  const _PromotionSection({required this.group, required this.provider});

  final Group group;
  final GroupProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final promoted =
        group.isPromoted &&
        (group.promotionExpiresAt == null ||
            group.promotionExpiresAt!.isAfter(DateTime.now()));
    final progress = group.risingEligible
        ? 1.0
        : (group.membersCount / 2).clamp(0.0, 1.0);
    return PubgetCard(
      key: const Key('group-promote-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.promoteTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            group.risingEligible ? copy.risingEligible : copy.risingNotEligible,
          ),
          if (!group.risingEligible) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final gap in group.risingGaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.circle, size: 8, color: AppColors.gold),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(_gapLabel(copy, gap))),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.goldPale,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.gold,
                ),
              ),
            ),
          ],
          if (promoted) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetBadge(label: copy.currentlyPromoted, compact: true),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: PubgetPrimaryButton(
                  key: const Key('group-promote-coins'),
                  onPressed: provider.promoting || !group.risingEligible
                      ? null
                      : () => provider.promote(group.id),
                  semanticLabel: copy.promoteWithCoins,
                  loading: provider.promoting,
                  child: Text(
                    provider.promoting
                        ? copy.promoting
                        : copy.promoteWithCoins,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PubgetIconButton(
                key: const Key('group-promote-share'),
                icon: Icons.share_outlined,
                tooltip: copy.shareGroupLink,
                onPressed: () => PubgetLinks.share(
                  context,
                  url: PubgetLinks.group(group.id),
                  title: group.name,
                  type: 'group',
                ),
              ),
              PubgetIconButton(
                key: const Key('group-promote-copy'),
                icon: Icons.copy_outlined,
                tooltip: copy.copyGroupLink,
                onPressed: () => PubgetLinks.copy(
                  context,
                  PubgetLinks.group(group.id),
                  type: 'group',
                ),
              ),
            ],
          ),
          if (provider.failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              provider.failure!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  String _gapLabel(GroupCopy copy, GroupRisingGap gap) => switch (gap) {
    GroupRisingGap.members => copy.risingNeedMembers,
    GroupRisingGap.image => copy.risingNeedImage,
    GroupRisingGap.description => copy.risingNeedDescription,
    GroupRisingGap.rules => copy.risingNeedRules,
    GroupRisingGap.activity => copy.risingNeedActivity,
  };
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.group, required this.provider});

  final Group group;
  final GroupProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  copy.dangerZone,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-members?groupId=${group.id}',
            ),
            semanticLabel: copy.transferOwnership,
            leadingIcon: Icons.swap_horiz,
            child: Text(copy.transferOwnership),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('group-details-disband'),
            onPressed: () => _disband(context),
            semanticLabel: copy.disbandGroup,
            leadingIcon: Icons.delete_outline,
            child: Text(copy.disbandGroup),
          ),
        ],
      ),
    );
  }

  Future<void> _disband(BuildContext context) async {
    final copy = AppStrings.of(context);
    final first = await PubgetConfirmationDialog.show(
      context,
      title: copy.disbandTitle(group.name),
      message: copy.disbandMessage,
      confirmLabel: copy.continueLabel,
      cancelLabel: copy.cancel,
    );
    if (first != true || !context.mounted) return;
    final second = await PubgetConfirmationDialog.show(
      context,
      title: copy.finalConfirmation,
      message: copy.disbandFinalMessage,
      confirmLabel: copy.disband,
      cancelLabel: copy.keepGroup,
    );
    if (second == true) await provider.disband(group.id);
  }
}

class _JoinAction extends StatelessWidget {
  const _JoinAction({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    if (provider.viewerBanned) {
      return PubgetEmptyState(
        title: copy.bannedFromGroup,
        message: copy.bannedFromGroup,
      );
    }
    if (provider.pendingRequest) {
      return PubgetEmptyState(title: copy.requestPending);
    }
    if (group.isFull) {
      return PubgetEmptyState(
        title: copy.groupCapacityReached,
        message: copy.groupFullMessage,
      );
    }
    if (group.joinPolicy == JoinPolicy.inviteOnly) {
      return PubgetEmptyState(
        title: copy.invitationRequired,
        message: copy.invitationRequiredMessage,
      );
    }
    final approval = group.joinPolicy == JoinPolicy.approval;
    final userId = context.read<AuthProvider>().currentUser?.id;
    return PubgetPrimaryButton(
      onPressed: provider.state == LoadingState.loading || userId == null
          ? null
          : () => showGroupJoinSheet(context, group: group, userId: userId),
      semanticLabel: approval ? copy.requestToJoin : copy.joinGroup,
      child: Text(approval ? copy.requestToJoin : copy.joinGroup),
    );
  }
}