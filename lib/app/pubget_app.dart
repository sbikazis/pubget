import 'package:cloud_firestore/cloud_firestore.dart';
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
      '/home' => ParameterizedRoute(path: Uri.base.path),
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
        provider.ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(repository: context.read<AuthRepository>()),
        ),
        provider.ChangeNotifierProvider<OnboardingProvider>(
          create: (context) =>
              OnboardingProvider(repository: context.read<UserRepository>()),
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
              },
              initialRoute: developmentInitialRoute,
              refreshListenable: Listenable.merge(<Listenable>[
                auth,
                onboarding,
              ]),
              routeGuard: (path) {
                if (path != '/home' && path != '/onboarding') return null;
                if (!auth.isInitialized ||
                    auth.state == LoadingState.initial ||
                    auth.state == LoadingState.loading) {
                  return '/splash';
                }
                if (!auth.isAuthenticated) return '/login';
                if (path == '/home' &&
                    onboarding.state == LoadingState.initial) {
                  return '/splash';
                }
                if (path == '/home' && !onboarding.canEnterHome) {
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

  (AuthRepository, UserRepository) _createRepositories() {
    if (!firebaseState.isReady) {
      final message =
          firebaseState.message ?? 'Firebase is unavailable in this build.';
      return (
        UnavailableAuthRepository(message),
        UnavailableUserRepository(message),
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
    );
  }
}
