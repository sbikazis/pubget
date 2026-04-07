import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';
import '../auth/user_info_screen.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final List<String> slogans = [
    "ابدأ رحلتك في عالم الأنمي",
    "شارك شغفك وكون صداقات",
    "انضم لأقوى مجتمعات الأنمي",
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

  void _register(AuthProvider authProvider) async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كلمة المرور وتأكيدها غير متطابقين")),
      );
      return;
    }

    await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      
    );

    if (!mounted) return;

    if (authProvider.user != null) {
      // إذا بيانات المستخدم غير مكتملة
      if (authProvider.user!.nickname == null || authProvider.user!.nickname!.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  void _registerWithGoogle(AuthProvider authProvider) async {
    await authProvider.signInWithGoogle();

    if (!mounted) return;

    if (authProvider.user != null) {
      if (authProvider.user!.nickname == null || authProvider.user!.nickname!.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  slogans[_currentSloganIndex],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
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

              const SizedBox(height: 16),

              // تأكيد كلمة المرور
              AppTextField(
                controller: _confirmPasswordController,
                label: "تأكيد كلمة المرور",
                placeholder: "••••••••",
                isPassword: true,
                prefixIcon: Icons.lock_outline,
              ),

              const SizedBox(height: 24),

              // زر إنشاء حساب
              AppButton(
                text: "إنشاء حساب",
                isLoading: authProvider.isLoading,
                onPressed: () => _register(authProvider),
              ),

              const SizedBox(height: 16),

              // زر Google
              AppButton(
                text: "التسجيل عبر Google",
                isLoading: authProvider.isLoading,
                icon: Icons.login,
                onPressed: () => _registerWithGoogle(authProvider),
              ),

              const SizedBox(height: 16),

              // رابط العودة لتسجيل الدخول
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  "لدي حساب بالفعل / تسجيل الدخول",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // رسالة خطأ
              if (authProvider.error != null)
                Text(
                  authProvider.error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              // Loading overlay
              if (authProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LoadingWidget(message: "جارٍ إنشاء الحساب..."),
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
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }
}