// lib/features/splash/splash_screen.dart
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
      debugPrint("🔹 Initializing LocalStorage...");
      await LocalStorageService.instance.init();
      debugPrint("✅ LocalStorage initialized");

      // تأخير بسيط لإظهار الشعار
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      debugPrint("🔹 Checking login status...");
      if (!authProvider.isLoggedIn || authProvider.user == null) {
        debugPrint("❌ User not logged in, redirecting to LoginScreen");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // تحميل بيانات المستخدم مع حماية من الأخطاء
      try {
        final userId = authProvider.user!.id;
        debugPrint("🔹 Loading user with ID: $userId");
        await userProvider.loadUser(userId);
        debugPrint("✅ User loaded successfully");
      } catch (e) {
        debugPrint("⚠️ LoadUser Error: $e");
      }

      if (!mounted) return;

      if (userProvider.currentUser == null) {
        debugPrint("❌ User data missing, redirecting to UserInfoScreen");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
        return;
      }

      // الانتقال إلى الصفحة الرئيسية
      debugPrint("🏠 All set, redirecting to HomeScreen");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

    } catch (e, st) {
      debugPrint("🔥 Splash Error: $e");
      debugPrint("$st");

      // fallback: الانتقال إلى LoginScreen لضمان عدم ظهور الشاشة السوداء
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        alignment: Alignment.center,
        child: const Text(
          "⛩️",
          style: TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}