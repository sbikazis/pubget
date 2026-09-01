import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart' as provider;

import '../core/network/network_service.dart';
import '../core/loading/loading_state.dart';
import '../core/theme/app_theme.dart';
import '../features/authentication/providers/auth_provider.dart';
import '../features/authentication/providers/onboarding_provider.dart';
import '../features/authentication/repositories/auth_repository.dart';
import '../features/authentication/repositories/firebase_auth_repository.dart';
import '../features/authentication/repositories/firebase_user_repository.dart';
import '../features/authentication/repositories/unavailable_repositories.dart';
import '../features/authentication/repositories/user_repository.dart';
import '../features/authentication/screens/login_page.dart';
import '../features/authentication/screens/onboarding_page.dart';
import '../features/authentication/screens/placeholder_home_page.dart';
import '../features/authentication/screens/register_page.dart';
import '../features/authentication/screens/splash_page.dart';
import '../features/authentication/screens/terms_page.dart';
import '../features/social/providers/profile_provider.dart';
import '../features/social/providers/social_provider.dart';
import '../features/social/repositories/firebase_profile_repository.dart';
import '../features/social/repositories/firebase_social_repository.dart';
import '../features/social/repositories/profile_repository.dart';
import '../features/social/repositories/social_repository.dart';
import '../features/social/repositories/unavailable_profile_repository.dart';
import '../features/social/repositories/unavailable_social_repository.dart';
import '../features/social/screens/edit_profile_page.dart';
import '../features/social/screens/friend_requests_page.dart';
import '../features/social/screens/profile_page.dart';
import 'app_route.dart';
import 'app_router.dart';
import 'design_system_showcase_page.dart';
import 'firebase_bootstrap.dart';

class PubgetApp extends StatelessWidget {
  const PubgetApp({required this.firebaseState, super.key});

  final FirebaseInitializationState firebaseState;

  @override
  Widget build(BuildContext context) {
    final requestedRoute = switch (Uri.base.path) {
      '/design-system' ||
      '/design-system/' => const ParameterizedRoute(path: '/design-system'),
      '/login' ||
      '/register' ||
      '/terms' ||
      '/onboarding' ||
      '/home' ||
      '/profile' ||
      '/profile/edit' ||
      '/friend-requests' => ParameterizedRoute(
        path: Uri.base.path,
        parameters: Uri.base.queryParameters,
      ),
      _ => const ParameterizedRoute(path: '/splash'),
    };
    final developmentInitialRoute = kDebugMode
        ? requestedRoute
        : requestedRoute.path == '/design-system'
        ? const ParameterizedRoute(path: '/splash')
        : requestedRoute;
    final repositories = _createRepositories();

    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider<NetworkService>(
          create: (_) => NetworkService()..start(),
        ),
        provider.Provider<AuthRepository>.value(value: repositories.$1),
        provider.Provider<UserRepository>.value(value: repositories.$2),
        provider.Provider<ProfileRepository>.value(value: repositories.$3),
        provider.Provider<SocialRepository>.value(value: repositories.$4),
        provider.ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(repository: context.read<AuthRepository>()),
        ),
        provider.ChangeNotifierProvider<OnboardingProvider>(
          create: (context) =>
              OnboardingProvider(repository: context.read<UserRepository>()),
        ),
        provider.ChangeNotifierProvider<ProfileProvider>(
          create: (context) =>
              ProfileProvider(repository: context.read<ProfileRepository>()),
        ),
        provider.ChangeNotifierProvider<SocialProvider>(
          create: (context) =>
              SocialProvider(repository: context.read<SocialRepository>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.read<AuthProvider>();
          final onboarding = context.read<OnboardingProvider>();
          return MaterialApp.router(
            title: 'Pubget',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: AppRouter.createConfig(
              homePage: SplashPage(firebaseState: firebaseState),
              designSystemPage: kDebugMode
                  ? const DesignSystemShowcasePage()
                  : null,
              domainPages: <String, Widget>{
                '/splash': SplashPage(firebaseState: firebaseState),
                '/login': const LoginPage(),
                '/register': const RegisterPage(),
                '/terms': const TermsPage(),
                '/onboarding': const OnboardingPage(),
                '/home': const PlaceholderHomePage(),
                '/profile/edit': const EditProfilePage(),
                '/friend-requests': const FriendRequestsPage(),
              },
              parameterizedPages: <String, ParameterizedPageBuilder>{
                '/profile': (parameters) =>
                    ProfilePage(userId: parameters['uid']),
              },
              initialRoute: developmentInitialRoute,
              refreshListenable: Listenable.merge(<Listenable>[
                auth,
                onboarding,
              ]),
              routeGuard: (path) {
                final isProtected =
                    path == '/home' ||
                    path == '/onboarding' ||
                    path == '/profile' ||
                    path == '/profile/edit' ||
                    path == '/friend-requests';
                if (!isProtected) return null;
                if (!auth.isInitialized ||
                    auth.state == LoadingState.initial ||
                    auth.state == LoadingState.loading) {
                  return '/splash';
                }
                if (!auth.isAuthenticated) return '/login';
                if (path != '/onboarding' &&
                    onboarding.state == LoadingState.initial) {
                  return '/splash';
                }
                if (path != '/onboarding' && !onboarding.canEnterHome) {
                  return '/onboarding';
                }
                return null;
              },
            ),
          );
        },
      ),
    );
  }

  (AuthRepository, UserRepository, ProfileRepository, SocialRepository)
  _createRepositories() {
    if (!firebaseState.isReady) {
      final message =
          firebaseState.message ?? 'Firebase is unavailable in this build.';
      return (
        UnavailableAuthRepository(message),
        UnavailableUserRepository(message),
        UnavailableProfileRepository(message),
        UnavailableSocialRepository(message),
      );
    }
    return (
      FirebaseAuthRepository(
        auth: firebase_auth.FirebaseAuth.instance,
        googleSignIn: GoogleSignIn.instance,
      ),
      FirebaseUserRepository(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      ),
      FirebaseProfileRepository(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      ),
      FirebaseSocialRepository(
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
      ),
    );
  }
}
