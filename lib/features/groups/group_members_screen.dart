import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/member_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart'; // مضاف لجلب المستخدم الحالي
import '../../core/constants/roles.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_dialog.dart';
import '../../core/logic/role_assignment_logic.dart';
import '../../widgets/role_selector_sheet.dart'; // ✅ استيراد الملف الجديد

class GroupMembersScreen extends StatelessWidget {
  final String groupId;

  const GroupMembersScreen({Key? key, required this.groupId}) : super(key: key);

  // ✅ الدالة الجديدة التي تستخدم الـ Sheet الفخم للترقية
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
          Navigator.pop(context); // إغلاق الـ Sheet
         
          final result = RoleAssignmentLogic.promote(
            actor: actor,
            target: target,
            newRole: newRole,
            allMembers: allMembers,
          );

          if (result.isAllowed && result.updatedMember != null) {
            await groupProvider.addMember(
              member: result.updatedMember!,
              adminId: actor.userId,
            );
            
            // ✅ التعديل المطلوب: تغيير النص ليكون "تحديث" بدلاً من "ترقية" لشمولية التخفيض أيضاً
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم تحديث رتبة ${target.displayName} إلى ${newRole.label}')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.message ?? 'فشل التعديل')),
            );
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
              child: Text('إدارة العضو: ${target.displayName}',
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
                    content: 'هل تريد إزالة ${target.displayName} من المجموعة؟',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت الإزالة بنجاح')),
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

          // ترتيب الأعضاء حسب الهرمية
          final members = RoleAssignmentLogic.sortByHierarchy(snapshot.data!);
         
          // تحديد عضوية المستخدم الحالي للتحقق من صلاحياته
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
              final badgeBg = RoleColors.getBadgeBackground(member.role, isDark: isDark);

              // التحقق من إمكانية الإدارة
              final canManage = RoleAssignmentLogic.canModify(
                actorRole: currentUserMember.role,
                targetRole: member.role,
                actorId: currentUserMember.userId,
                targetId: member.userId,
              );

              // 🔥 التعديل المطلوب: استخدام الـ Getter الذكي displayImageUrl
              final String? profileImage = member.displayImageUrl;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: badgeBg,
                  backgroundImage: profileImage != null && profileImage.isNotEmpty
                      ? NetworkImage(profileImage)
                      : null,
                  child: (profileImage == null || profileImage.isEmpty)
                      ? Icon(Icons.person, color: roleColor)
                      : null,
                ),
                title: Text(
                  member.effectiveName, // ✅ تعديل إضافي لضمان تناسق الاسم أيضاً
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
                subtitle: member.characterName != null
                    ? Text(
                        member.characterName!,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                    if (canManage)
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