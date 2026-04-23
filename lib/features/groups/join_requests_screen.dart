// lib/features/groups/join_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/member_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart'; // إضافة AuthProvider لفحص سعة الشوغو
import 'package:pubget/features/profile/profile_sceen.dart'; 

import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';
import '../../core/logic/subscription_limits_logic.dart'; // إضافة منطق الحدود

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/premium_badge.dart'; // ✅ إضافة مستورد الشارة

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

  // ✅ التعديل الرئيسي: استخدام showLimitReachedDialog الموحدة لضمان عمل زر الترقية
  Future<void> _handleAccept(BuildContext context, MemberModel request) async {
    final groupProvider = context.read<GroupProvider>();
    final authProvider = context.read<AuthProvider>();
    final adminUser = authProvider.user;

    if (adminUser == null) return;

    try {
      // 1. جلب بيانات المجموعة الحالية للتأكد من عدد الأعضاء
      final group = await groupProvider.getGroup(groupId: groupId);
      if (group == null) return;

      // 2. فحص الحدود: هل يسمح لصاحب المجموعة (الشوغو) بإضافة عضو جديد؟
      final limitResult = SubscriptionLimitsLogic.canAcceptNewMember(
        adminUser,
        group.membersCount,
      );

      if (!limitResult.isAllowed) {
        if (context.mounted) {
          if (limitResult.shouldShowUpgrade) {
            // ✅ استخدام الدالة المركزية لضمان انتقال المستخدم لصفحة الترقية
            AppDialog.showLimitReachedDialog(
              context, 
              customContent: limitResult.message,
            );
          } else {
            // تنبيه عادي إذا كان الحد لا يدعم الترقية (حالة نادرة)
            AppDialog.show(
              context,
              title: 'سعة المجموعة ممتلئة',
              content: limitResult.message ?? '',
              confirmText: 'حسناً',
            );
          }
        }
        return;
      }

      // 3. إذا كانت السعة تسمح، ننتقل لتأكيد القبول
      final String displayConfirmName = request.realUserName ?? request.displayName ?? "هذا العضو";

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false, 
        builder: (dialogContext) => AppDialog(
          title: 'قبول الطلب',
          content: 'هل تريد قبول انضمام $displayConfirmName؟',
          confirmText: 'قبول',
          onConfirm: () => Navigator.of(dialogContext).pop(true), 
          cancelText: 'إلغاء',
          onCancel: () => Navigator.of(dialogContext).pop(false),
        ),
      );

      if (confirmed != true) return;

      final groupName = group.name;

      await groupProvider.acceptJoinRequest(
        groupId: groupId,
        groupName: groupName,
        requestMember: request,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول العضو بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في القبول: $e')),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialog(
        title: 'رفض الطلب',
        content: 'هل تريد رفض وحذف هذا الطلب نهائياً؟',
        confirmText: 'رفض',
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        cancelText: 'إلغاء',
        onCancel: () => Navigator.of(dialogContext).pop(false),
      ),
    );

    if (confirmed != true) return;

    try {
      final groupProvider = context.read<GroupProvider>();
      final group = await groupProvider.getGroup(groupId: groupId);
      final groupName = group?.name ?? "المجموعة";

      await groupProvider.rejectJoinRequest(
        groupId: groupId,
        groupName: groupName,
        userId: userId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الرفض: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('طلبات الانضمام'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark ? Colors.white : AppColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<MemberModel>>(
        stream: groupProvider.streamJoinRequests(groupId: groupId),
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

          // ✅ التعديل الأول (المنطق): ترتيب يضع البريميوم أولاً ثم الأحدث تاريخاً
          // ملاحظة: الـ Provider الآن يقوم بالترتيب من Firestore ولكن نؤكده هنا احتياطاً
          final requests = snapshot.data!;
          requests.sort((a, b) {
            if (a.isPremium && !b.isPremium) return -1;
            if (!a.isPremium && b.isPremium) return 1;
            return b.joinedAt.compareTo(a.joinedAt);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index];
              final displayImage = req.characterImageUrl ?? req.realUserImageUrl;
              final String displayName = (req.characterName != null && req.characterName!.isNotEmpty)
                  ? req.characterName!
                  : (req.realUserName ?? req.displayName ?? 'عضو جديد');

              return Container(
                // ✅ التعديل الثاني (التصميم): التمييز البصري الذهبي يعتمد على الحقل المخزن
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: req.isPremium 
                    ? LinearGradient(
                        colors: isDark 
                          ? [const Color(0xFFD4AF37).withOpacity(0.15), AppColors.darkCard]
                          : [const Color(0xFFD4AF37).withOpacity(0.1), AppColors.lightCard],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      )
                    : null,
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: req.isPremium 
                        ? const BorderSide(color: Color(0xFFD4AF37), width: 2.0) 
                        : (isDark ? const BorderSide(color: AppColors.darkBorder, width: 0.5) : BorderSide.none),
                  ),
                  elevation: req.isPremium ? 6 : 0,
                  color: req.isPremium ? Colors.transparent : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isDark ? AppColors.darkSurface : Colors.grey[300],
                                  backgroundImage: displayImage != null
                                      ? NetworkImage(displayImage)
                                      : null,
                                  child: displayImage == null
                                      ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.grey)
                                      : null,
                                ),
                                if (req.isPremium)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const PremiumBadge(size: 18),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                                ),
                                              ),
                                            ),
                                            if (req.isPremium) ...[
                                              const SizedBox(width: 6),
                                              const PremiumBadge(size: 16),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                                        tooltip: 'عرض الملف الشخصي',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfileScreen(userId: req.userId),
                                            ),
                                          );
                                        },
                                      ),
                                      if (req.isPremium) ...[
                                         _buildRoleBadge('أولوية ✨', const Color(0xFFD4AF37), const Color(0xFFD4AF37).withOpacity(0.15)),
                                         const SizedBox(width: 4),
                                      ],
                                      _buildRoleBadge('طالب انضمام', RoleColors.senpai, RoleColors.senpaiBadgeBg),
                                    ],
                                  ),
                                  if (req.realUserName != null && req.realUserName != displayName)
                                    Text(
                                      '@${req.realUserName}',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'تاريخ الطلب: ${_formatDate(req.joinedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextHint : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (req.characterReason != null && req.characterReason!.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(
                            'السبب: ${req.characterReason}',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _handleReject(context, req.userId),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _handleAccept(context, req),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: req.isPremium ? const Color(0xFFD4AF37) : AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: req.isPremium ? 4 : 0,
                                minimumSize: const Size(120, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(req.isPremium ? 'قبول الأولويّة' : 'قبول الانضمام'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}