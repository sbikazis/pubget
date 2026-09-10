import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';
import 'role_permissions_page.dart';

/// Menu values for a member row. Kick/ban are omitted when the viewer cannot
/// manage members (server still enforces the callable).
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
    final viewerId = context.watch<AuthProvider>().currentUser?.id;
    final canManageMembers = _viewerCanManageMembers(context);
    final viewerRank = groups.viewerRank;
    final copy = AppStrings.of(context);
    final query = _search.text.trim().toLowerCase();
    final sorted = [...provider.members]
      ..sort(compareMembersByRankThenJoined);
    final visible = query.isEmpty
        ? sorted
        : sorted
            .where((member) => member.uid.toLowerCase().contains(query))
            .toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.members),
        actions: <Widget>[
          PubgetIconButton(
            icon: Icons.person_add_alt,
            tooltip: copy.addMembers,
            onPressed: () => _showInvite(context, provider),
          ),
          if (canManageMembers)
            PubgetIconButton(
              icon: Icons.block_outlined,
              tooltip: copy.bannedUsers,
              onPressed: () => AppNavigation.go(
                context,
                '/group-bans?groupId=${widget.groupId}',
              ),
            ),
          if (viewerRank != null &&
              rankHasPermission(viewerRank, GroupPermission.manageRoles))
            PubgetIconButton(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: 'Edit role permissions',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RolePermissionsPage(groupId: widget.groupId),
                ),
              ),
            ),
        ],
      ),
      body: PubgetAtmosphere(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: PubgetSearchField(
                controller: _search,
                hint: copy.searchMembers,
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _search.clear();
                  setState(() {});
                },
              ),
            ),
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
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: visible.length + (provider.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == visible.length) {
                      return PubgetSecondaryButton(
                        onPressed: provider.loadMore,
                        semanticLabel: copy.loadMore,
                        child: Text(copy.loadMore),
                      );
                    }
                    return _MemberCard(
                      member: visible[index],
                      viewerId: viewerId,
                      viewerRank: viewerRank,
                      canManageMembers: canManageMembers,
                      isFounderViewer: groups.isFounder,
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

  bool _viewerCanManageMembers(BuildContext context) {
    final groups = context.watch<GroupProvider>();
    if (groups.group?.id != widget.groupId) return false;
    return groups.membership?.canManageMembers ?? false;
  }

  Future<void> _showInvite(
    BuildContext context,
    GroupMembersProvider provider,
  ) async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite a user'),
        content: PubgetTextField(
          controller: controller,
          label: 'Recipient UID',
        ),
        actions: <Widget>[
          PubgetTextButton(
            onPressed: () => Navigator.pop(dialogContext),
            semanticLabel: 'Cancel invitation',
            child: const Text('Cancel'),
          ),
          PubgetPrimaryButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            semanticLabel: 'Create invitation',
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (uid == null || uid.isEmpty || !context.mounted) return;
    final result = await provider.createInvite(uid);
    if (!context.mounted || !result.isSuccess) return;
    final inviteId = result.valueOrNull!;
    await PubgetAlertDialog.show(
      context,
      title: 'Invitation created',
      message:
          '/group-invite?groupId=${widget.groupId}&inviteId=$inviteId\n\n'
          'This recipient-bound invitation expires in seven days and can be '
          'used once.',
      closeLabel: 'Done',
      icon: Icons.link,
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.viewerId,
    required this.viewerRank,
    required this.canManageMembers,
    required this.isFounderViewer,
  });

  final GroupMember member;
  final String? viewerId;
  final PubgetRank? viewerRank;
  final bool canManageMembers;
  final bool isFounderViewer;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GroupMembersProvider>();
    final copy = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(member.role, isDarkMode: isDark);
    final badge = pubgetRankBadgeAsset(member.role);
    final isSelf = viewerId != null && viewerId == member.uid;
    final rankBlocked = viewerRank == null ||
        member.role.index >= viewerRank!.index;
    final assignable = viewerRank == null
        ? const <PubgetRank>[]
        : assignableRanksUnderCeiling(
            actor: viewerRank!,
            targetCurrent: member.role,
          );
    final canChangeRole = !isSelf && !rankBlocked && assignable.isNotEmpty;
    final canKickBan = canManageMembers && !isSelf && !rankBlocked;
    final canTransfer =
        isFounderViewer && !isSelf && member.role != PubgetRank.mikado;
    final actions = groupMemberMenuActions(
      canManageMembers: canKickBan,
      canChangeRole: canChangeRole,
      canTransfer: canTransfer,
    );
    return PubgetCard(
      child: Row(
        children: <Widget>[
          PubgetAvatar(
            name: member.uid,
            onTap: () =>
                AppNavigation.go(context, '/profile?uid=${member.uid}'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (badge != null) ...[
                      Image.asset(
                        badge,
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.military_tech,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        member.uid,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${copy.roleLabel(member.role.name)} • ${member.inviteCount} invites',
                  style: TextStyle(color: color.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              key: Key('member-menu-${member.uid}'),
              onSelected: (action) => _act(
                context,
                provider,
                action,
                assignable: assignable,
              ),
              itemBuilder: (_) => actions
                  .map(
                    (value) => PopupMenuItem<String>(
                      value: value,
                      child: Text(_menuLabel(context, value)),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  String _menuLabel(BuildContext context, String value) {
    final copy = AppStrings.of(context);
    return switch (value) {
      'role' => copy.changeRole,
      'kick' => copy.kick,
      'ban' => copy.ban,
      'transfer' => copy.transferOwnership,
      _ => value,
    };
  }

  Future<void> _act(
    BuildContext context,
    GroupMembersProvider provider,
    String action, {
    required List<PubgetRank> assignable,
  }) async {
    if (action == 'role') {
      final role = await showDialog<PubgetRank>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Change role'),
          children: assignable
              .map(
                (role) => SimpleDialogOption(
                  key: Key('pick-role-${role.name}'),
                  onPressed: () => Navigator.pop(dialogContext, role),
                  child: Text(groupRoleLabel(role)),
                ),
              )
              .toList(growable: false),
        ),
      );
      if (role == null || !context.mounted) return;
      await provider.changeRole(member.uid, role);
      return;
    }
    final confirmed = await PubgetConfirmationDialog.show(
      context,
      title: action == 'transfer'
          ? 'Transfer ownership?'
          : '${action[0].toUpperCase()}${action.substring(1)} member?',
      message: action == 'transfer'
          ? 'This changes the MIKADO role. A second confirmation follows.'
          : 'Confirm this sensitive group action.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !context.mounted) return;
    if (action == 'transfer') {
      final second = await PubgetConfirmationDialog.show(
        context,
        title: 'Final ownership confirmation',
        message: 'You will no longer be the MIKADO.',
        confirmLabel: 'Transfer',
        cancelLabel: 'Cancel',
      );
      if (second == true) await provider.transferOwnership(member.uid);
    } else if (action == 'kick') {
      await provider.kick(member.uid);
    } else {
      await provider.ban(member.uid);
    }
  }
}
