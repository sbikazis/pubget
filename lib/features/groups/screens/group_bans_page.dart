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

  String _formatBanDate(DateTime? value) {
    if (value == null) return '';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<GroupMembersProvider>();
    final groups = context.watch<GroupProvider>();
    final groupReady = groups.group?.id == widget.groupId;
    final allowed =
        groupReady && groups.canViewBannedMembers;
    final canUnban = groupReady && groups.canUnban;

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('الأعضاء المحظورون'),
      ),
      body: !allowed && groups.state == LoadingState.loaded
          ? const PubgetEmptyState(
              title: 'لا يمكن عرض المحظورين',
              message:
                  'تحتاج صلاحية الطرد/الحظر أو رفع الحظر لعرض هذه القائمة.',
              icon: Icons.lock_outline,
            )
          : PubgetLoadingStateView(
              state: members.state,
              onRetry: () => members.loadBans(widget.groupId),
              empty: const PubgetEmptyState(
                title: 'لا يوجد أعضاء محظورون حاليًا.',
              ),
              error: PubgetErrorState(
                message: members.failure?.message ?? 'تعذّر تحميل المحظورين.',
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
                  final details = <String>[
                    if (ban.lastRole != null)
                      'آخر رتبة: ${groupRoleLabel(ban.lastRole!)}',
                    if (ban.bannedByUid != null)
                      'حُظر بواسطة ${ban.bannedByUid}',
                    if (ban.createdAt != null)
                      _formatBanDate(ban.createdAt),
                    if (ban.reason != null && ban.reason!.trim().isNotEmpty)
                      ban.reason!.trim(),
                  ];
                  return PubgetCard(
                    child: Row(
                      children: <Widget>[
                        PubgetAvatar(name: ban.uid),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                ban.uid,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (details.isNotEmpty)
                                Text(details.join(' · ')),
                            ],
                          ),
                        ),
                        if (canUnban)
                          PubgetSecondaryButton(
                            key: Key('unban-${ban.uid}'),
                            onPressed: members.state == LoadingState.refreshing
                                ? null
                                : () => _unban(context, members, ban),
                            semanticLabel: 'إلغاء حظر ${ban.uid}',
                            child: const Text('إلغاء الحظر'),
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
      title: 'إلغاء حظر ${ban.uid}؟',
      message: 'سيتمكن من الانضمام مجدداً وفق سياسة دخول المجموعة.',
      confirmLabel: 'إلغاء الحظر',
      cancelLabel: 'إلغاء',
    );
    if (confirmed == true) await provider.unban(ban.uid);
  }
}
