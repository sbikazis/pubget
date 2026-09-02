import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/firebase_bootstrap.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/authentication/providers/auth_draft_store.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/authentication/screens/login_page.dart';
import 'package:pubget/features/authentication/screens/splash_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets(
    'Firebase failure splash is not an unauthenticated entry screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SplashPage(
            firebaseState: FirebaseInitializationState.unavailable(
              FirebaseBootstrap.userFacingInitializationMessage(
                RangeError.range(14, 0, 13, 'length'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Authentication is unavailable here'), findsNothing);
      expect(find.text('Open sign in'), findsNothing);
      expect(find.text('Pubget could not start'), findsOneWidget);
      expect(find.textContaining('RangeError'), findsNothing);
      expect(
        find.text(FirebaseBootstrap.unexpectedInitializationMessage),
        findsOneWidget,
      );
    },
  );

  testWidgets('ready unauthenticated splash goes to login, not an error page', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    final network = NetworkService(probe: () async => true);
    addTearDown(network.dispose);
    await network.refresh();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(value: network),
          ChangeNotifierProvider<AuthDraftStore>(
            create: (_) => AuthDraftStore(),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(repository: repository),
          ),
          ChangeNotifierProvider<OnboardingProvider>(
            create: (_) => OnboardingProvider(repository: FakeUserRepository()),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: AppRouter.createConfig(
            homePage: const SplashPage(
              firebaseState: FirebaseInitializationState.initializedForTests(),
            ),
            domainPages: const <String, Widget>{'/login': LoginPage()},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Authentication is unavailable here'), findsNothing);
    expect(find.text('Open sign in'), findsNothing);
    expect(find.text('Pubget could not start'), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}
