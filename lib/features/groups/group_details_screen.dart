// lib/features/groups/group_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../models/group_model.dart';


import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/home_provider.dart';

import '../groups/group_members_screen.dart';
import '../groups/roleplay_join_screen.dart';
import '../groups/chat/chat_screen.dart';
// التعديل: تفعيل استيراد صفحة التعديل
import '../groups/edit_group_screen.dart'; 

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
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      if (group.type.isRoleplay) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoleplayJoinScreen(group: group)),
        );
      } else {
        final error = await _homeProvider.joinGroup(user: user, group: group);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الانضمام بنجاح')));
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildActions(GroupModel group, List<String> memberIds) {
    final user = _authProvider.user;
    final isFounder = user != null && user.id == group.founderId;
    final isMember = user != null && memberIds.contains(user.id);

    return Row(
      children: [
        Expanded(
          child: (isMember || isFounder) 
              ? ElevatedButton.icon(
                  onPressed: () => _openChat(group.id),
                  icon: const Icon(Icons.chat),
                  label: const Text('دخول للدردشة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _onJoin(group),
                  icon: const Icon(Icons.group_add),
                  label: _isProcessing
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(group.type.isRoleplay ? 'انضم كتقمص دور' : 'انضم للمجموعة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _openMembers(group.id),
          icon: const Icon(Icons.people),
          tooltip: 'الأعضاء',
        ),
        if (isFounder) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
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
                Navigator.of(context).pop(); // إغلاق القائمة
                // التعديل: التوجه فعلياً لصفحة التعديل وتمرير بيانات المجموعة
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditGroupScreen(group: group),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('ترويج المجموعة'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خاصية الترويج ستتوفر قريباً')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف المجموعة', style: TextStyle(color: Colors.red)),
              onTap: () => _confirmDelete(group),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(GroupModel group) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه المجموعة نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await _groupProvider.deleteGroup(groupId: group.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المجموعة')));
      }
    }
  }

  void _openMembers(String groupId) => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersScreen(groupId: groupId)));
  void _openChat(String groupId) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(groupId: groupId)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupModel?>(
      stream: _groupProvider.streamGroup(groupId: widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: LoadingWidget(message: 'جاري التحميل...')));
        final group = snapshot.data;
        if (group == null) return Scaffold(body: Center(child: EmptyStateWidget(title: 'المجموعة غير موجودة', icon: Icons.error, onActionPressed: () => Navigator.pop(context))));

        return StreamBuilder<List<String>>(
          stream: _groupProvider.streamMembers(groupId: group.id).map((m) => m.map((e) => e.userId).toList()),
          builder: (context, memberSnapshot) {
            final memberIds = memberSnapshot.data ?? [];
            
            return Scaffold(
              appBar: AppBar(title: const Text('تفاصيل المجموعة'), centerTitle: true),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(group),
                    const SizedBox(height: 16),
                    _buildActions(group, memberIds),
                    const SizedBox(height: 18),
                    const Text('الوصف', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(group.description.isNotEmpty ? group.description : 'لا يوجد وصف.'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(GroupModel group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: group.imageUrl.isNotEmpty 
                ? Image.network(group.imageUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50)),
          ),
        ),
        const SizedBox(height: 12),
        Text(group.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(group.type.label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.people, size: 18, color: Colors.grey),
            const SizedBox(width: 4),
            Text('${group.membersCount} عضو'),
          ],
        ),
      ],
    );
  }
}