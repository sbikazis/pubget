import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';

class GroupBansPage extends StatefulWidget {
  const GroupBansPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<GroupBansPage> createState() => _GroupBansPageState();
}

class _GroupBansPageState extends State<GroupBansPage> {
  var _requestedGroupLoad = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupMembersProvider>();
    Future<void>.microtask(() => provider.loadBans(widget.groupId));
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
    final members = context.watch<GroupMembersProvider>();
    final groups = context.watch<GroupProvider>();
    final allowed =
        groups.group?.id == widget.groupId && groups.canManageMembers;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Banned users')),
      body: !allowed && groups.state == LoadingState.loaded
          ? const PubgetEmptyState(
              title: 'You cannot manage bans',
              message:
                  'Only the founder or a role with manageMembers can '
                  'see and unban users.',
              icon: Icons.lock_outline,
            )
          : PubgetLoadingStateView(
              state: members.state,
              onRetry: () => members.loadBans(widget.groupId),
              empty: const PubgetEmptyState(
                title: 'No banned users',
                message: 'Banned members will appear here.',
              ),
              error: PubgetErrorState(
                message: members.failure?.message ?? 'Bans could not load.',
                onRetry: () => members.loadBans(widget.groupId),
              ),
              offline: PubgetOfflineState(
                onRetry: () => members.loadBans(widget.groupId),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: members.bans.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final ban = members.bans[index];
                  return PubgetCard(
                    child: Row(
                      children: <Widget>[
                        PubgetAvatar(name: ban.uid),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(ban.uid),
                              if (ban.bannedByUid != null)
                                Text('Banned by ${ban.bannedByUid}'),
                            ],
                          ),
                        ),
                        PubgetSecondaryButton(
                          key: Key('unban-${ban.uid}'),
                          onPressed: members.state == LoadingState.refreshing
                              ? null
                              : () => _unban(context, members, ban),
                          semanticLabel: 'Unban ${ban.uid}',
                          child: const Text('Unban'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _unban(
    BuildContext context,
    GroupMembersProvider provider,
    GroupBan ban,
  ) async {
    final confirmed = await PubgetConfirmationDialog.show(
      context,
      title: 'Unban ${ban.uid}?',
      message: 'They will be able to join again under the group join policy.',
      confirmLabel: 'Unban',
      cancelLabel: 'Cancel',
    );
    if (confirmed == true) await provider.unban(ban.uid);
  }
}
