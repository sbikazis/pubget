// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/profile_provider.dart'; 
import '../../models/user_model.dart';
import '../../models/group_model.dart';

import '../../widgets/app_button.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

import '../../core/theme/app_colors.dart';
import 'package:pubget/features/profile/edit_profile_screen.dart';
import 'package:pubget/features/profile/respect_modal.dart'; 

class ProfileScreen extends StatefulWidget { 
  final String? userId;

  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // ✅ تعديل: استخدام ألوان السمة لضمان الوضوح في الـ Dark Mode
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تعديل: ويدجت مخصص للإحصائيات يحل محل الـ Chip التقليدي لضمان التباين
  Widget _buildStatCard(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          profileProvider, 
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '',
                            style: TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
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
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (user.nickname != null && user.nickname!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              user.nickname!,
                              style: TextStyle(
                                fontSize: 14, 
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _buildStatCard(context, 'نقاط الاحترام', '${user.totalRespect}'),
                            _buildStatCard(context, 'المعجبون', '${user.fansCount}'),
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
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    user.bio, 
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

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
                  },
                ),
                const SizedBox(height: 10),
                const Divider(),
              ],

              const SizedBox(height: 8),

              // ================= Personal Details =================
              _buildInfoRow(context, 'الانضمام منذ', user.createdAt.toLocal().toString().split(' ').first),
              if (user.age != null) _buildInfoRow(context, 'العمر', '${user.age}'),
              if (user.country != null && user.country!.isNotEmpty) _buildInfoRow(context, 'البلد', user.country!),

              const SizedBox(height: 16),

              // ================= Favorite Animes =================
              Text(
                'الأنميات المفضلة', 
                style: TextStyle(
                  fontWeight: FontWeight.w700, 
                  fontSize: 16,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (user.favoriteAnimes.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: user.favoriteAnimes.map((anime) => Chip(
                    label: Text(anime, style: const TextStyle(fontSize: 12)),
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    labelStyle: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  )).toList(),
                )
              else
                Text(
                  'لم يتم إضافة أنميات مفضلة بعد', 
                  style: TextStyle(color: isDark ? AppColors.darkTextHint : Colors.grey),
                ),

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
                        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        appBar: AppBar(
                          title: Text(isMe ? 'مجموعاتي' : 'مجموعات ${user.username}'),
                          centerTitle: true,
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: group.imageUrl.isNotEmpty ? NetworkImage(group.imageUrl) : null,
                                      child: group.imageUrl.isEmpty ? const Icon(Icons.groups) : null,
                                    ),
                                    title: Text(
                                      group.name,
                                      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                    ),
                                    subtitle: Text(
                                      group.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios, 
                                      size: 16,
                                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                                    ),
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