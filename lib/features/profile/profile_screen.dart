// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/private_chat_provider.dart';
import '../../models/user_model.dart';
import '../../models/group_model.dart';

import '../../widgets/app_button.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/premium_badge.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/limits.dart';
import '../../core/utils/chat_id_utils.dart';
import 'package:pubget/features/profile/edit_profile_screen.dart';
import 'package:pubget/features/profile/respect_modal.dart';
import 'package:pubget/features/edits/user_edits_grid.dart';
import 'package:pubget/features/private_chat/private_chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ✅ نخزن قيمة الاحترام الممنوحة للشخص الآخر لتحديد إذا كان زر المراسلة مفعّلاً
  int? _myRespectGiven;

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

  Widget _buildStatCard(BuildContext context, String label, String value, {bool isPremium = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFD4AF37)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isPremium ? 1.2 : 0.5,
        ),
        boxShadow: isPremium
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
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

  Future<void> _openRespectModal(
    BuildContext context,
    UserModel targetUser,
    String currentUserId,
  ) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final previousValue = await profileProvider.getPreviousRespectValue(
      fromUserId: currentUserId,
      toUserId: targetUser.id,
    );
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RespectModal(
        targetUser: targetUser,
        currentUserId: currentUserId,
        previousValue: previousValue,
      ),
    );
    if (!context.mounted) return;
    _loadMyRespectGiven(currentUserId, targetUser.id, profileProvider);
  }

  // ✅ فتح المحادثة الخاصة — ينشئها إذا لم تكن موجودة، ثم ينتقل إليها
  Future<void> _openPrivateChat(
    BuildContext context,
    String myId,
    UserModel otherUser,
  ) async {
    final privateChatProvider =
        Provider.of<PrivateChatProvider>(context, listen: false);

    // chatId ثابت ومتسق بين الطرفين باستخدام نفس المنطق في RespectLogic
    final chatId = buildPrivateChatId(myId, otherUser.id);
    final ids = [myId, otherUser.id]..sort();

    final actualChatId = await privateChatProvider.createPrivateChat(
      chatId: chatId,
      userA: ids[0],
      userB: ids[1],
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          chatId: actualChatId,
          otherUser: otherUser,
        ),
      ),
    );
  }

  // ✅ تحميل نقاط الاحترام الممنوحة من المستخدم الحالي للشخص المعروض
  Future<void> _loadMyRespectGiven(
    String fromUserId,
    String toUserId,
    ProfileProvider profileProvider,
  ) async {
    final value = await profileProvider.getPreviousRespectValue(
      fromUserId: fromUserId,
      toUserId: toUserId,
    );
    if (mounted) setState(() => _myRespectGiven = value ?? 0);
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

        // ✅ تحميل نقاط الاحترام عند أول بناء للشاشة (للشخص الآخر فقط)
        if (!isMe && myId != null && _myRespectGiven == null) {
          _loadMyRespectGiven(myId, user.id, profileProvider);
        }

        return _buildProfileContent(
          context,
          user,
          profileProvider,
          groupProvider,
          isMe: isMe,
          myId: myId,
        );
      },
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserModel user,
    ProfileProvider profileProvider,
    GroupProvider groupProvider, {
    required bool isMe,
    String? myId,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ زر المراسلة مفعّل إذا منح المستخدم الحالي >= 5 نقاط احترام للشخص الآخر
    final bool canMessage =
        !isMe && (_myRespectGiven ?? 0) >= Limits.fanThreshold;

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
              // ================= Avatar + Username =================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : '',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اسم المستخدم + شارة البريميوم
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.username,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isPremium) ...[
                              const SizedBox(width: 8),
                              const PremiumBadge(size: 18, showText: false),
                            ],
                          ],
                        ),
                        if (user.nickname != null && user.nickname!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              user.nickname!,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // ✅ Stats (نصف العرض) + زر المراسلة (نصف العرض)
                        Row(
                          children: [
                            // ✅ Stats تأخذ نصف العرض
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildStatCard(
                                    context,
                                    'الاحترام',
                                    '${user.totalRespect}',
                                    isPremium: user.isPremium,
                                  ),
                                  _buildStatCard(
                                    context,
                                    'المعجبون',
                                    '${user.fansCount}',
                                    isPremium: user.isPremium,
                                  ),
                                ],
                              ),
                            ),

                            // ✅ زر المراسلة — يظهر فقط للآخرين
                            if (!isMe) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Tooltip(
                                  message: canMessage
                                      ? 'فتح المحادثة'
                                      : 'يجب منح ${Limits.fanThreshold} نقاط احترام أولاً',
                                  child: ElevatedButton.icon(
                                    onPressed: canMessage && myId != null
                                        ? () => _openPrivateChat(context, myId, user)
                                        : null,
                                    icon: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: canMessage
                                          ? Colors.white
                                          : (isDark
                                              ? AppColors.darkTextHint
                                              : Colors.grey),
                                    ),
                                    label: Text(
                                      'مراسلة',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: canMessage
                                            ? Colors.white
                                            : (isDark
                                                ? AppColors.darkTextHint
                                                : Colors.grey),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canMessage
                                          ? AppColors.primary
                                          : (isDark
                                              ? AppColors.darkCard
                                              : Colors.grey.shade200),
                                      disabledBackgroundColor: isDark
                                          ? AppColors.darkCard
                                          : Colors.grey.shade200,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: canMessage
                                              ? AppColors.primary
                                              : (isDark
                                                  ? AppColors.darkBorder
                                                  : Colors.grey.shade400),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                      color: user.isPremium
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    user.bio,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ================= زر منح نقاط الاحترام =================
              if (!isMe && currentUserId != null) ...[
                const Divider(),
                AppButton(
                  text: 'امنح نقاط تقدير للعضو 🌟',
                  onPressed: () {
                    _openRespectModal(context, user, currentUserId);
                  },
                ),
                // ✅ تلميح إذا الزر معطّل
                if (!canMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'امنح ${Limits.fanThreshold} نقاط احترام لفتح المراسلة المباشرة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextHint
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const Divider(),
              ],

              const SizedBox(height: 8),

              // ================= Personal Details =================
              _buildInfoRow(
                context,
                'الانضمام منذ',
                user.createdAt.toLocal().toString().split(' ').first,
              ),
              if (user.age != null)
                _buildInfoRow(context, 'العمر', '${user.age}'),
              if (user.country != null && user.country!.isNotEmpty)
                _buildInfoRow(context, 'البلد', user.country!),

              const SizedBox(height: 16),

              // ================= Favorite Animes =================
              Text(
                'الأنميات المفضلة',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (user.favoriteAnimes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.favoriteAnimes
                      .map(
                        (anime) => Chip(
                          label: Text(anime,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          side: BorderSide(
                            color: user.isPremium
                                ? const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.5)
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          ),
                          labelStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                Text(
                  'لم يتم إضافة أنميات مفضلة بعد',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextHint : Colors.grey,
                  ),
                ),

              const SizedBox(height: 24),

              // ================= Actions =================
              if (isMe)
                AppButton(
                  text: 'تعديل الملف الشخصي',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => EditProfileScreen(user: user)),
                    );
                  },
                ),
              if (isMe) const SizedBox(height: 12),

              AppButton(
                text: isMe
                    ? 'عرض مجموعاتي'
                    : 'عرض مجموعات ${user.username}',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        appBar: AppBar(
                          title: Text(
                              isMe ? 'مجموعاتي' : 'مجموعات ${user.username}'),
                          centerTitle: true,
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                        ),
                        body: FutureBuilder<List<GroupModel>>(
                          future:
                              groupProvider.getUserGroups(userId: user.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              return const LoadingWidget();
                            if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return const EmptyStateWidget(
                                title: 'لا توجد مجموعات',
                                subtitle:
                                    'لم يتم الانضمام إلى أي مجموعة بعد',
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
                                  color: isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          group.imageUrl.isNotEmpty
                                              ? NetworkImage(group.imageUrl)
                                              : null,
                                      child: group.imageUrl.isEmpty
                                          ? const Icon(Icons.groups)
                                          : null,
                                    ),
                                    title: Text(
                                      group.name,
                                      style: TextStyle(
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary),
                                    ),
                                    subtitle: Text(
                                      group.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: isDark
                                          ? AppColors.darkTextHint
                                          : AppColors.lightTextHint,
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

              // ================= Edits Grid =================
              const Divider(),
              const SizedBox(height: 8),
              UserEditsGrid(
                userId: user.id,
                username: user.username,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
