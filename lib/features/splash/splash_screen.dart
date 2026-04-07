// lib/features/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/local/local_storage_service.dart';

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
      debugPrint("🔹 Splash: Starting Initialization...");

      // 1. تهيئة التخزين المحلي
      await LocalStorageService.instance
          .init()
          .timeout(const Duration(seconds: 5));
      debugPrint("✅ LocalStorage initialized");

      // تأخير بسيط لإعطاء هيبة لشعار البوابة اليابانية ⛩️
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();

      // 2. التحقق من حالة المستخدم (جلسة العمل)
      debugPrint("🔹 Splash: Checking auth state...");
      await authProvider.checkAuthState();

      if (!mounted) return;

      // 3. إذا كان المستخدم مسجلاً، نقوم بتحميل بياناته كاملة قبل الدخول
      if (authProvider.isLoggedIn && authProvider.user != null) {
        try {
          final userId = authProvider.user!.id;
          debugPrint("🔹 Splash: Pre-loading user data for: $userId");
          
          await userProvider
              .loadUser(userId)
              .timeout(const Duration(seconds: 5));
          
          debugPrint("✅ User data loaded");
        } catch (e) {
          debugPrint("⚠️ Splash: LoadUser Error (Non-critical): $e");
        }
      }

      // =========================================================
      // 🔥 ملاحظة هامة: لا يوجد Navigator.push هنا!
      // بمجرد انتهاء التحميل، الـ AuthProvider سيغير isLoading إلى false.
      // الـ Consumer في ملف app.dart سيشعر بهذا التغيير ويقوم بتبديل
      // شاشة الـ Splash بالصفحة المناسبة (Home أو Login) تلقائياً.
      // =========================================================
      debugPrint("✅ Splash: Initialization complete.");

    } catch (e, st) {
      debugPrint("🔥 Splash Critical Error: $e");
      debugPrint("$st");
      
      // في حالة الخطأ الكارثي، نجعل التطبيق يتوقف عن التحميل ليقرر app.dart الوجهة
      if (mounted) {
        context.read<AuthProvider>().clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تصميم الواجهة كما وصفته: البوابة اليابانية في المنتصف مع طابع الفخامة
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "⛩️",
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            // مؤشر تحميل هادئ يتماشى مع ألوان التطبيق
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}