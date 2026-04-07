import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../auth/register_screen.dart';
import '../auth/user_info_screen.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<String> slogans = [
    "شارك شغفك بالأنمي",
    "اكتشف مجتمعك",
    "أنشئ عالمك الخاص",
  ];

  int _currentSloganIndex = 0;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);

    _startSloganRotation();
  }

  void _startSloganRotation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _currentSloganIndex = (_currentSloganIndex + 1) % slogans.length;
      });

      _animController.forward(from: 0).then((_) => _startSloganRotation());
    });
  }

  // =========================================================
  // LOGIN LOGIC (تمت إزالة context من البارامترات)
  // =========================================================
  void _login(AuthProvider authProvider) async {
    await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return; // صمام الأمان لمنع الخطأ الأحمر

    if (authProvider.user != null) {
      final nextScreen = (authProvider.user!.nickname == null || authProvider.user!.nickname!.isEmpty)
          ? const UserInfoScreen()
          : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
  }

  // =========================================================
  // GOOGLE LOGIN LOGIC (الإصلاح الجذري للكارثة)
  // =========================================================
  void _loginWithGoogle(AuthProvider authProvider) async {
    await authProvider.signInWithGoogle();

    if (!mounted) return; // صمام الأمان: التأكد أن الشاشة لا تزال نشطة

    if (authProvider.user != null) {
      final nextScreen = (authProvider.user!.nickname == null || authProvider.user!.nickname!.isEmpty)
          ? const UserInfoScreen()
          : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        // 🔥 الإصلاح: إضافة SingleChildScrollView لمنع الـ Overflow عند ظهور الكيبورد
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار التطبيق
              const Center(
                child: Text(
                  "⛩️",
                  style: TextStyle(fontSize: 64),
                ),
              ),

              const SizedBox(height: 24),

              // العبارات التحفيزية
              SizedBox(
                height: 30, // تثبيت الارتفاع لمنع القفز عند تغيير النص
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Text(
                    slogans[_currentSloganIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // البريد الإلكتروني
              AppTextField(
                controller: _emailController,
                label: "البريد الإلكتروني",
                placeholder: "example@mail.com",
                prefixIcon: Icons.email,
              ),

              const SizedBox(height: 16),

              // كلمة المرور
              AppTextField(
                controller: _passwordController,
                label: "كلمة المرور",
                placeholder: "••••••••",
                isPassword: true,
                prefixIcon: Icons.lock,
              ),

              const SizedBox(height: 24),

              // زر تسجيل الدخول
              AppButton(
                text: "تسجيل الدخول",
                isLoading: authProvider.isLoading,
                onPressed: () => _login(authProvider),
              ),

              const SizedBox(height: 16),

              // زر Google
              AppButton(
                text: "تسجيل الدخول عبر Google",
                isLoading: authProvider.isLoading,
                icon: Icons.login,
                onPressed: () => _loginWithGoogle(authProvider),
              ),

              const SizedBox(height: 16),

              // رابط إنشاء حساب
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  "ليس لدي حساب / إنشاء واحد",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // رسالة خطأ
              if (authProvider.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    authProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Loading overlay
              if (authProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LoadingWidget(message: "جارٍ تسجيل الدخول..."),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }
}