// lib/features/groups/group_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../models/group_model.dart';
import '../../models/user_model.dart';

import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/home_provider.dart';

import '../groups/group_members_screen.dart';
import '../groups/roleplay_join_screen.dart';
import '../groups/chat/chat_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late GroupProvider _groupProvider;
  late AuthProvider _authProvider;
  late HomeProvider _homeProvider;

  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groupProvider = context.read<GroupProvider>();
    _authProvider = context.read<AuthProvider>();
    _homeProvider = context.read<HomeProvider>();
  }

  Future<void> _onJoin(GroupModel group) async {
    final user = _authProvider.user;
    if (user == null) {
      // If not logged in, navigate back or show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (group.type.isRoleplay) {
        // For roleplay groups we navigate to the roleplay join flow
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoleplayJoinScreen(group: group),
          ),
        );
      } else {
        final error = await _home_provider_join(user, group);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الانضمام إلى المجموعة')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _home_provider_join(UserModel user, GroupModel group) async {
    // Use HomeProvider.joinGroup to respect business rules
    return await _homeProvider.joinGroup(user: user, group: group);
  }

  void _openMembers(String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupMembersScreen(groupId: groupId)),
    );
  }

  void _openChat(String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(groupId: groupId)),
    );
  }

  Widget _buildHeader(GroupModel group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group image
        AspectRatio(
          aspectRatio: 16 / 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: group.imageUrl.isNotEmpty
                ? Image.network(
                    group.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                    ),
                  )
                : Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                group.type.label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (group.slogan.isNotEmpty)
          Text(
            group.slogan,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.group, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text('${group.membersCount} عضو'),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(
                '${group.createdAt.year}/${group.createdAt.month}/${group.createdAt.day}'),
          ],
        ),
        const SizedBox(height: 12),
        if (group.type.isRoleplay && group.animeName != null)
          Row(
            children: [
              const Icon(Icons.movie, size: 18),
              const SizedBox(width: 8),
              Text('الأنمي: ${group.animeName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
      ],
    );
  }

  Widget _buildActions(GroupModel group) {
    final user = _authProvider.user;
    final isFounder = user != null && user.id == group.founderId;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
                      );
                      return;
                    }
                    _onJoin(group);
                  },
            icon: const Icon(Icons.group_add),
            label: _isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(group.type.isRoleplay ? 'انضم كتقمص دور' : 'انضم للمجموعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _openMembers(group.id),
          icon: const Icon(Icons.people),
          tooltip: 'الأعضاء',
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => _openChat(group.id),
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'الدردشة',
        ),
        if (isFounder) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              // Founder actions placeholder (edit / promote)
              showModalBottomSheet(
                context: context,
                builder: (_) => _buildFounderSheet(group),
              );
            },
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'أدوات المؤسس',
          ),
        ],
      ],
    );
  }

  Widget _buildFounderSheet(GroupModel group) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          runSpacing: 8,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل المجموعة'),
              onTap: () {
                Navigator.of(context).pop();
                // navigate to edit screen when implemented
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('ترويج المجموعة'),
              onTap: () {
                Navigator.of(context).pop();
                // call promotion flow later
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف المجموعة', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: const Text('هل أنت متأكد من حذف هذه المجموعة؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _groupProvider.deleteGroup(groupId: group.id);
                  if (mounted) {
                    Navigator.of(context).pop(); // close details screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف المجموعة')),
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

  Widget _buildBody(GroupModel group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(group),
          const SizedBox(height: 16),
          _buildActions(group),
          const SizedBox(height: 18),
          const Text('الوصف', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            group.description.isNotEmpty ? group.description : 'لا يوجد وصف للمجموعة.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openMembers(group.id),
            icon: const Icon(Icons.visibility),
            label: const Text('عرض الأعضاء'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _groupProvider.streamGroup(groupId: widget.groupId),
      builder: (context, AsyncSnapshot<GroupModel?> snapshot) {
        Widget body;

        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: LoadingWidget(message: 'جاري التحميل...'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          body = Padding(
            padding: const EdgeInsets.all(24.0),
            child: EmptyStateWidget(
              title: 'المجموعة غير موجودة',
              subtitle: 'ربما تم حذف هذه المجموعة أو لم تعد متاحة.',
              icon: Icons.error_outline,
              actionLabel: 'العودة',
              onActionPressed: () => Navigator.of(context).pop(),
            ),
          );
        } else {
          final group = snapshot.data!;
          body = _buildBody(group);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('تفاصيل المجموعة'),
            centerTitle: true,
            elevation: 0,
          ),
          body: body,
        );
      },
    );
  }
}