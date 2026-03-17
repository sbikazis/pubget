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
    return MultiProvider(
      providers: [
        // Providers موجودة مسبقًا في main.dart، هنا فقط ربط UI بها
        ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
        ChangeNotifierProvider.value(value: context.read<UserProvider>()),
        ChangeNotifierProvider.value(value: context.read<HomeProvider>()),
        ChangeNotifierProvider.value(value: context.read<GroupProvider>()),
        ChangeNotifierProvider.value(value: context.read<ChatProvider>()),
        ChangeNotifierProvider.value(value: context.read<GameProvider>()),
        ChangeNotifierProvider.value(value: context.read<ProfileProvider>()),
        ChangeNotifierProvider.value(value: context.read<PrivateChatProvider>()),
        ChangeNotifierProvider.value(value: context.read<SettingsProvider>()),
        ChangeNotifierProvider.value(value: context.read<NotificationsProvider>()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Pubget',
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (_) => const SplashScreen(),
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
}