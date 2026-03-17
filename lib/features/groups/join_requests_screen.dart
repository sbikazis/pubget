// lib/features/groups/join_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/invite_model.dart';
import '../../models/member_model.dart';
import '../../models/user_model.dart';

import '../../providers/group_provider.dart';
import '../../providers/profile_provider.dart';

import '../../services/firebase/firestore_service.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import 'package:pubget/core/constants/roles.dart';
/// شاشة عرض طلبات الانضمام لمجموعة (Join Requests)
/// تعتمد على:
/// - GroupProvider.streamInvites(groupId)
/// - ProfileProvider.getUserProfile(userId) لعرض بيانات المستخدم المدعو
/// - FirestoreService لحذف المستندات (قبول/رفض الطلب)
class JoinRequestsScreen extends StatelessWidget {
  final String groupId;

  const JoinRequestsScreen({Key? key, required this.groupId}) : super(key: key);

  String _formatDate(DateTime dt) {
    try {
      return DateFormat.yMMMd('ar').add_Hm().format(dt.toLocal());
    } catch (_) {
      return dt.toLocal().toString();
    }
  }

  /// تصميم شارة بسيطة (RoleBadge) مضمّنة داخل الشاشة
  Widget _buildRoleBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _acceptInvite({
    required BuildContext context,
    required InviteModel invite,
    required UserModel invitedUser,
  }) async {
    final groupProvider = context.read<GroupProvider>();
    final firestore = context.read<FirestoreService>();

    // تأكيد قبل الإجراء
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'قبول الطلب',
        content: 'هل تريد قبول طلب الانضمام لهذا المستخدم؟',
        confirmText: 'قبول',
        onConfirm: () => Navigator.pop(context, true),
        cancelText: 'إلغاء',
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true) return;



    try {
      // إنشاء MemberModel بسيط (دور افتراضي: member)
      final member = MemberModel(
        userId: invitedUser.id,
        groupId: invite.groupId,
        role: Roles.member,
        joinedAt: DateTime.now(),
        displayName: invitedUser.username,
      );

      await groupProvider.addMember(member: member);

      // حذف مستند الدعوة من الفرستور
      await firestore.deleteDocument(
        path: FirestorePaths.groupInvites(invite.groupId),
        docId: invite.inviteId,
      );

      if (Navigator.canPop(context)) Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الطلب وإضافة العضو')),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل قبول الطلب: ${e.toString()}')),
      );
    } finally {
      // ensure loading closed
      if (Navigator.canPop(context)) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
    }
  }

  Future<void> _rejectInvite({
    required BuildContext context,
    required InviteModel invite,
  }) async {
    final firestore = context.read<FirestoreService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'رفض الطلب',
        content: 'هل تريد رفض هذا الطلب؟ سيتم حذفه نهائياً.',
        confirmText: 'رفض',
        onConfirm: () => Navigator.pop(context, true),
        cancelText: 'إلغاء',
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true) return;



    try {
      await firestore.deleteDocument(
        path: FirestorePaths.groupInvites(invite.groupId),
        docId: invite.inviteId,
      );

      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض الطلب وحذفه')),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفض الطلب: ${e.toString()}')),
      );
    } finally {
      if (Navigator.canPop(context)) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final profileProvider = context.read<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الانضمام'),
        centerTitle: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: StreamBuilder<List<InviteModel>>(
        stream: groupProvider.streamInvites(groupId: groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'جاري تحميل الطلبات...');
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateWidget(
              title: 'لا توجد طلبات',
              subtitle: 'لم يصل أي طلب انضمام لهذه المجموعة حتى الآن.',
              icon: Icons.how_to_reg,
            );
          }

          final invites = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final invite = invites[index];

              return FutureBuilder<UserModel?>(
                future: profileProvider.getUserProfile(invite.invitedUserId),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      title: Text('جاري تحميل بيانات المستخدم...'),
                    );
                  }

                  final invitedUser = userSnap.data;

                  final avatar = invitedUser?.avatarUrl ?? '';
                  final displayName = invitedUser?.username ?? invite.invitedUserId;

                  // Badge: since invite doesn't include role, show "طالب انضمام" badge
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final badgeColor = RoleColors.senpai;
                  final badgeBg = RoleColors.senpaiBadgeBg;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? Icon(Icons.person, color: badgeColor) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildRoleBadge('طالب انضمام', badgeColor, badgeBg),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'مقدم من: ${invite.invitedByUserId}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'تاريخ الطلب: ${_formatDate(invite.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                text: 'قبول',
                                onPressed: invitedUser == null
                                    ? null
                                    : () => _acceptInvite(
                                          context: context,
                                          invite: invite,
                                          invitedUser: invitedUser,
                                        ),
                                expand: false,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => _rejectInvite(context: context, invite: invite),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('رفض'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}