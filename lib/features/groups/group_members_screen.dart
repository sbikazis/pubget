import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/member_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/constants/roles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_dialog.dart';
import '../../core/logic/role_assignment_logic.dart';
import '../../core/logic/invite_ranking_logic.dart';
import '../../widgets/role_selector_sheet.dart';

class GroupMembersScreen extends StatelessWidget {
  final String groupId;

  const GroupMembersScreen({Key? key, required this.groupId}) : super(key: key);

  void _showPromotionSheet(BuildContext context, MemberModel actor, MemberModel target, List<MemberModel> allMembers) {
    final groupProvider = context.read<GroupProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoleSelectorSheet(
        allMembers: allMembers,
        targetMember: target,
        onRoleSelected: (newRole) async {
          if (!context.mounted) return;
          Navigator.pop(context);

          final result = RoleAssignmentLogic.promote(
            actor: actor,
            target: target,
            newRole: newRole,
            allMembers: allMembers,
          );

          if (result.isAllowed && result.updatedMember!= null) {
            await groupProvider.addMember(
              member: result.updatedMember!,
              adminId: actor.userId,
            );

            await InviteRankingLogic.refreshRanks(groupId: groupId);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم تحديث رتبة ${target.effectiveName} إلى ${newRole.label}')),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message?? 'فشل التعديل')),
              );
            }
          }
        },
      ),
    );
  }

  void _showMemberActions(BuildContext context, MemberModel actor, MemberModel target, List<MemberModel> allMembers) {
    final groupProvider = context.read<GroupProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('إدارة العضو: ${target.effectiveName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts, color: AppColors.primary),
              title: const Text('تعديل الرتبة (ترقية/تخفيض)'),
              onTap: () {
                Navigator.pop(context);
                _showPromotionSheet(context, actor, target, allMembers);
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
                    content: 'هل تريد إزالة ${target.effectiveName} من المجموعة؟',
                    confirmText: 'إزالة',
                    onConfirm: () => Navigator.pop(context, true),
                    cancelText: 'إلغاء',
                    onCancel: () => Navigator.pop(context, false),
                  ),
                );

                if (confirmed == true) {
                  await groupProvider.removeMember(
                    groupId: groupId,
                    userId: target.userId,
                    adminId: actor.userId,
                  );

                  await InviteRankingLogic.refreshRanks(groupId: groupId);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت الإزالة بنجاح')),
                    );
                  }
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
    final currentUserId = context.read<UserProvider>().currentUser?.id;

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

          final members = RoleAssignmentLogic.sortByHierarchy(snapshot.data!);

          // ✅ [إضافة] حساب عدد الدعوات لكل عضو
          final Map<String, int> inviteCounts = {};
          for (var m in members) {
            if (m.invitedByUserId!= null && m.invitedByUserId!.isNotEmpty) {
              inviteCounts[m.invitedByUserId!] = (inviteCounts[m.invitedByUserId!]?? 0) + 1;
            }
          }

          final currentUserMember = members.firstWhere(
            (m) => m.userId == currentUserId,
            orElse: () => MemberModel(userId: '', groupId: '', role: Roles.member, joinedAt: DateTime.now()),
          );

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final roleColor = RoleColors.getColor(member.role, isDark: isDark);

              final canManage = RoleAssignmentLogic.canModify(
                actorRole: currentUserMember.role,
                targetRole: member.role,
                actorId: currentUserMember.userId,
                targetId: member.userId,
              );

              final String? profileImage = member.displayImageUrl;
              final int memberInvites = inviteCounts[member.userId]?? 0;

              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: ClipOval(
                    child: profileImage!= null && profileImage.isNotEmpty
                      ? Image.network(
                            profileImage,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: roleColor),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes!= null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(Icons.person, color: roleColor),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.effectiveName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ),
                    // مؤشر يدوي/دعوات
                    if (member.role!= Roles.member && member.role!= Roles.founder)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: member.isManualRole
                          ? Colors.purple.withOpacity(0.15)
                            : Colors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: member.isManualRole
                            ? Colors.purple.withOpacity(0.3)
                              : Colors.teal.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              member.isManualRole? Icons.verified_user : Icons.group_add,
                              size: 10,
                              color: member.isManualRole? Colors.purple : Colors.teal,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              member.isManualRole? 'يدوي' : 'دعوات',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: member.isManualRole? Colors.purple : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ✅ [إضافة] عداد الدعوات - يظهر فقط لو > 0
                    if (memberInvites > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_add_alt_1, size: 10, color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              '$memberInvites',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                subtitle: member.characterName!= null && member.characterName!.trim().isNotEmpty
                  ? Text(
                        member.characterName!,
                        style: TextStyle(
                          color: isDark? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.role.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: roleColor,
                      ),
                    ),
                    if (canManage && member.userId!= currentUserId)
                      const Icon(Icons.chevron_left, size: 16, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  if (member.userId == currentUserId) return;

                  if (canManage) {
                    _showMemberActions(context, currentUserMember, member, members);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا تملك صلاحية تعديل هذا العضو')),
                    );
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