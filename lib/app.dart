// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'providers/edits_provider.dart';
import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_service.dart';
import 'services/firebase/storage_service.dart';
import 'services/local/local_storage_service.dart';
import 'services/monetization/ad_service.dart';
import 'services/monetization/promotion_service.dart';
import 'core/logic/group_join_validator.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/user_info_screen.dart';
import 'features/auth/terms_screen.dart';
import 'features/home/home_screen.dart';
import 'features/edits/edits_screen.dart';

class PubgetApp extends StatefulWidget {
  const PubgetApp({super.key});

  @override
  State<PubgetApp> createState() => _PubgetAppState();
}

class _PubgetAppState extends State<PubgetApp> {
  String? _lastRegisteredUserId;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final storage = StorageService();
    final localStorage = LocalStorageService.instance;

    return MultiProvider(
      providers: [
        Provider(create: (_) => firestore),
        Provider(create: (_) => storage),
        Provider(create: (_) => localStorage),
        Provider(create: (_) => AuthService(firestore: firestore)),
        Provider(create: (_) => PromotionService(firestore)),
        Provider(create: (_) => AdService(localStorage)),
        Provider(create: (_) => GroupJoinValidator(firestoreService: firestore)),
        ChangeNotifierProvider(
          create: (context) => UserProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            context.read<AuthService>(),
            context.read<UserProvider>(),
          ),
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
        ChangeNotifierProvider(
          create: (_) => EditsProvider(),
        ),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          if (auth.isLoggedIn &&
              auth.user != null &&
              _lastRegisteredUserId != auth.user!.id) {
            _lastRegisteredUserId = auth.user!.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(seconds: 3), () {
                context
                    .read<NotificationsProvider>()
                    .registerToken(auth.user!.id);
              });
              context.read<EditsProvider>().loadSeenIds();
            });
          }

          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Pubget',
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: _getHome(auth),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/user_info': (_) => const UserInfoScreen(),
              '/terms': (_) => const TermsScreen(),
              '/home': (_) => const HomeScreen(),
            },
            builder: (context, child) {
              return Consumer<EditsProvider>(
                builder: (context, editsProvider, _) {

                  // ── الانتقال التلقائي بعد اكتمال النشر
                  if (editsProvider.lastUploadedEdit != null) {
                    final uploadedEdit = editsProvider.lastUploadedEdit!;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // ← تصفير أولاً بدون notify لمنع إعادة الدخول
                      editsProvider.clearLastUploadedEdit();

                      // ← ضع الإيديت في أول القائمة
                      editsProvider.prependEdit(uploadedEdit);

                      // ← انتقل لـ EditsScreen عادياً بدون initialEdits
                      // هكذا المستخدم يرى الإيديت الجديد أولاً ويكمل للقائمة العامة
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => const EditsScreen(),
                        ),
                      );
                    });
                  }

                  return Stack(
                    children: [
                      child!,

                      // ── شريط "جاري النشر" — عالمي يظهر أينما كان المستخدم
                      if (editsProvider.isUploading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: SafeArea(
                              bottom: false,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'جاري نشر الإيديت...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _getHome(AuthProvider auth) {
    if (auth.isLoading) return const SplashScreen();
    if (auth.isLoggedIn) {
      return (auth.user?.isProfileCompleted == true)
          ? const HomeScreen()
          : const UserInfoScreen();
    }
    return const LoginScreen();
  }
}
