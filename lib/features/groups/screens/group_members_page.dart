import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import 'role_permissions_page.dart';

class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupMembersProvider>();
    Future<void>.microtask(() => provider.load(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
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
            return _MemberCard(member: provider.members[index]);
          },
        ),
      ),
    );
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
  const _MemberCard({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GroupMembersProvider>();
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
              onSelected: (action) => _act(context, provider, action),
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'role', child: Text('Change role')),
                PopupMenuItem(value: 'kick', child: Text('Kick')),
                PopupMenuItem(value: 'ban', child: Text('Ban')),
                PopupMenuItem(
                  value: 'transfer',
                  child: Text('Transfer ownership'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    GroupMembersProvider provider,
    String action,
  ) async {
    if (action == 'role') {
      await provider.changeRole(member.uid, GroupRole.senpai);
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
