// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart'; // 🔥 مضاف للمزامنة
import '../../providers/notifications_provider.dart'; 
import '../../models/notification_model.dart'; 
import '../../widgets/loading_widget.dart';
import '../home/promoted_groups_section.dart';
import 'package:pubget/features/home/my_group_section.dart';


// added imports for direct navigation
import '../home/search_screen.dart';
import 'package:pubget/features/home/notifications_screen.dart';
import '../groups/create_group_screen.dart';
import 'package:pubget/features/profile/profile_sceen.dart'; // تأكد من صحة الإملاء profile_screen
import '../private_chat/private_chats_list_screen.dart';

import '../settings/settings_screen.dart';
import 'package:pubget/models/user_model.dart';

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
  
  // التعديل: متغير لمتابعة التبويب المختار
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _homeProvider = context.read<HomeProvider>();
      _authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>(); // 🔥 مضاف

      final currentUser = _authProvider.user;
      if (currentUser != null) {
        _homeProvider.initialize(currentUser: currentUser);
        // 🔥 ضمان مزامنة بيانات المستخدم الحالي عند فتح التطبيق
        userProvider.syncUser(currentUser); 
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

  // 🔥 التعديل: تمرير userId كاحتياط لضمان تحميل البيانات في ProfileScreen
  void _openProfile() {
    final currentUser = context.read<AuthProvider>().user;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: currentUser?.id),
      ),
    );
  }

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
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                child: (user == null || user.avatarUrl.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
              ),
              decoration: const BoxDecoration(
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
                setState(() => _selectedIndex = 1); // الانتقال لتبويب مجموعاتي
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

  // التعديل: واجهة الصفحة الرئيسية الموحدة (التبويب الأول)
  Widget _buildHomeDiscoveryContent(UserModel? user) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user != null && user.username.isNotEmpty
                              ? 'مرحباً، ${user.username}'
                              : 'مرحباً بك في Pubget',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('اكتشف مجموعات جديدة الآن',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _homeProvider.tryShowMorningAd(
                        isPremium: user?.subscriptionType.name == 'premium'),
                    icon: const Icon(Icons.campaign_outlined),
                    tooltip: 'عرض إعلان صباحي',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // هنا المحرك الأساسي: القائمة المدمجة (مروجة + مقترحة) بالهوية الجديدة
            const PromotedGroupsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 🔥 التعديل: Widget مخصص لأيقونة الإشعارات مع التنبيه البصري
  Widget _buildNotificationIcon(String userId) {
    final notificationProvider = context.read<NotificationsProvider>();
    return StreamBuilder<List<NotificationModel>>(
      stream: notificationProvider.streamNotifications(userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: _openNotifications,
              tooltip: 'الإشعارات',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
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
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'القائمة',
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'بحث',
          ),
          // 🔥 التعديل: استبدال الأيقونة الثابتة بالـ Widget التفاعلي الجديد
          if (user != null)
            _buildNotificationIcon(user.id)
          else
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
                backgroundImage: user != null && user.avatarUrl.isNotEmpty
                    ? NetworkImage(user.avatarUrl)
                    : null,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
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
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeDiscoveryContent(user), // تبويب 1: اكتشاف (النسخة المحدثة)
              const MyGroupsSection(showCreatedOnly: true), // تبويب 2: مجموعاتي
              const MyGroupsSection(showJoinedOnly: true),  // تبويب 3: منضم إليها
              const PrivateChatsListScreen(),              // تبويب 4: خاص
            ],
          ),
          if (isLoading || _isRefreshing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: LoadingWidget(message: 'جاري التحميل...')),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'اكتشف'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'مجموعاتي'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'منضم لها'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'الخاص'),
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