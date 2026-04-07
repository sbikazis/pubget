// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ================== PROVIDERS ==================
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/home_provider.dart';
import 'providers/group_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/game_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/private_chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notifications_provider.dart';

// ================== SERVICES ==================
import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_service.dart';
import 'services/firebase/storage_service.dart';
import 'services/local/local_storage_service.dart';
import 'services/monetization/ad_service.dart';
import 'services/monetization/promotion_service.dart';

// ================== LOGIC ==================
import 'core/logic/group_join_validator.dart';

// ================== THEMES ==================
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';

// ================== SCREENS ==================
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/user_info_screen.dart';
import 'features/auth/terms_screen.dart';
import 'features/home/home_screen.dart';

class PubgetApp extends StatelessWidget {
  const PubgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final storage = StorageService();
    final localStorage = LocalStorageService.instance;

    return MultiProvider(
      providers: [
        // ================= SERVICES =================
        Provider(create: (_) => firestore),
        Provider(create: (_) => storage),
        Provider(create: (_) => localStorage),
        Provider(create: (_) => AuthService(firestore: firestore)),
        Provider(create: (_) => PromotionService(firestore)),
        Provider(create: (_) => AdService(localStorage)),
        Provider(create: (_) => GroupJoinValidator(firestoreService: firestore)),

        // ================= PROVIDERS =================
        
        // ⚠️ التعديل: تم نقل UserProvider للأعلى لأن AuthProvider يحتاجه الآن
        ChangeNotifierProvider(
          create: (context) => UserProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) {
            // ✅ الإصلاح: تمرير المعامل الثاني (UserProvider) المطلوب
            final authProvider = AuthProvider(
              context.read<AuthService>(),
              context.read<UserProvider>(), 
            );
            // ملاحظة: listenToAuthState يتم استدعاؤه تلقائياً داخل الـ Constructor الآن
            return authProvider;
          },
        ),

        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),

        ChangeNotifierProvider(
          create: (context) => HomeProvider(
            firestore: context.read<FirestoreService>(),
            promotionService: context.read<PromotionService>(),
            adService: context.read<AdService>(),
            joinValidator: context.read<GroupJoinValidator>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => GroupProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            firestoreService: context.read<FirestoreService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => GameProvider(
            firestore: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => ProfileProvider(
            context.read<FirestoreService>(),
            context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => PrivateChatProvider(
            firestoreService: context.read<FirestoreService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => NotificationsProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
      ],

      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Pubget',
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            // 🔥 الإصلاح الجوهري للموجه الذكي (Home Logic)
            home: _getHome(auth),

            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/user_info': (_) => const UserInfoScreen(),
              '/terms': (_) => const TermsScreen(),
              '/home': (_) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }

  /// دالة الموجه لتبسيط كود MaterialApp
  Widget _getHome(AuthProvider auth) {
    // 1. إذا كان التطبيق لا يزال يتحقق من حالة Firebase
    if (auth.isLoading) {
      return const SplashScreen();
    }

    // 2. إذا وجد مستخدم مسجل الدخول
    if (auth.isLoggedIn) {
      // نتحقق هل أكمل بيانات الملف الشخصي أم لا
      if (auth.user?.isProfileCompleted == true) {
        return const HomeScreen();
      } else {
        return const UserInfoScreen();
      }
    }

    // 3. إذا لم يوجد تسجيل دخول، نذهب لصفحة الدخول
    return const LoginScreen();
  }
}