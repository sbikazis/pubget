import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';
import 'role_permissions_page.dart';

/// Menu values for a non-founder member row. Kick/ban are omitted when the
/// viewer cannot manage members (server still enforces the callable).
List<String> groupMemberMenuActions({required bool canManageMembers}) {
  return <String>[
    'role',
    if (canManageMembers) 'kick',
    if (canManageMembers) 'ban',
    'transfer',
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
    final canManageMembers = _viewerCanManageMembers(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: <Widget>[
          PubgetIconButton(
            icon: Icons.person_add_alt,
            tooltip: 'Create invitation',
            onPressed: () => _showInvite(context, provider),
          ),
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
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => provider.load(widget.groupId),
        empty: const PubgetEmptyState(title: 'No members'),
        error: PubgetErrorState(
          message: provider.failure?.message ?? 'Members could not load.',
          onRetry: () => provider.load(widget.groupId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => provider.load(widget.groupId),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: provider.members.length + (provider.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index == provider.members.length) {
              return PubgetSecondaryButton(
                onPressed: provider.loadMore,
                semanticLabel: 'Load more members',
                child: const Text('Load more'),
              );
            }
            return _MemberCard(
              member: provider.members[index],
              canManageMembers: canManageMembers,
            );
          },
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
  const _MemberCard({required this.member, required this.canManageMembers});

  final GroupMember member;
  final bool canManageMembers;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GroupMembersProvider>();
    final actions = groupMemberMenuActions(canManageMembers: canManageMembers);
    return PubgetCard(
      child: Row(
        children: <Widget>[
          PubgetAvatar(name: member.uid),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.uid),
                Text(
                  '${groupRoleLabel(member.role)} • ${member.inviteCount} invites',
                ),
              ],
            ),
          ),
          if (member.role != GroupRole.founder)
            PopupMenuButton<String>(
              key: Key('member-menu-${member.uid}'),
              onSelected: (action) => _act(context, provider, action),
              itemBuilder: (_) => actions
                  .map(
                    (value) => PopupMenuItem<String>(
                      value: value,
                      child: Text(_menuLabel(value)),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  String _menuLabel(String value) => switch (value) {
    'role' => 'Change role',
    'kick' => 'Kick',
    'ban' => 'Ban',
    'transfer' => 'Transfer ownership',
    _ => value,
  };

  Future<void> _act(
    BuildContext context,
    GroupMembersProvider provider,
    String action,
  ) async {
    if (action == 'role') {
      final role = await showDialog<GroupRole>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Change role'),
          children: GroupRole.values
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
          ? 'This changes the Founder role. A second confirmation follows.'
          : 'Confirm this sensitive group action.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !context.mounted) return;
    if (action == 'transfer') {
      final second = await PubgetConfirmationDialog.show(
        context,
        title: 'Final ownership confirmation',
        message: 'You will no longer be the Founder.',
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
