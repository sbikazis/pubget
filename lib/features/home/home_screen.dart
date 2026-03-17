// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/loading_widget.dart';
import '../home/promoted_groups_section.dart';
import 'package:pubget/features/home/my_group_section.dart';
import '../../widgets/empty_state_widget.dart';

// added imports for direct navigation
import '../home/search_screen.dart';
import 'package:pubget/features/home/notifications_screen.dart';
import '../groups/create_group_screen.dart';
import 'package:pubget/features/profile/profile_sceen.dart';
import '../private_chat/private_chats_list_screen.dart';
import '../groups/group_details_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeProvider _homeProvider;
  late AuthProvider _authProvider;
  bool _initialized = false;
  bool _isRefreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _homeProvider = context.read<HomeProvider>();
      _authProvider = context.read<AuthProvider>();

      final currentUser = _authProvider.user;
      if (currentUser != null) {
        _homeProvider.initialize(currentUser: currentUser);
      }

      _initialized = true;
    }
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isRefreshing = true);
    try {
      await _homeProvider.refresh(user);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );

  void _openNotifications() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );

  void _openCreateGroup() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
      );

  void _openProfile() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );

  void _openPrivateChats() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivateChatsListScreen()),
      );

  void _openSuggested() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );

  Widget _buildDrawer(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.username ?? 'مستخدم'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user != null && user.avatarUrl.isNotEmpty
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: (user == null || user.avatarUrl.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('حسابي'),
              onTap: () {
                Navigator.of(context).pop();
                _openProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('الدردشات الخاصة'),
              onTap: () {
                Navigator.of(context).pop();
                _openPrivateChats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('مجموعاتي'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('المجموعات المقترحة'),
              onTap: () {
                Navigator.of(context).pop();
                _openSuggested();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.of(context).pop();
                context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedGroupsSection() {
    final suggested = _homeProvider.promotedGroups;
    if (suggested.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: EmptyStateWidget(
          title: 'لا توجد اقتراحات حالياً',
          subtitle: 'سنقترح مجموعات بناءً على نشاطك لاحقاً.',
          icon: Icons.lightbulb_outline,
          onActionPressed: _openSuggested,
          actionLabel: 'استعرض الاقتراحات',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('مقترحات لك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: suggested.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final g = suggested[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailsScreen(groupId: g.id),
                  ),
                ),
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: g.isPromoted
                            ? AppColors.promotedBorder
                            : Colors.transparent,
                        width: g.isPromoted ? 1.4 : 0),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: g.imageUrl.isNotEmpty
                              ? Image.network(g.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: AppColors.lightCard))
                              : Container(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: Text(g.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(g.type.label,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPrivateChatsPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('الدردشات الخاصة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              TextButton(
                onPressed: _openPrivateChats,
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('لا توجد محادثات بعد'),
              subtitle: const Text('ابدأ محادثة خاصة مع أحد الأصدقاء'),
              trailing: IconButton(
                icon: const Icon(Icons.chat),
                onPressed: _openPrivateChats,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final homeProvider = context.watch<HomeProvider>();

    final user = authProvider.user;
    final isLoading = homeProvider.isLoading || authProvider.isLoading;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Pubget'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'القائمة',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'بحث',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: _openNotifications,
            tooltip: 'الإشعارات',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    user != null && user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                child: (user == null || user.avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null &&
                                        user.username.isNotEmpty
                                    ? 'مرحباً، ${user.username}'
                                    : 'مرحباً بك في Pubget',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                  'اكتشف مجموعات جديدة أو ادخل لمجموعاتك',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _homeProvider
                              .tryShowMorningAd(
                                  isPremium: user
                                          ?.subscriptionType.name ==
                                      'premium'),
                          icon:
                              const Icon(Icons.campaign_outlined),
                          tooltip: 'عرض إعلان صباحي',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const PromotedGroupsSection(),
                  const SizedBox(height: 12),
                  _buildSuggestedGroupsSection(),
                  const SizedBox(height: 8),
                  _buildPrivateChatsPreview(),
                  const SizedBox(height: 8),
                  const MyGroupsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (isLoading || _isRefreshing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                    child: LoadingWidget(
                        message: 'جاري التحميل...')),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateGroup,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('إنشاء مجموعة'),
      ),
    );
  }
}