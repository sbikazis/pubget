import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/settings/screens/settings_page.dart';
import 'package:pubget/features/settings/settings_provider.dart';
import 'package:pubget/features/settings/settings_repository.dart';
import 'package:pubget/features/settings/settings_store.dart';
import 'package:pubget/features/social/providers/profile_provider.dart';
import 'package:pubget/features/social/repositories/profile_repository.dart';

import 'authentication_test_support.dart';
import 'social_test_support.dart';

void main() {
  test('loads defaults then persists theme and locale', () async {
    final store = MemorySettingsStore();
    final repository = SettingsRepository(store: store);
    final provider = SettingsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load();
    expect(provider.themeMode, ThemeMode.system);
    expect(provider.localeOption, AppLocaleOption.system);
    expect(provider.locale, isNull);

    expect(await provider.setThemeMode(ThemeMode.dark), isTrue);
    expect(await provider.setLocaleOption(AppLocaleOption.arabic), isTrue);
    expect(provider.themeMode, ThemeMode.dark);
    expect(provider.locale, const Locale('ar'));

    final restored = SettingsProvider(repository: SettingsRepository(store: store));
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.localeOption, AppLocaleOption.arabic);
  });

  test('save failure rolls back the previous value', () async {
    final store = _FailingSettingsStore();
    final provider = SettingsProvider(
      repository: SettingsRepository(store: store),
    );
    addTearDown(provider.dispose);
    await provider.load();
    expect(await provider.setThemeMode(ThemeMode.light), isFalse);
    expect(provider.themeMode, ThemeMode.system);
    expect(provider.failure, isNotNull);
  });

  test('profile session reset isolates the previous account', () async {
    final provider = ProfileProvider(repository: FakeProfileRepository());
    addTearDown(provider.dispose);
    await provider.load(viewerId: 'user-1', profileId: 'user-1');
    expect(provider.ownProfile?.email, 'fan@example.com');
    provider.bindUser('user-2');
    expect(provider.ownProfile, isNull);
    expect(provider.state, LoadingState.initial);
  });

  test('account switch clears onboarding private profile', () async {
    final onboarding = OnboardingProvider(repository: FakeUserRepository());
    addTearDown(onboarding.dispose);
    await onboarding.saveProfile(
      authUser: const AuthUser(id: 'a', email: 'a@example.com'),
      username: 'alice',
      isProfileCompleted: true,
    );
    expect(onboarding.profile?.username, 'alice');
    onboarding.bindUser('a');
    onboarding.bindUser('b');
    expect(onboarding.profile, isNull);
    expect(onboarding.state, LoadingState.initial);
  });

  test('ProfileUpdate cannot carry economy or role fields', () {
    const update = ProfileUpdate(
      bio: 'hello',
      profileVisibility: 'private',
    );
    expect(update.toMap().containsKey('coinsBalance'), isFalse);
    expect(update.toMap().containsKey('premiumExpiresAt'), isFalse);
    expect(update.toMap().containsKey('subscriptionType'), isFalse);
    expect(update.toMap().containsKey('role'), isFalse);
    expect(update.toMap().keys, <String>['bio', 'profileVisibility']);
  });

  testWidgets('settings page follows RTL locale and shows account actions', (
    tester,
  ) async {
    final auth = AuthProvider(
      repository: FakeAuthRepository(
        user: const AuthUser(id: 'a', email: 'a@example.com'),
      ),
    );
    await auth.initialize();
    addTearDown(auth.dispose);
    final settings = SettingsProvider(
      repository: SettingsRepository(store: MemorySettingsStore()),
    );
    await settings.setLocaleOption(AppLocaleOption.arabic);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<OnboardingProvider>(
            create: (_) => OnboardingProvider(repository: FakeUserRepository()),
          ),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('العربية'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('العربية'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(SettingsPage))),
      TextDirection.rtl,
    );
  });
}

final class _FailingSettingsStore implements SettingsStore {
  @override
  Future<Map<String, String>> read() async => const <String, String>{};

  @override
  Future<void> write(Map<String, String> values) async {
    throw StateError('disk full');
  }
}
