import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart'; // 🔥 مضاف للمزامنة
import '../../providers/chat_provider.dart'; // 🔥 مضاف للعدادات
import '../../providers/private_chat_provider.dart'; // 🔥 مضاف للعدادات
import '../../providers/notifications_provider.dart';
import '../../models/notification_model.dart';
import '../../widgets/loading_widget.dart';
import '../home/promoted_groups_section.dart';
import 'package:pubget/features/home/my_group_section.dart';

// added imports for direct navigation
import '../home/search_screen.dart';
import 'package:pubget/features/home/notifications_screen.dart';
import '../groups/create_group_screen.dart';
import 'package:pubget/features/profile/profile_sceen.dart';
import '../private_chat/private_chats_list_screen.dart';

import '../settings/settings_screen.dart';
import 'package:pubget/models/user_model.dart';
import '../../core/constants/limits.dart'; // ✅ مضاف للوصول للشارة
import 'package:pubget/features/settings/premium_details_screen.dart'; // ✅ مضاف لفتح صفحة الترقية

// ✅ استيراد خدمة الإعلانات لتفعيل منطق الأشباح
import '../../services/monetization/ad_service.dart';

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

  // ✅ متغيرات محلية للتحكم الفوري في العدادات (Optimistic UI)
  bool _hidePrivateBadge = false;
  bool _hideGroupsBadge = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _homeProvider = context.read<HomeProvider>();
      _authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      final currentUser = _authProvider.user;
      if (currentUser != null) {
        _homeProvider.initialize(currentUser: currentUser);
        // 🔥 ضمان مزامنة بيانات المستخدم الحالي عند فتح التطبيق
        userProvider.syncUser(currentUser);

        // 🚀 تفعيل إعلان الصباح (منطق الأشباح) عند فتح التطبيق لأول مرة في اليوم
        // يتم تنفيذه بعد رسم الواجهة لضمان عدم تعليق التطبيق
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final adService = context.read<AdService>();
          adService.tryShowMorningAd(isPremium: currentUser.isPremium);
        });
      }

      _initialized = true;
    }
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isRefreshing = false); // إعادة التعيين عند التحديث اليدوي
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

  // ✅ دالة لفتح صفحة البريميوم
  void _openPremiumDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumDetailsScreen(),
    );
  }

  // =========================================================
  // ✅ بناء أيقونة مع عداد (Badge) للـ Bottom Bar
  // =========================================================
  Widget _buildTabIcon(IconData icon, int count, bool forceHide) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0 && !forceHide) // يتم الإخفاء إذا تحقق شرط التصفير الفوري
          Positioned(
            right: -6,
            top: -3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser; // استخدام UserProvider للمزامنة الفورية
    final bool isPremium = user?.isPremium ?? false;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Row(
                children: [
                  Text(user?.username ?? 'مستخدم'),
                  if (isPremium) ...[
                    const SizedBox(width: 5),
                    Text(Limits.premiumBadge, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
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
                _onTabTapped(3); // تفعيل تصفير العداد عند الانتقال من القائمة
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('مجموعاتي'),
              onTap: () {
                Navigator.of(context).pop();
                _onTabTapped(1);
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

            // ✅ إضافة زر الترقية الفاخر في القائمة
            ListTile(
              leading: Icon(
                isPremium ? Icons.verified : Icons.workspace_premium,
                color: isPremium ? Colors.teal : Colors.amber[700],
              ),
              title: Text(
                isPremium ? 'عضوية Premium نشطة' : 'ترقية إلى Premium',
                style: TextStyle(
                  color: isPremium ? Colors.teal : Colors.amber[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: isPremium ? const Icon(Icons.check_circle, size: 18, color: Colors.teal) : null,
              onTap: isPremium ? null : () {
                Navigator.of(context).pop();
                _openPremiumDetails();
              },
            ),

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

  Widget _buildHomeDiscoveryContent(UserModel? user) {
    // نستخدم النسخة من UserProvider لضمان ظهور الشارة فوراً
    final currentUser = context.watch<UserProvider>().currentUser;
    final bool isPremium = currentUser?.isPremium ?? false;

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
                        Row(
                          children: [
                            Text(
                              currentUser != null && currentUser.username.isNotEmpty
                                  ? 'مرحباً، ${currentUser.username}'
                                  : 'مرحباً بك في Pubget',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 6),
                              Text(Limits.premiumBadge, style: const TextStyle(fontSize: 16)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('اكتشف مجموعات جديدة الآن',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  // ✅ زر عرض إعلان يدوي (للاختبار فقط)
                  IconButton(
                    onPressed: () {
                      final adService = context.read<AdService>();
                      adService.tryShowMorningAd(isPremium: isPremium);
                    },
                    icon: const Icon(Icons.campaign_outlined),
                    tooltip: 'عرض إعلان تجريبي',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const PromotedGroupsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String userId) {
    final notificationProvider = context.read<NotificationsProvider>();
    return StreamBuilder<List<NotificationModel>>(
      stream: notificationProvider.streamNotifications(userId),
      initialData: const [], // منع الوميض عند التحميل
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

  // ✅ دالة معالجة الضغط على التبويب لتصفير العداد فورياً
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 3) _hidePrivateBadge = true; // تصفير الخاص فوراً
      if (index == 1 || index == 2) _hideGroupsBadge = true; // تصفير المجموعات فوراً
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final homeProvider = context.watch<HomeProvider>();
    final chatProvider = context.read<ChatProvider>();
    final privateChatProvider = context.read<PrivateChatProvider>();
    final user = context.watch<UserProvider>().currentUser; // المزامنة مع UserProvider

    final isLoading = homeProvider.isLoading || authProvider.isLoading;
    final bool isPremium = user?.isPremium ?? false;

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
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  CircleAvatar(
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
                  if (isPremium)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Text(Limits.premiumBadge, style: const TextStyle(fontSize: 12)),
                    ),
                ],
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
              _buildHomeDiscoveryContent(user),
              const MyGroupsSection(showCreatedOnly: true),
              const MyGroupsSection(showJoinedOnly: true),
              const PrivateChatsListScreen(),
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
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'اكتشف'),
         
          BottomNavigationBarItem(
            icon: (user == null)
                ? const Icon(Icons.admin_panel_settings)
                : StreamBuilder<int>(
                    stream: chatProvider.streamTotalGroupsUnreadCount(
                      userId: user.id,
                      groups: homeProvider.myGroups,
                    ),
                    initialData: 0,
                    builder: (context, snapshot) => _buildTabIcon(Icons.admin_panel_settings, snapshot.data ?? 0, _hideGroupsBadge),
                  ),
            label: 'مجموعاتي'
          ),

          BottomNavigationBarItem(
            icon: (user == null)
                ? const Icon(Icons.group)
                : StreamBuilder<int>(
                    stream: chatProvider.streamTotalGroupsUnreadCount(
                      userId: user.id,
                      groups: homeProvider.joinedGroups,
                    ),
                    initialData: 0,
                    builder: (context, snapshot) => _buildTabIcon(Icons.group, snapshot.data ?? 0, _hideGroupsBadge),
                  ),
            label: 'منضم لها',
          ),

          BottomNavigationBarItem(
            icon: (user == null)
                ? const Icon(Icons.chat_bubble)
                : StreamBuilder<int>(
                    stream: privateChatProvider.streamAllPrivateUnreadCount(user.id),
                    initialData: 0,
                    builder: (context, snapshot) => _buildTabIcon(Icons.chat_bubble, snapshot.data ?? 0, _hidePrivateBadge),
                  ),
            label: 'الخاص',
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
