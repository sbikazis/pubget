import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
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
      if (provider.isFounder) {
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
    if (!_redirected &&
        provider.state == LoadingState.loaded &&
        provider.isMember &&
        !provider.isFounder) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigation.go(context, '/group-chat?groupId=${widget.groupId}');
        }
      });
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(
          provider.isFounder ? GroupCopy.of(context).controlPanel : copy.groupDetails,
        ),
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
                : provider.isFounder
                    ? _FounderPanel(group: group)
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
            key: const Key('group-details-hero'),
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
                  Text(copy.rules, style: Theme.of(context).textTheme.titleMedium),
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

class _FounderPanel extends StatelessWidget {
  const _FounderPanel({required this.group});

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
          const SizedBox(height: AppSpacing.lg),
          _PromotionSection(group: group, provider: provider),
          const SizedBox(height: AppSpacing.lg),
          _PanelTile(
            icon: Icons.inbox_outlined,
            title: groupCopy.requestInbox,
            subtitle: groupCopy.pendingCount(pending),
            onTap: () => AppNavigation.go(
              context,
              '/group-requests?groupId=${group.id}',
            ),
          ),
          _PanelTile(
            icon: Icons.groups_outlined,
            title: copy.manageMembers,
            onTap: () => AppNavigation.go(
              context,
              '/group-members?groupId=${group.id}',
            ),
          ),
          _PanelTile(
            icon: Icons.gavel_outlined,
            title: groupCopy.manageRules,
            onTap: () => AppNavigation.go(
              context,
              '/group-settings?groupId=${group.id}',
            ),
          ),
          _PanelTile(
            icon: Icons.tune_outlined,
            title: copy.groupSettings,
            onTap: () => AppNavigation.go(
              context,
              '/group-settings?groupId=${group.id}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(groupCopy.growth, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: copy.members,
                  value: '${group.membersCount}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: groupCopy.growth,
                  value: '${group.activityScore}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-chat?groupId=${group.id}',
            ),
            semanticLabel: copy.openChat,
            leadingIcon: Icons.forum_outlined,
            child: Text(copy.openChat),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/events?groupId=${Uri.encodeComponent(group.id)}',
            ),
            semanticLabel: copy.groupEvents,
            child: Text(copy.groupEvents),
          ),
          if (provider.canCreateEvents) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/events/create?groupId=${Uri.encodeComponent(group.id)}',
              ),
              semanticLabel: copy.createEvent,
              child: Text(copy.createEvent),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/games?groupId=${Uri.encodeComponent(group.id)}',
            ),
            semanticLabel: copy.groupGames,
            child: Text(copy.groupGames),
          ),
          if (provider.membership?.canManageGames == true) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/games/create?groupId=${Uri.encodeComponent(group.id)}',
              ),
              semanticLabel: copy.createGame,
              child: Text(copy.createGame),
            ),
          ],
          if (provider.canManageMembers) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/group-bans?groupId=${group.id}',
              ),
              semanticLabel: copy.bannedUsers,
              child: Text(copy.bannedUsers),
            ),
          ],
          if (group.type != GroupType.public) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/group-roleplay?groupId=${group.id}',
              ),
              semanticLabel: copy.roleplayCharacters,
              child: Text(copy.roleplayCharacters),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(groupCopy.danger, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/group-members?groupId=${group.id}',
            ),
            semanticLabel: copy.transferOwnership,
            child: Text(copy.transferOwnership),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextButton(
            key: const Key('group-details-disband'),
            onPressed: () => _disband(context, provider),
            semanticLabel: copy.disbandGroup,
            child: Text(copy.disbandGroup),
          ),
        ],
      ),
    );
  }

  Future<void> _disband(BuildContext context, GroupProvider provider) async {
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

class _PromotionSection extends StatelessWidget {
  const _PromotionSection({required this.group, required this.provider});

  final Group group;
  final GroupProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final metrics = group.activityMetrics;
    final promoted = group.isPromoted &&
        (group.promotionExpiresAt == null ||
            group.promotionExpiresAt!.isAfter(DateTime.now()));
    return PubgetCard(
      key: const Key('group-promote-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(copy.promoteTitle, style: Theme.of(context).textTheme.titleMedium),
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
          ],
          if (promoted) ...[
            const SizedBox(height: AppSpacing.sm),
            PubgetBadge(label: copy.currentlyPromoted, compact: true),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: copy.newMembersWeek,
                  value: '${metrics?.joinsInWindow ?? 0}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: copy.chatActivity,
                  value: '${metrics?.recentMessageCount ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: copy.activeMembers,
                  value: '${metrics?.activeMemberCount ?? group.membersCount}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: copy.growth,
                  value: '${group.activityScore}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('group-promote-coins'),
            onPressed: provider.promoting
                ? null
                : () => provider.promote(group.id),
            semanticLabel: copy.promoteWithCoins,
            loading: provider.promoting,
            child: Text(provider.promoting ? copy.promoting : copy.promoteWithCoins),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('group-promote-share'),
            onPressed: () => PubgetLinks.share(
              context,
              url: PubgetLinks.group(group.id),
              title: group.name,
              type: 'group',
            ),
            semanticLabel: copy.shareGroupLink,
            leadingIcon: Icons.share_outlined,
            child: Text(copy.shareGroupLink),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('group-promote-copy'),
            onPressed: () => PubgetLinks.copy(
              context,
              PubgetLinks.group(group.id),
              type: 'group',
            ),
            semanticLabel: copy.copyGroupLink,
            leadingIcon: Icons.copy_outlined,
            child: Text(copy.copyGroupLink),
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

class _PanelTile extends StatelessWidget {
  const _PanelTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PubgetCard(
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.royalPurple.withValues(alpha: 0.16),
            child: Icon(icon, color: AppColors.gold),
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_left),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
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
