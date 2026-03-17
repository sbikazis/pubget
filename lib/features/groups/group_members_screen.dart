// lib/features/groups/group_members_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/member_model.dart';
import '../../providers/group_provider.dart';
import '../../core/constants/roles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_dialog.dart';
import '../../core/logic/role_assignment_logic.dart';

class GroupMembersScreen extends StatelessWidget {
  final String groupId;

  const GroupMembersScreen({Key? key, required this.groupId}) : super(key: key);

  void _showMemberActions(BuildContext context, MemberModel member) {
    final groupProvider = context.read<GroupProvider>();

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.upgrade),
              title: const Text('ترقية العضو'),
              onTap: () async {
                Navigator.pop(context);
                final members = await groupProvider.getMembers(groupId: groupId);

                // مثال: ترقية إلى Sensei إذا متاح
                final result = RoleAssignmentLogic.promote(
                  actor: members.firstWhere((m) => m.role == Roles.founder),
                  target: member,
                  newRole: Roles.sensei,
                  allMembers: members,
                );

                if (result.isAllowed && result.updatedMember != null) {
                  await groupProvider.addMember(member: result.updatedMember!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت الترقية بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message ?? 'فشل الترقية')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('إرجاع إلى عضو'),
              onTap: () async {
                Navigator.pop(context);
                final members = await groupProvider.getMembers(groupId: groupId);

                final result = RoleAssignmentLogic.demote(
                  actor: members.firstWhere((m) => m.role == Roles.founder),
                  target: member,
                );

                if (result.isAllowed && result.updatedMember != null) {
                  await groupProvider.addMember(member: result.updatedMember!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت الإرجاع بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message ?? 'فشل الإرجاع')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('إزالة العضو', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AppDialog(
                    title: 'تأكيد الإزالة',
                    content: 'هل تريد إزالة هذا العضو من المجموعة؟',
                    confirmText: 'إزالة',
                    onConfirm: () => Navigator.pop(context, true),
                    cancelText: 'إلغاء',
                    onCancel: () => Navigator.pop(context, false),
                  ),
                );

                if (confirmed == true) {
                  await groupProvider.removeMember(
                    groupId: groupId,
                    userId: member.userId,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت الإزالة')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أعضاء المجموعة'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MemberModel>>(
        stream: groupProvider.streamMembers(groupId: groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'جاري تحميل الأعضاء...');
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              title: 'لا يوجد أعضاء',
              subtitle: 'لم ينضم أي عضو بعد إلى هذه المجموعة.',
              icon: Icons.group_off,
            );
          }

          final members = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final roleColor = RoleColors.getColor(member.role, isDark: isDark);
              final badgeBg =
                  RoleColors.getBadgeBackground(member.role, isDark: isDark);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: badgeBg,
                  backgroundImage: member.characterImageUrl != null
                      ? NetworkImage(member.characterImageUrl!)
                      : null,
                  child: member.characterImageUrl == null
                      ? Icon(Icons.person, color: roleColor)
                      : null,
                ),
                title: Text(
                  member.displayName ?? 'مجهول',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
                subtitle: member.characterName != null
                    ? Text(
                        member.characterName!,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      )
                    : null,
                trailing: Text(
                  member.role.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: roleColor,
                  ),
                ),
                onTap: () {

                  // فقط المؤسس لا يمكن تعديله
                  if (member.role == Roles.founder) {
                    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن تعديل المؤسس')),
                  );
                  } else {
                      _showMemberActions(context, member);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}