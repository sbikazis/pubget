// lib/features/groups/join_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/member_model.dart';
import '../../providers/group_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/role_colors.dart';

import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_dialog.dart';

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

  Future<void> _handleAccept(BuildContext context, MemberModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'قبول الطلب',
        content: 'هل تريد قبول انضمام ${request.displayName}؟',
        confirmText: 'قبول',
        onConfirm: () => Navigator.pop(context, true),
        cancelText: 'إلغاء',
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true) return;

    try {
      // جلب اسم المجموعة للإشعار
      final group = await context.read<GroupProvider>().getGroup(groupId: groupId);
      final groupName = group?.name ?? "المجموعة";

      await context.read<GroupProvider>().acceptJoinRequest(
        groupId: groupId,
        groupName: groupName,
        requestMember: request,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول العضو بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في القبول: $e')),
      );
    }
  }

  Future<void> _handleReject(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: 'رفض الطلب',
        content: 'هل تريد رفض وحذف هذا الطلب نهائياً؟',
        confirmText: 'رفض',
        onConfirm: () => Navigator.pop(context, true),
        cancelText: 'إلغاء',
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true) return;

    try {
      final group = await context.read<GroupProvider>().getGroup(groupId: groupId);
      final groupName = group?.name ?? "المجموعة";

      await context.read<GroupProvider>().rejectJoinRequest(
        groupId: groupId,
        groupName: groupName,
        userId: userId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض الطلب')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الرفض: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الانضمام'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: AppColors.primary,
        elevation: 0,
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

          final requests = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index];

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: req.characterImageUrl != null 
                                ? NetworkImage(req.characterImageUrl!) 
                                : null,
                            child: req.characterImageUrl == null 
                                ? const Icon(Icons.person) 
                                : null,
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
                                        req.displayName?? 'مستخدم مجهول',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    _buildRoleBadge('طالب انضمام', RoleColors.senpai, RoleColors.senpaiBadgeBg),
                                  ],
                                ),
                                if (req.characterName != null)
                                  Text(
                                    'الشخصية: ${req.characterName}',
                                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                                  ),
                                Text(
                                  'تاريخ الطلب: ${_formatDate(req.joinedAt)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (req.characterReason != null && req.characterReason!.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          'السبب: ${req.characterReason}',
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _handleReject(context, req.userId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('رفض'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleAccept(context, req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('قبول الانضمام'),
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
      ),
    );
  }
}