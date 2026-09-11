import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_authority.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/members_council_sheets.dart';
import 'role_permissions_page.dart';

/// Menu values for a member row. Kick/ban are omitted when the viewer cannot
/// manage members (server still enforces the callable).
///
/// Kept for unit-test compatibility with the Council action model.
List<String> groupMemberMenuActions({
  required bool canManageMembers,
  required bool canChangeRole,
  required bool canTransfer,
}) {
  return <String>[
    if (canChangeRole) 'role',
    if (canManageMembers) 'kick',
    if (canManageMembers) 'ban',
    if (canTransfer) 'transfer',
  ];
}

class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  var _requestedGroupLoad = false;
  final _search = TextEditingController();
  PubgetRank? _rankFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupMembersProvider>();
    Future<void>.microtask(() => provider.load(widget.groupId));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedGroupLoad) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    _requestedGroupLoad = true;
    final groups = context.read<GroupProvider>();
    Future<void>.microtask(
      () => groups.load(groupId: widget.groupId, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    final groups = context.watch<GroupProvider>();
    final actor = groups.group?.id == widget.groupId ? groups.membership : null;
    final copy = AppStrings.of(context);
    final query = _search.text.trim().toLowerCase();
    final sorted = [...provider.members]
      ..sort(compareMembersByRankThenJoined);

    final filtered = sorted.where((member) {
      if (_rankFilter != null && member.role != _rankFilter) return false;
      if (query.isEmpty) return true;
      final haystack = <String?>[
        member.displayName,
        member.username,
        member.roleplayName,
        member.uid,
        member.primaryIdentity,
        member.secondaryIdentity,
      ].whereType<String>().map((s) => s.toLowerCase());
      return haystack.any((value) => value.contains(query));
    }).toList(growable: false);

    final memberCount =
        groups.group?.membersCount ?? provider.members.length;
    final occupancy = provider.rankOccupancy;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('الأعضاء'),
        actions: <Widget>[
          if (groups.canManageRoles)
            PopupMenuButton<String>(
              key: const Key('members-management-overflow'),
              tooltip: 'إدارة',
              onSelected: (value) {
                if (value == 'permissions') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RolePermissionsPage(groupId: widget.groupId),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'permissions',
                  child: Text('صلاحيات الرتب'),
                ),
              ],
            ),
        ],
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$memberCount أعضاء · 7 رتب',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                children: <Widget>[
                  PubgetSearchField(
                    controller: _search,
                    hint: copy.searchMembers,
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      if (GroupAuthority.canInvite(actor) || groups.canInvite)
                        Expanded(
                          child: PubgetSecondaryButton(
                            key: const Key('invite-members'),
                            onPressed: () => showInviteMembersSheet(
                              context,
                              groupId: widget.groupId,
                            ),
                            semanticLabel: 'دعوة أعضاء',
                            leadingIcon: Icons.person_add_alt,
                            child: const Text('دعوة أعضاء'),
                          ),
                        ),
                      if ((GroupAuthority.canInvite(actor) ||
                              groups.canInvite) &&
                          groups.canViewBannedMembers)
                        const SizedBox(width: AppSpacing.sm),
                      if (groups.canViewBannedMembers)
                        Expanded(
                          child: PubgetSecondaryButton(
                            key: const Key('banned-members'),
                            onPressed: () => AppNavigation.go(
                              context,
                              '/group-bans?groupId=${widget.groupId}',
                            ),
                            semanticLabel: 'الأعضاء المحظورون',
                            leadingIcon: Icons.block_outlined,
                            child: const Text('الأعضاء المحظورون'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: PubgetSelectionChip(
                      label: 'الكل',
                      selected: _rankFilter == null,
                      onSelected: (_) => setState(() => _rankFilter = null),
                    ),
                  ),
                  ...PubgetRank.values.map(
                    (rank) => Padding(
                      padding:
                          const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                      child: PubgetSelectionChip(
                        label: groupRoleLabel(rank),
                        selected: _rankFilter == rank,
                        onSelected: (_) => setState(() {
                          _rankFilter = _rankFilter == rank ? null : rank;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (provider.members.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: occupancy.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final seat = occupancy[index];
                    return _RankOverviewChip(
                      seat: seat,
                      selected: _rankFilter == seat.rank,
                      onTap: () => setState(() {
                        _rankFilter =
                            _rankFilter == seat.rank ? null : seat.rank;
                      }),
                    );
                  },
                ),
              ),
            ],
            Expanded(
              child: PubgetLoadingStateView(
                state: provider.state,
                onRetry: () => provider.load(widget.groupId),
                empty: PubgetEmptyState(title: copy.noMembers),
                error: PubgetErrorState(
                  message: provider.failure?.message ?? copy.membersFailed,
                  onRetry: () => provider.load(widget.groupId),
                ),
                offline: PubgetOfflineState(
                  onRetry: () => provider.load(widget.groupId),
                ),
                child: filtered.isEmpty && query.isNotEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'لم نعثر على عضو بهذا الاسم.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount:
                            filtered.length + (provider.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return PubgetSecondaryButton(
                              onPressed: provider.loadMore,
                              semanticLabel: copy.loadMore,
                              child: Text(copy.loadMore),
                            );
                          }
                          return _CouncilMemberCard(
                            member: filtered[index],
                            actor: actor,
                            founderId: groups.group?.founderId,
                            groupId: widget.groupId,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankOverviewChip extends StatelessWidget {
  const _RankOverviewChip({
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  final RankOccupancy seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(seat.rank, isDarkMode: isDark);
    final badge = pubgetRankBadgeAsset(seat.rank);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 112,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? color
                  : color.withValues(alpha: 0.28),
              width: selected ? 1.6 : 1,
            ),
            color: color.withValues(alpha: selected ? 0.14 : 0.07),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (badge != null)
                    Image.asset(
                      badge,
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.military_tech, size: 12, color: color),
                    ),
                  if (badge != null) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      groupRoleLabel(seat.rank),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                seat.countLabel(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                seat.capacityLabel(arabic: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouncilMemberCard extends StatelessWidget {
  const _CouncilMemberCard({
    required this.member,
    required this.actor,
    required this.founderId,
    required this.groupId,
  });

  final GroupMember member;
  final GroupMember? actor;
  final String? founderId;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final color = rankColorResolver(member.role, isDarkMode: false);
    final badge = pubgetRankBadgeAsset(member.role);
    final canRank = GroupAuthority.canManageTargetRank(
      actor: actor,
      target: member,
    );
    final canWarn = GroupAuthority.canWarnTarget(actor: actor, target: member);
    final canKick = GroupAuthority.canKickOrBanTarget(
      actor: actor,
      target: member,
    );
    final canTransfer = GroupAuthority.canTransferOwnership(
          actor: actor,
          founderId: founderId,
        ) &&
        member.role != PubgetRank.mikado &&
        actor?.uid != member.uid;
    final hasManagement = canRank || canWarn || canKick || canTransfer;

    return PubgetCard(
      key: hasManagement ? Key('member-menu-${member.uid}') : null,
      onTap: () => showMemberActionSheet(
        context,
        target: member,
        actor: actor,
        groupId: groupId,
        founderId: founderId,
      ),
      child: Row(
        children: <Widget>[
          PubgetAvatar(
            name: member.primaryIdentity,
            imageUrl: member.avatarUrl,
            onTap: () =>
                AppNavigation.go(context, '/profile?uid=${member.uid}'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.primaryIdentity,
                  style: pubgetRankNameTextStyle(member.role, fontSize: 15),
                ),
                if (member.secondaryIdentity != null)
                  Text(
                    member.secondaryIdentity!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    if (badge != null) ...[
                      Image.asset(
                        badge,
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.military_tech,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        groupRoleLabel(member.role),
                        style: TextStyle(
                          color: color.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.more_vert,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: hasManagement ? 0.55 : 0.28),
          ),
        ],
      ),
    );
  }
}
