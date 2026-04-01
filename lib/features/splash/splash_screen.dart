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

      await LocalStorageService.instance
          .init()
          .timeout(const Duration(seconds: 5));

      debugPrint("✅ LocalStorage initialized");

      // تأخير بسيط لإظهار الشعار
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      // ===============================
      // 🔥 أهم خطوة: تحميل حالة تسجيل الدخول
      // ===============================
      debugPrint("🔹 Checking auth state...");
      await authProvider.checkAuthState();

      if (!mounted) return;

      // ===============================
      // ❌ المستخدم غير مسجل
      // ===============================
      if (!authProvider.isLoggedIn || authProvider.user == null) {
        debugPrint("❌ User not logged in → LoginScreen");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // ===============================
      // 🔄 تحميل بيانات المستخدم
      // ===============================
      try {
        final userId = authProvider.user!.id;

        debugPrint("🔹 Loading user with ID: $userId");

        await userProvider
            .loadUser(userId)
            .timeout(const Duration(seconds: 5));

        debugPrint("✅ User loaded successfully");

      } catch (e) {
        debugPrint("⚠️ LoadUser Error: $e");
      }

      if (!mounted) return;

      // ===============================
      // ❌ الملف غير مكتمل
      // ===============================
      if (userProvider.currentUser == null ||
          !(userProvider.currentUser!.isProfileCompleted)) {
        debugPrint("❌ Profile incomplete → UserInfoScreen");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
        return;
      }

      // ===============================
      // ✅ كل شيء جاهز → Home
      // ===============================
      debugPrint("🏠 Redirecting to HomeScreen");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

    } catch (e, st) {
      debugPrint("🔥 Splash Error: $e");
      debugPrint("$st");

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