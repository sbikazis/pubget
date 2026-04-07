// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/profile_provider.dart'; // ✅ إضافة المستورد الموحد
import '../../models/user_model.dart';
import '../../models/group_model.dart';

import '../../widgets/app_button.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

import '../../core/theme/app_colors.dart';
// تم حذف RespectLogic و FirestoreService من هنا لعدم الحاجة لهما في الواجهة بعد التوحيد
import 'package:pubget/features/profile/edit_profile_screen.dart';
import 'package:pubget/features/profile/respect_modal.dart'; // استيراد المودال الموحد

class ProfileScreen extends StatefulWidget { 
  final String? userId;

  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // تم حذف متغيرات الـ Slider والـ Loading القديمة لتوحيد المنطق

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام ProfileProvider بدلاً من التشتت بين المزودات
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

    final String? myId = authProvider.user?.id ?? userProvider.currentUser?.id;
    final String targetId = widget.userId ?? myId ?? '';

    if (targetId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
        body: const Center(
          child: EmptyStateWidget(
            title: 'يجب تسجيل الدخول',
            subtitle: 'سجل الدخول أو أنشئ حسابًا لعرض الملف الشخصي',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }

    // ✅ التعديل الجوهري: استخدام Stream لضمان تحديث البيانات فوراً عند تغييرها في الـ Modal
    return StreamBuilder<UserModel>(
      stream: profileProvider.streamUserProfile(targetId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingWidget());
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('الملف الشخصي')),
            body: const Center(child: Text('تعذر العثور على المستخدم')),
          );
        }

        final user = snapshot.data!;
        final bool isMe = (user.id == myId);

        return _buildProfileContent(
          context, 
          user, 
          profileProvider, // تمرير الـ profileProvider الموحد
          groupProvider, 
          isMe: isMe
        );
      },
    );
  }

  Widget _buildProfileContent(
    BuildContext context, 
    UserModel user, 
    ProfileProvider profileProvider, 
    GroupProvider groupProvider,
    {required bool isMe}
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // جلب البيانات مرة أخرى يدوياً عند السحب للأسفل
          await profileProvider.getUserProfile(user.id);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= Avatar + Username + Nickname =================
              Row(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.lightBorder,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (user.nickname != null && user.nickname!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              user.nickname!,
                              style: const TextStyle(fontSize: 14, color: Colors.black),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 4,
                          children: [
                            Chip(
                              label: Text('نقاط الاحترام: ${user.totalRespect}', style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppColors.lightCard,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('المعجبون: ${user.fansCount}', style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppColors.lightCard,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ================= Bio =================
              if (user.bio.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(user.bio, style: const TextStyle(fontSize: 14)),
                ),

              const SizedBox(height: 16),

              // ✅ التعديل الجوهري: استبدال الـ Slider اليدوي بزر ملكي يفتح الـ Modal
              if (!isMe && currentUserId != null) ...[
                const Divider(),
                AppButton(
                  text: 'امنح نقاط تقدير للعضو 🌟',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RespectModal(
                        targetUser: user,
                        currentUserId: currentUserId,
                      ),
                    ); 
                    // لم نعد بحاجة لـ .then هنا لأن الـ StreamBuilder سيتكفل بالتحديث التلقائي
                  },
                ),
                const SizedBox(height: 10),
                const Divider(),
              ],

              const SizedBox(height: 8),

              // ================= Personal Details =================
              _buildInfoRow('الانضمام منذ', user.createdAt.toLocal().toString().split(' ').first),
              if (user.age != null) _buildInfoRow('العمر', '${user.age}'),
              if (user.country != null && user.country!.isNotEmpty) _buildInfoRow('البلد', user.country!),

              const SizedBox(height: 16),

              // ================= Favorite Animes =================
              const Text('الأنميات المفضلة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (user.favoriteAnimes.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: user.favoriteAnimes.map((anime) => Chip(label: Text(anime))).toList(),
                )
              else
                const Text('لم يتم إضافة أنميات مفضلة بعد', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 24),

              // ================= Actions =================
              if (isMe)
                AppButton(
                  text: 'تعديل الملف الشخصي',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
                    );
                  },
                ),
              if (isMe) const SizedBox(height: 12),
              
              AppButton(
                text: isMe ? 'عرض مجموعاتي' : 'عرض مجموعات ${user.username}',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(isMe ? 'مجموعاتي' : 'مجموعات ${user.username}'),
                          centerTitle: true,
                        ),
                        body: FutureBuilder<List<GroupModel>>(
                          future: groupProvider.getUserGroups(userId: user.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingWidget();
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const EmptyStateWidget(
                                title: 'لا توجد مجموعات',
                                subtitle: 'لم يتم الانضمام إلى أي مجموعة بعد',
                                icon: Icons.group_off,
                              );
                            }
                            final groups = snapshot.data!;
                            return ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: groups.length,
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: group.imageUrl.isNotEmpty ? NetworkImage(group.imageUrl) : null,
                                      child: group.imageUrl.isEmpty ? const Icon(Icons.groups) : null,
                                    ),
                                    title: Text(group.name),
                                    subtitle: Text(group.description),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () {},
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}