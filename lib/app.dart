import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
import 'providers/chat_background_provider.dart';
import 'providers/deep_link_provider.dart';
import 'providers/store_provider.dart';

import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_service.dart';
import 'services/firebase/storage_service.dart';
import 'services/local/local_storage_service.dart';
import 'services/monetization/ad_service.dart';
import 'services/monetization/promotion_service.dart';

import 'core/logic/group_join_validator.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/utils/notification_service.dart';
import 'core/constants/notification_channels.dart';

import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/user_info_screen.dart';
import 'features/auth/terms_screen.dart';
import 'features/home/home_screen.dart';
import 'features/edits/edits_screen.dart';
import 'features/groups/group_details_screen.dart';
import 'features/groups/chat/chat_screen.dart';
import 'features/groups/join_requests_screen.dart';
import 'features/private_chat/private_chat_screen.dart';
import 'models/member_model.dart';
import 'models/user_model.dart';
import 'services/deep_link_service.dart';
import 'package:pubget/providers/sticker_provider.dart';
import 'package:pubget/services/firebase/sticker_service.dart';

class PubgetApp extends StatefulWidget {
  const PubgetApp({super.key});

  @override
  State<PubgetApp> createState() => _PubgetAppState();
}

class _PubgetAppState extends State<PubgetApp> {
  String? _lastRegisteredUserId;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ✅ تسجيل الـ callbacks مرة واحدة فقط
  bool _notificationCallbacksRegistered = false;

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
        Provider(
          create: (_) => GroupJoinValidator(firestoreService: firestore),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              UserProvider(firestoreService: context.read<FirestoreService>()),
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
          create: (context) =>
              GroupProvider(firestoreService: context.read<FirestoreService>()),
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
            userProvider: context.read<UserProvider>(),
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
        ChangeNotifierProxyProvider<UserProvider, StoreProvider>(
          create: (context) => StoreProvider(
            userProvider: Provider.of<UserProvider>(context, listen: false),
          ),
          update: (context, userProvider, storeProvider) =>
              StoreProvider(userProvider: userProvider),
        ),
        ChangeNotifierProvider(create: (_) => EditsProvider()),
        ChangeNotifierProvider(create: (_) => ChatBackgroundProvider()),
        ChangeNotifierProvider(create: (_) => DeepLinkProvider()),
        ChangeNotifierProvider(
          create: (_) => StickerProvider(StickerService()),
        ),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          // ✅ تسجيل FCM Token عند تسجيل الدخول
          if (auth.isLoggedIn &&
              auth.user != null &&
              _lastRegisteredUserId != auth.user!.id) {
            _lastRegisteredUserId = auth.user!.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  context
                      .read<NotificationsProvider>()
                      .registerToken(auth.user!.id);
                }
              });
              context.read<EditsProvider>().loadSeenIds();
            });
          }

          // ✅ تسجيل Notification Callbacks مرة واحدة فقط
          if (!_notificationCallbacksRegistered) {
            _notificationCallbacksRegistered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _registerNotificationCallbacks(context);
            });
          }

          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Pubget',
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode:
                settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: _getHome(auth),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/user_info': (_) => const UserInfoScreen(),
              '/terms': (_) => const TermsScreen(),
              '/home': (_) => const HomeScreen(),
            },
            builder: (context, child) {
              return _GlobalAppOverlay(
                navigatorKey: _navigatorKey,
                child: child!,
              );
            },
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ✅ تسجيل Callbacks للإشعارات
  // ══════════════════════════════════════════════════════════
  void _registerNotificationCallbacks(BuildContext context) {
    NotificationService.instance.registerCallbacks(
      // ── الضغط على الإشعار → التنقل ──────────────────────
      onTap: (navData) => _handleNotificationNav(context, navData),

      // ── الرد المباشر من الإشعار ──────────────────────────
      onReply: ({
        required NotificationNavType type,
        required String refId,
        required String replyText,
      }) =>
          _handleNotificationReply(
            context,
            type: type,
            refId: refId,
            replyText: replyText,
          ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ✅ منطق التنقل عند الضغط على الإشعار
  // ══════════════════════════════════════════════════════════
  void _handleNotificationNav(
      BuildContext context, NotificationNavData navData) {
    final auth = context.read<AuthProvider>();

    // ✅ لا تنقل إذا المستخدم غير مسجل دخول
    if (!auth.isLoggedIn || auth.user == null) {
      debugPrint('⚠️ Notification tap ignored — user not logged in');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;

      switch (navData.type) {
        // ── دردشة مجموعة ──────────────────────────────────
        case NotificationNavType.groupChat:
          if (navData.refId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(groupId: navData.refId!),
              ),
            );
          }
          break;

        // ── دردشة خاصة ────────────────────────────────────
        case NotificationNavType.privateChat:
          if (navData.refId != null) {
            _navigateToPrivateChat(
              navigator: navigator,
              context: context,
              chatId: navData.refId!,
              otherUserId: navData.senderId,
              currentUser: auth.user!,
            );
          }
          break;

        // ── طلب انضمام ────────────────────────────────────
        case NotificationNavType.joinRequest:
          if (navData.refId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) =>
                    JoinRequestsScreen(groupId: navData.refId!),
              ),
            );
          }
          break;

        // ── قبول الطلب → تفاصيل المجموعة ──────────────────
        case NotificationNavType.requestAccepted:
          if (navData.refId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) =>
                    GroupDetailsScreen(groupId: navData.refId!),
              ),
            );
          }
          break;

        // ── تعليق على إيديت ───────────────────────────────
        case NotificationNavType.comment:
          if (navData.refId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => EditsScreen(
                  initialEditId: navData.refId!,
                  initialCommentId: navData.commentId,
                  autoOpenComments: true,
                ),
              ),
            );
          }
          break;

        case NotificationNavType.other:
          break;
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  // ✅ التنقل للدردشة الخاصة مع جلب بيانات المستخدم الآخر
  // ══════════════════════════════════════════════════════════
  Future<void> _navigateToPrivateChat({
    required NavigatorState navigator,
    required BuildContext context,
    required String chatId,
    required String? otherUserId,
    required dynamic currentUser,
  }) async {
    if (otherUserId == null || otherUserId.isEmpty) return;

    try {
      final userProvider = context.read<UserProvider>();
      final otherUser = await userProvider.getUserById(otherUserId);

      if (otherUser == null) {
        debugPrint('⚠️ Could not fetch other user for private chat nav');
        return;
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(
            chatId: chatId,
            otherUser: otherUser,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error navigating to private chat: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // ✅ الرد المباشر من الإشعار بدون فتح التطبيق
  // ══════════════════════════════════════════════════════════
  Future<void> _handleNotificationReply(
    BuildContext context, {
    required NotificationNavType type,
    required String refId,
    required String replyText,
  }) async {
    final auth = context.read<AuthProvider>();

    // ✅ لا ترسل إذا المستخدم غير مسجل دخول
    if (!auth.isLoggedIn || auth.user == null) {
      debugPrint('⚠️ Notification reply ignored — user not logged in');
      return;
    }

    final currentUser = auth.user!;

    try {
      if (type == NotificationNavType.groupChat) {
        // ── رد على رسالة مجموعة ───────────────────────────
        final chatProvider = context.read<ChatProvider>();
        final member = await chatProvider.getMember(
          groupId: refId,
          userId: currentUser.id,
        );

        if (member == null) {
          debugPrint('⚠️ Reply failed — member not found in group $refId');
          return;
        }

        await chatProvider.sendTextMessage(
          groupId: refId,
          messageId: const Uuid().v4(),
          sender: member,
          text: replyText,
          userAvatar: currentUser.avatarUrl,
        );

        debugPrint('✅ Group reply sent from notification');
      } else if (type == NotificationNavType.privateChat) {
        // ── رد على رسالة خاصة ─────────────────────────────
        final privateChatProvider = context.read<PrivateChatProvider>();

        await privateChatProvider.sendTextMessage(
          chatId: refId,
          messageId: const Uuid().v4(),
          sender: currentUser,
          text: replyText,
        );

        debugPrint('✅ Private reply sent from notification');
      }
    } catch (e) {
      debugPrint('❌ Error sending notification reply: $e');
    }
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

// ══════════════════════════════════════════════════════════════
// _GlobalAppOverlay — بدون تعديل عن النسخة الأصلية
// ══════════════════════════════════════════════════════════════
class _GlobalAppOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const _GlobalAppOverlay(
      {required this.child, required this.navigatorKey});

  @override
  State<_GlobalAppOverlay> createState() => _GlobalAppOverlayState();
}

class _GlobalAppOverlayState extends State<_GlobalAppOverlay> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<EditsProvider>()
          .uploadCompletedNotifier
          .addListener(_handleUploadCompleted);
      context.read<DeepLinkProvider>().addListener(_handleDeepLink);
      context.read<AuthProvider>().addListener(_handleDeepLink);
    });
  }

  @override
  void dispose() {
    context
        .read<EditsProvider>()
        .uploadCompletedNotifier
        .removeListener(_handleUploadCompleted);
    context.read<DeepLinkProvider>().removeListener(_handleDeepLink);
    context.read<AuthProvider>().removeListener(_handleDeepLink);
    super.dispose();
  }

  void _handleDeepLink() {
    final deepLinkProvider = context.read<DeepLinkProvider>();
    final pending = deepLinkProvider.pendingLink;
    if (pending == null) return;

    final auth = context.read<AuthProvider>();
    if (auth.isLoading || !auth.isLoggedIn) return;

    deepLinkProvider.clearPendingLink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pending.type == DeepLinkType.group) {
        widget.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => GroupDetailsScreen(groupId: pending.id),
          ),
        );
      }
    });
  }

  void _handleUploadCompleted() {
    if (_isNavigating) return;
    final editsProvider = context.read<EditsProvider>();
    final uploadedEdit = editsProvider.uploadCompletedNotifier.value;
    if (uploadedEdit == null) return;

    _isNavigating = true;
    editsProvider.clearLastUploadedEdit();
    editsProvider.prependEdit(uploadedEdit);
    editsProvider.setSkipNextLoad();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.navigatorKey.currentState?.push(
        MaterialPageRoute(
            builder: (_) => const EditsScreen(startIndex: 0)),
      );
      if (mounted) _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditsProvider>(
      builder: (context, editsProvider, _) {
        return Stack(
          children: [
            widget.child,
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
                                color: Colors.white, fontSize: 13),
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
  }
}