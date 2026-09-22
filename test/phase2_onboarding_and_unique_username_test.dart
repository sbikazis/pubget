import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/firebase_bootstrap.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/authentication/auth_validators.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/models/pubget_user.dart';
import 'package:pubget/features/authentication/providers/auth_draft_store.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/authentication/screens/onboarding_page.dart';
import 'package:pubget/features/authentication/screens/splash_page.dart';
import 'package:pubget/features/settings/settings_provider.dart';
import 'package:pubget/features/settings/settings_repository.dart';
import 'package:pubget/features/settings/settings_store.dart';

import 'authentication_test_support.dart';

void main() {
  group('Phase 02 username rules', () {
    test('accepts letters, digits, dots, underscores and hyphens', () {
      for (final value in <String>['fan', 'fan_2024', 'a.b-c_d', 'ahmed-9']) {
        expect(
          AuthValidators.username(value),
          isNull,
          reason: '$value should be valid',
        );
      }
    });

    test('rejects short, digit-first, invalid-character and oversized names', () {
      expect(AuthValidators.username('ab'), isNotNull);
      expect(AuthValidators.username('123fan'), isNotNull);
      expect(AuthValidators.username('fan name'), isNotNull);
      expect(AuthValidators.username('fan@pubget'), isNotNull);
      expect(AuthValidators.username('a' * 25), isNotNull);
      expect(AuthValidators.username('a' * 20), isNull);
      // Arabic runs through the same letter/digit charset.
      expect(AuthValidators.username('أحمد'), isNull);
    });

    test('canonicalUsername lowercases for server lookup', () {
      expect(AuthValidators.canonicalUsername(' Pubget_Fan '), 'pubget_fan');
      expect(AuthValidators.canonicalUsername('أحمد'), 'أحمد');
    });
  });

  group('Phase 02 onboarding identity gating', () {
    testWidgets('continue is blocked until name, photo and username', (
      tester,
    ) async {
      await pumpAuthScreen(tester, child: const OnboardingPage());
      await tester.ensureVisible(find.byKey(const Key('onboarding-continue')));
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pump();

      expect(find.text('Username is required.'), findsOneWidget);
      expect(find.text('Display name is required.'), findsOneWidget);
      expect(find.text('Profile photo is required.'), findsOneWidget);
      expect(find.text('A little about you'), findsNothing);
    });

    testWidgets('free username surfaces inline availability while typing', (
      tester,
    ) async {
      await pumpAuthScreen(tester, child: const OnboardingPage());
      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'alice',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Username is available.'), findsOneWidget);
    });

    testWidgets('taken username blocks continue even when format is valid', (
      tester,
    ) async {
      final users = FakeUserRepository()..takenUsernames.add('taken');
      final auth = FakeAuthRepository(
        user: const AuthUser(
          id: 'user-1',
          email: 'fan@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
        ),
      );
      addTearDown(auth.close);
      await pumpAuthScreen(
        tester,
        child: const OnboardingPage(),
        users: users,
        repository: auth,
      );
      final authProvider = tester
          .element(find.byType(OnboardingPage))
          .read<AuthProvider>();
      await authProvider.initialize();
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'taken',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding-displayName')),
        'Dana',
      );
      // The identity step shows the taken error after the server re-check.
      await tester.ensureVisible(find.byKey(const Key('onboarding-continue')));
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Username is already taken.'), findsOneWidget);
      expect(find.text('A little about you'), findsNothing);
    });

    testWidgets('offline flows offer a device-local save instead of identity', (
      tester,
    ) async {
      final network = NetworkService(probe: () async => false);
      addTearDown(network.dispose);
      await network.refresh();
      await pumpAuthScreen(
        tester,
        child: const OnboardingPage(),
        network: network,
        users: FakeUserRepository()
          ..user = PubgetUser(
            id: 'user-1',
            email: 'a@example.com',
            username: 'alice',
            displayName: 'Alice',
            createdAt: DateTime.now(),
            isProfileCompleted: false,
          ),
      );

      expect(find.text('You are offline'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-skip-step')), findsOneWidget);
      expect(find.text('Save on this device for now'), findsOneWidget);
    });
  });

  group('Phase 02 username availability via provider', () {
    test('check, reserve and language mirror delegate to the repository', () async {
      final repository = FakeUserRepository();
      final onboarding = OnboardingProvider(repository: repository);
      addTearDown(onboarding.dispose);

      final available = await onboarding.checkUsernameAvailable('alice');
      expect(available.isSuccess, isTrue);
      expect(available.valueOrNull?.available, isTrue);
      expect(available.valueOrNull?.normalized, 'alice');

      final reserve = await onboarding.reserveUsername('alice');
      expect(reserve.isSuccess, isTrue);
      expect(repository.takenUsernames, contains('alice'));

      // A second reservation for the same owner is idempotent at the fake
      // level because the check now sees it as still claimable by the owner.
      // The server enforces single-owner semantics in userNameRegistry.js.
      final second = await onboarding.checkUsernameAvailable('alice');
      expect(second.valueOrNull?.available, isFalse);

      await onboarding.updateLanguage('ar');
      expect(repository.mirrorLanguageChanges, contains('ar'));
    });

    test('availability failure produces a server-error status', () async {
      final repository = FakeUserRepository()
        ..availabilityFailure = const UnknownError('server down');
      final onboarding = OnboardingProvider(repository: repository);
      addTearDown(onboarding.dispose);

      final result = await onboarding.checkUsernameAvailable('alice');
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isNotNull);
    });
  });

  group('Phase 02 language seeding', () {
    test('server profile seeds a fresh device exactly once', () async {
      final store = MemorySettingsStore();
      final provider = SettingsProvider(
        repository: SettingsRepository(store: store),
      );
      addTearDown(provider.dispose);
      await provider.load();

      expect(provider.languageSeeded, isFalse);
      expect(await provider.seedLanguageFromServer('en'), isTrue);
      expect(provider.localeOption, AppLocaleOption.english);
      expect(provider.languageSeeded, isTrue);

      // Later explicit choices are not overridden by the server.
      expect(await provider.seedLanguageFromServer('ar'), isFalse);
      expect(provider.localeOption, AppLocaleOption.english);

      final restored = SettingsProvider(
        repository: SettingsRepository(store: store),
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.languageSeeded, isTrue);
      expect(restored.localeOption, AppLocaleOption.english);
    });

    test('explicit radio choice marks the device as seeded', () async {
      final provider = SettingsProvider(
        repository: SettingsRepository(
          store: MemorySettingsStore(),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.setLocaleOption(AppLocaleOption.arabic);
      expect(provider.languageSeeded, isTrue);
      expect(provider.localeOption, AppLocaleOption.arabic);
    });
  });

  group('Phase 02 splash language hand-off', () {
    testWidgets('an authenticated fresh device is seeded from the profile', (
      tester,
    ) async {
      final users = FakeUserRepository()
        ..user = PubgetUser(
          id: 'user-1',
          email: 'fan@example.com',
          username: 'fan',
          displayName: 'Fan',
          language: 'en',
          createdAt: DateTime.now(),
          isProfileCompleted: true,
        );
      final auth = FakeAuthRepository(
        user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
      );
      addTearDown(auth.close);
      final network = NetworkService(probe: () async => true);
      addTearDown(network.dispose);
      await network.refresh();
      final settings = await englishSettingsProvider();
      addTearDown(settings.dispose);
      final delegate = AppRouterDelegate(
        homePage: const SplashPage(
          firebaseState: FirebaseInitializationState.initializedForTests(),
        ),
        domainPages: const <String, Widget>{
          '/home': Scaffold(body: Text('home-stub')),
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NetworkService>.value(value: network),
            ChangeNotifierProvider<AuthDraftStore>(
              create: (_) => AuthDraftStore(),
            ),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(repository: auth),
            ),
            ChangeNotifierProvider<OnboardingProvider>(
              create: (_) => OnboardingProvider(repository: users),
            ),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            locale: settings.locale,
            home: Router(
              routerDelegate: delegate,
              routeInformationParser: AppRouteInformationParser(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(settings.localeOption, AppLocaleOption.english);
      expect(settings.languageSeeded, isTrue);
    });
  });
}