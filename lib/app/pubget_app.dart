import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/examples/dummy_provider.dart';
import '../core/examples/dummy_repository.dart';
import '../core/network/network_service.dart';
import '../core/theme/app_theme.dart';
import 'app_router.dart';
import 'foundation_home_page.dart';
import 'firebase_bootstrap.dart';

class PubgetApp extends StatelessWidget {
  const PubgetApp({required this.firebaseState, super.key});

  final FirebaseInitializationState firebaseState;

  @override
  Widget build(BuildContext context) {
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
        routerConfig: AppRouter.createConfig(
          homePage: FoundationHomePage(firebaseState: firebaseState),
        ),
      ),
    );
  }
}
