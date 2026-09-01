import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/examples/dummy_provider.dart';
import '../core/examples/dummy_repository.dart';
import '../core/network/network_service.dart';
import '../core/theme/app_theme.dart';
import 'app_route.dart';
import 'app_router.dart';
import 'design_system_showcase_page.dart';
import 'foundation_home_page.dart';
import 'firebase_bootstrap.dart';

class PubgetApp extends StatelessWidget {
  const PubgetApp({required this.firebaseState, super.key});

  final FirebaseInitializationState firebaseState;

  @override
  Widget build(BuildContext context) {
    final initialRoute = switch (Uri.base.path) {
      '/design-system' ||
      '/design-system/' => const ParameterizedRoute(path: '/design-system'),
      _ => const FoundationRoute(),
    };
    final developmentInitialRoute = kDebugMode
        ? initialRoute
        : const FoundationRoute();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NetworkService>(
          create: (_) => NetworkService()..start(),
        ),
        Provider<DummyRepository>(create: (_) => DummyRepository()),
        ChangeNotifierProvider<DummyProvider>(
          create: (context) =>
              DummyProvider(repository: context.read<DummyRepository>()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Pubget',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.createConfig(
          homePage: FoundationHomePage(firebaseState: firebaseState),
          designSystemPage: kDebugMode
              ? const DesignSystemShowcasePage()
              : null,
          initialRoute: developmentInitialRoute,
        ),
      ),
    );
  }
}
