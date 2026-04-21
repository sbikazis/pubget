// lib/features/groups/group_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/firestore_paths.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/app_dialog.dart';

import '../../models/group_model.dart';
import '../../models/member_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/home_provider.dart';
import 'package:pubget/models/user_model.dart';

import '../groups/group_members_screen.dart';
import '../groups/roleplay_join_screen.dart';
import '../groups/chat/chat_screen.dart';
import '../groups/edit_group_screen.dart';
import '../../services/firebase/firestore_service.dart';
import '../../core/logic/group_join_validator.dart';
import 'package:pubget/services/monetization/promotion_dayalog.dart';
import '../../core/logic/subscription_limits_logic.dart'; // إضافة استيراد المنطق

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({Key? key, required this.groupId}) : super(key: key);

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

  Future<void> _showInviterDialog(GroupModel group, UserModel user) async {
    final controller = TextEditingController();
    bool hasInviter = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('طلب انضمام'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل تمت دعوتك من قبل عضو في هذه المجموعة؟'),
              CheckboxListTile(
                title: const Text('نعم، دعاني صديق'),
                value: hasInviter,
                activeColor: AppColors.primary,
                onChanged: (val) => setDialogState(() => hasInviter = val!),
              ),
              if (hasInviter)
                AppTextField(
                  label: 'اسم الداعي',
                  placeholder: 'اكتب اسم العضو أو شخصيته',
                  controller: controller,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final inviterName = hasInviter ? controller.text.trim() : null;
                Navigator.pop(context);
                _processJoin(group, user, inviterName);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ التعديل الرئيسي: استخدام showLimitReachedDialog لضمان تفعيل زر الترقية
  Future<void> _processJoin(GroupModel group, UserModel user, String? inviterName) async {
    setState(() => _isProcessing = true);
    try {
      final firestore = context.read<FirestoreService>();
      final validator = GroupJoinValidator(firestoreService: firestore);
     
      final validation = await validator.validateJoin(
        user: user,
        currentJoinedGroupsCount: _homeProvider.joinedGroups.length,
        groupId: group.id,
        groupType: group.type,
        characterName: null,
        characterImageUrl: null,
        animeName: group.animeName,
        animeId: group.animeId,
        inviterName: inviterName,
      );

      if (!validation.isValid) {
        if (mounted) {
          if (validation.shouldShowUpgrade) {
            // استخدام المحرك المركزي لفتح صفحة البريميوم
            AppDialog.showLimitReachedDialog(
              context,
              customContent: validation.errorMessage,
            );
          } else {
            AppDialog.show(
              context, 
              title: 'تنبيه', 
              content: validation.errorMessage!, 
              confirmText: "حسنا ✅",
            );
          }
        }
        return;
      }

      final error = await _homeProvider.joinGroup(
        user: user,
        group: group,
        invitedByUserId: validation.foundInviterId,
        onLimitReached: (limitResult) {
          if (limitResult.shouldShowUpgrade) {
            AppDialog.showLimitReachedDialog(
              context,
              customContent: limitResult.message,
            );
          } else {
            AppDialog.show(
              context,
              title: 'سعة الانضمام',
              content: limitResult.message ?? '',
              confirmText: 'حسناً',
            );
          }
        }
      );

      if (error != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الانضمام بنجاح')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onJoin(GroupModel group) async {
    final user = _authProvider.user;
    if (user == null) return;

    if (group.type.isRoleplay) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoleplayJoinScreen(group: group)),
      );
    } else {
      _showInviterDialog(group, user);
    }
  }

  Widget _buildRankingInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نظام ترقية الأعضاء النشطين',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'ادعُ أصدقاءك للانضمام وارتقِ تلقائياً إلى رتبة سينباي أو هاكوشو أو سينسي!',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(GroupModel group, List<MemberModel> members) {
    final user = _authProvider.user;
    if (user == null) return const SizedBox();

    final memberIds = members.map((e) => e.userId).toList();
    final isFounder = user.id == group.founderId;
    final isMember = memberIds.contains(user.id);
    final currentMember = isMember ? members.firstWhere((m) => m.userId == user.id) : null;

    if (isMember || isFounder) {
      return Row(
        children: [
          _buildChatButton(group.id),
          const SizedBox(width: 8),
          _buildMembersIconButton(group.id),
          _buildGroupOptionsButton(group, isFounder, currentMember),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .doc(FirestorePaths.groupJoinRequestDoc(group.id, user.id))
          .snapshots(),
      builder: (context, snapshot) {
        final hasRequest = snapshot.hasData && snapshot.data!.exists;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || hasRequest) ? null : () => _onJoin(group),
                    icon: Icon(hasRequest ? Icons.hourglass_top : Icons.group_add),
                    label: _isProcessing
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(hasRequest
                            ? 'بانتظار الموافقة'
                            : (group.type.isRoleplay ? 'انضم كتقمص دور' : 'انضم للمجموعة')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasRequest ? Colors.grey : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildMembersIconButton(group.id),
              ],
            ),
            if (!hasRequest) _buildRankingInfo(),
          ],
        );
      },
    );
  }

  Widget _buildChatButton(String groupId) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _openChat(groupId),
        icon: const Icon(Icons.chat),
        label: const Text('دخول للدردشة'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMembersIconButton(String groupId) => IconButton(
    onPressed: () => _openMembers(groupId),
    icon: const Icon(Icons.people),
    tooltip: 'الأعضاء',
  );

  Widget _buildGroupOptionsButton(GroupModel group, bool isFounder, MemberModel? currentMember) => IconButton(
    onPressed: () {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _buildOptionsSheet(group, isFounder, currentMember),
      );
    },
    icon: Icon(isFounder ? Icons.admin_panel_settings : Icons.more_vert),
    tooltip: isFounder ? 'أدوات المؤسس' : 'خيارات المجموعة',
  );

  Widget _buildOptionsSheet(GroupModel group, bool isFounder, MemberModel? currentMember) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          runSpacing: 8,
          children: [
            if (isFounder) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('تعديل المجموعة'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EditGroupScreen(group: group)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign, color: Colors.amber),
                title: const Text('ترويج المجموعة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPromotionDialog(group);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('تفكيك المجموعة (حذف نهائي)', style: TextStyle(color: Colors.red)),
                onTap: () => _handleDisbandGroup(group),
              ),
            ] else if (currentMember != null) ...[
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('خروج من المجموعة', style: TextStyle(color: Colors.red)),
                onTap: () => _handleLeaveGroup(group, currentMember),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleLeaveGroup(GroupModel group, MemberModel member) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مغادرة المجموعة'),
        content: Text('هل أنت متأكد من مغادرة "${group.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('مغادرة', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await _groupProvider.leaveGroup(
          groupId: group.id,
          userId: member.userId,
          characterName: member.characterName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد غادرت المجموعة')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDisbandGroup(GroupModel group) async {
    Navigator.of(context).pop();
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفكيك المجموعة 🚩'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيتم حذف المجموعة نهائياً وإشعار جميع الأعضاء. يمكنك كتابة رسالة وداع لهم:'),
            const SizedBox(height: 12),
            AppTextField(
              controller: messageController,
              label: 'رسالة الوداع (اختياري)',
              placeholder: 'شكراً لكم جميعاً...',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('تفكيك نهائي', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await _groupProvider.disbandGroup(
          groupId: group.id,
          groupName: group.name,
          farewellMessage: messageController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pop(); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفكيك المجموعة وإرسال رسائل الوداع')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showPromotionDialog(GroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromotionDialog(
        groupName: group.name,
        onConfirm: () async {
          Navigator.pop(context);
          try {
            await _groupProvider.promoteGroup(groupId: group.id, userId: _authProvider.user!.id);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترويج مجموعتك بنجاح!')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الترويج: $e')));
          }
        },
      ),
    );
  }

  void _openMembers(String groupId) => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersScreen(groupId: groupId)));
  void _openChat(String groupId) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(groupId: groupId)));

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return StreamBuilder<GroupModel?>(
      stream: groupProvider.streamGroup(groupId: widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Scaffold(body: Center(child: Text("حدث خطأ في الاتصال")));

        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: LoadingWidget(message: 'جاري التحميل...')));
        }

        final group = snapshot.data;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: EmptyStateWidget(title: 'المجموعة غير موجودة', icon: Icons.error, onActionPressed: () => Navigator.pop(context)))
          );
        }

        return StreamBuilder<List<MemberModel>>(
          stream: groupProvider.streamMembers(groupId: group.id),
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? [];
           
            return Scaffold(
              appBar: AppBar(
                title: const Text('تفاصيل المجموعة'),
                centerTitle: true
              ),
              body: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(group),
                        const SizedBox(height: 20),
                        _buildActions(group, members),
                        const SizedBox(height: 24),
                        const Text('الوصف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Divider(color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          group.description.isNotEmpty ? group.description : 'لا يوجد وصف متاح لهذه المجموعة.',
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  if (_isProcessing)
                    Container( 
                      color: Colors.black26,
                      child: const Center(child: LoadingWidget()),
                    ),
                ],
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