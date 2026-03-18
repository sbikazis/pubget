import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

import '../../services/local/local_storage_service.dart';

import '../auth/login_screen.dart';
import '../auth/user_info_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // تهيئة التخزين المحلي
      await LocalStorageService.instance.init();

      // تأخير بسيط
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      // إذا لم يكن مسجل دخول
      if (!authProvider.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // تحميل بيانات المستخدم
      final userId = authProvider.user!.id;

      await userProvider.loadUser(userId);

      if (!mounted) return;

      // إذا لا توجد بيانات
      if (userProvider.currentUser == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
        return;
      }

      // الدخول إلى التطبيق
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      // 🔥 مهم جداً: منع الشاشة السوداء
      debugPrint("Splash Error: $e");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "⛩️",
          style: TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}
