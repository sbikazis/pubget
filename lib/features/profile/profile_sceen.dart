// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/group_provider.dart';
import '../../models/user_model.dart';
import '../../models/group_model.dart';

import '../../widgets/app_button.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

import '../../core/theme/app_colors.dart';

import 'package:pubget/features/profile/edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
    final userProvider = Provider.of<UserProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final UserModel? user = userProvider.currentUser;

    if (user == null) {
      return  Scaffold(
        appBar: AppBar(title: Text('الملف الشخصي'), centerTitle: true),
        body: Center(
          child: EmptyStateWidget(
            title: 'يجب تسجيل الدخول',
            subtitle: 'سجل الدخول أو أنشئ حسابًا لعرض الملف الشخصي',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await userProvider.loadUser(user.id);
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
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : '',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
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
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (user.nickname != null && user.nickname!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              user.nickname!,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Chip(
                              label:
                                  Text('نقاط الاحترام: ${user.totalRespect}'),
                              backgroundColor: AppColors.lightCard,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('المعجبون: ${user.fansCount}'),
                              backgroundColor: AppColors.lightCard,
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
                  child: Text(
                    user.bio,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

              const SizedBox(height: 16),

              // ================= Personal Details =================
              _buildInfoRow(
                  'الانضمام منذ',
                  user.createdAt.toLocal().toString().split(' ').first),
              if (user.age != null) _buildInfoRow('العمر', '${user.age}'),
              if (user.country != null && user.country!.isNotEmpty)
                _buildInfoRow('البلد', user.country!),

              const SizedBox(height: 16),

              // ================= Favorite Animes =================
              Text(
                'الأنميات المفضلة',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (user.favoriteAnimes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.favoriteAnimes
                      .map((anime) => Chip(label: Text(anime)))
                      .toList(),
                )
              else
                const Text(
                  'لم يتم إضافة أنميات مفضلة بعد',
                  style: TextStyle(color: Colors.grey),
                ),

              const SizedBox(height: 24),

              // ================= Actions =================
              AppButton(
                text: 'تعديل الملف الشخصي',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(user: user),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'عرض مجموعاتي',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('مجموعاتي'),
                          centerTitle: true,
                        ),
                        body: FutureBuilder<List<GroupModel>>(
                          future: groupProvider.getUserGroups(userId: user.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const LoadingWidget();
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const EmptyStateWidget(
                                title: 'لا توجد مجموعات',
                                subtitle: 'لم تنضم إلى أي مجموعة بعد',
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
                                      backgroundImage: group.imageUrl.isNotEmpty
                                          ? NetworkImage(group.imageUrl)
                                          : null,
                                      child: group.imageUrl.isEmpty
                                          ? const Icon(Icons.groups)
                                          : null,
                                    ),
                                    title: Text(group.name),
                                    subtitle: Text(group.description),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16),
                                    onTap: () {
                                      // فتح صفحة المجموعة لاحقًا
                                    },
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