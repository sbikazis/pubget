import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';

/// Rank-aware entry surface for GOKENIN+ members (not mikado control panel).
class GroupEntryHub extends StatelessWidget {
  const GroupEntryHub({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final copy = AppStrings.of(context);
    final rank = provider.viewerRank ?? PubgetRank.ronin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = rankColorResolver(rank, isDarkMode: isDark);
    final permissions = provider.viewerPermissions;
    final tabs = dashboardTabsFor(permissions);
    final badge = pubgetRankBadgeAsset(rank);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PubgetCard(
            child: Row(
              children: <Widget>[
                if (badge != null)
                  Image.asset(
                    badge,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.military_tech,
                      color: accent,
                      size: 36,
                    ),
                  ),
                if (badge != null) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pubgetRankDisplayName(rank),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (rankUsesFullDashboard(rank))
            _TabbedDashboard(
              group: group,
              tabs: tabs,
              accent: accent,
            )
          else ...[
            if (permissions.contains(GroupPermission.invite))
              _HubCard(
                accent: accent,
                icon: Icons.person_add_alt,
                title: copy.addMembers,
                subtitle: 'Invite friends into this circle.',
                onTap: () => AppNavigation.go(
                  context,
                  '/group-members?groupId=${group.id}',
                ),
              ),
            if (permissions.contains(GroupPermission.pinOwnMessages) ||
                permissions.contains(GroupPermission.promoteContent))
              _HubCard(
                accent: accent,
                icon: Icons.push_pin_outlined,
                title: 'Pinned content',
                subtitle: 'Highlights and pinned posts for the group.',
                onTap: () => AppNavigation.go(
                  context,
                  '/group-chat?groupId=${group.id}',
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('entry-hub-enter-chat'),
            onPressed: () => AppNavigation.go(
              context,
              '/group-chat?groupId=${group.id}',
            ),
            semanticLabel: copy.openChat,
            leadingIcon: Icons.forum_outlined,
            child: Text(copy.openChat),
          ),
        ],
      ),
    );
  }
}

class _TabbedDashboard extends StatelessWidget {
  const _TabbedDashboard({
    required this.group,
    required this.tabs,
    required this.accent,
  });

  final Group group;
  final List<RankDashboardTab> tabs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final actionable = tabs
        .where((tab) => tab != RankDashboardTab.chat)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final tab in actionable)
          _HubCard(
            accent: accent,
            icon: _tabIcon(tab),
            title: _tabLabel(tab),
            onTap: () => _openTab(context, tab),
          ),
      ],
    );
  }

  void _openTab(BuildContext context, RankDashboardTab tab) {
    final id = group.id;
    final route = switch (tab) {
      RankDashboardTab.invite || RankDashboardTab.members =>
        '/group-members?groupId=$id',
      RankDashboardTab.requests => '/group-requests?groupId=$id',
      RankDashboardTab.events =>
        '/events?groupId=${Uri.encodeComponent(id)}',
      RankDashboardTab.games => '/games?groupId=${Uri.encodeComponent(id)}',
      RankDashboardTab.bans => '/group-bans?groupId=$id',
      RankDashboardTab.background ||
      RankDashboardTab.settings ||
      RankDashboardTab.roles ||
      RankDashboardTab.audit =>
        '/group-settings?groupId=$id',
      RankDashboardTab.pinnedContent || RankDashboardTab.chat =>
        '/group-chat?groupId=$id',
    };
    AppNavigation.go(context, route);
  }

  IconData _tabIcon(RankDashboardTab tab) => switch (tab) {
    RankDashboardTab.invite => Icons.person_add_alt,
    RankDashboardTab.pinnedContent => Icons.push_pin_outlined,
    RankDashboardTab.members => Icons.groups_outlined,
    RankDashboardTab.requests => Icons.inbox_outlined,
    RankDashboardTab.events => Icons.event_outlined,
    RankDashboardTab.games => Icons.sports_esports_outlined,
    RankDashboardTab.bans => Icons.block_outlined,
    RankDashboardTab.background => Icons.wallpaper_outlined,
    RankDashboardTab.settings => Icons.tune_outlined,
    RankDashboardTab.roles => Icons.admin_panel_settings_outlined,
    RankDashboardTab.audit => Icons.history_outlined,
    RankDashboardTab.chat => Icons.forum_outlined,
  };

  String _tabLabel(RankDashboardTab tab) => switch (tab) {
    RankDashboardTab.invite => 'Invite',
    RankDashboardTab.pinnedContent => 'Pinned content',
    RankDashboardTab.members => 'Members',
    RankDashboardTab.requests => 'Requests',
    RankDashboardTab.events => 'Events',
    RankDashboardTab.games => 'Games',
    RankDashboardTab.bans => 'Bans',
    RankDashboardTab.background => 'Background',
    RankDashboardTab.settings => 'Settings',
    RankDashboardTab.roles => 'Roles',
    RankDashboardTab.audit => 'Audit',
    RankDashboardTab.chat => 'Chat',
  };
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Color accent;
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
            backgroundColor: accent.withValues(alpha: 0.18),
            child: Icon(icon, color: accent),
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: Icon(Icons.chevron_left, color: accent),
        ),
      ),
    );
  }
}
