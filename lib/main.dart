// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Provider
import 'package:provider/provider.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';

// =================== SERVICES ===================
import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_service.dart';
import 'services/firebase/storage_service.dart';

import 'package:pubget/services/monetization/promotion_service.dart';
import 'package:pubget/services/monetization/ad_service.dart';
import 'services/local/local_storage_service.dart';
import 'package:pubget/core/logic/group_join_validator.dart';

// =================== PROVIDERS ===================
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/home_provider.dart';
import 'providers/group_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/game_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/private_chat_provider.dart';
import 'providers/settings_provider.dart';
import 'package:pubget/providers/notifications_provider.dart';

// =================== THEMES ===================
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const PubgetApp());
}

class PubgetApp extends StatelessWidget {
  const PubgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        /// ================= SERVICES =================

        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),

        Provider<StorageService>(
          create: (_) => StorageService(),
        ),

        Provider<LocalStorageService>(
          create: (_) => LocalStorageService.instance,
        ),

        Provider<AuthService>(
          create: (context) => AuthService(
            firestore: context.read<FirestoreService>(),
          ),
        ),

        Provider<PromotionService>(
          create: (context) =>
              PromotionService(context.read<FirestoreService>()),
        ),

        Provider<AdService>(
          create: (context) =>
              AdService(context.read<LocalStorageService>()),
        ),

        Provider<GroupJoinValidator>(
  create: (context) => GroupJoinValidator(
    firestoreService: context.read<FirestoreService>(),
  ),
),

        /// ================= CORE PROVIDERS =================

        ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(context.read<AuthService>()),
        ),

        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),

        /// ================= FEATURE PROVIDERS =================

        ChangeNotifierProvider<HomeProvider>(
          create: (context) => HomeProvider(
            firestore: context.read<FirestoreService>(),
            promotionService: context.read<PromotionService>(),
            adService: context.read<AdService>(),
            joinValidator: context.read<GroupJoinValidator>(),
          ),
        ),

        ChangeNotifierProvider<GroupProvider>(
          create: (context) => GroupProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider<ChatProvider>(
          create: (context) => ChatProvider(
            firestoreService: context.read<FirestoreService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider<GameProvider>(
          create: (context) => GameProvider(
            firestore: context.read<FirestoreService>(),
          ),
        ),

        ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(
            context.read<FirestoreService>(),
            context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider<PrivateChatProvider>(
          create: (context) => PrivateChatProvider(
            firestoreService: context.read<FirestoreService>(),
            storageService: context.read<StorageService>(),
          ),
        ),

        ChangeNotifierProvider<NotificationsProvider>(
          create: (context) => NotificationsProvider(
            firestoreService: context.read<FirestoreService>(),
          ),
        ),
      ],

      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Pubget',

            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode:
                settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            
          );
        },
      ),
    );
  }
}