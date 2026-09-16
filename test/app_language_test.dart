import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/authentication/auth_validators.dart';
import 'package:pubget/features/authentication/screens/login_page.dart';
import 'package:pubget/features/settings/screens/settings_page.dart';
import 'package:pubget/features/settings/settings_provider.dart';
import 'package:pubget/features/settings/settings_repository.dart';
import 'package:pubget/features/settings/settings_store.dart';

import 'authentication_test_support.dart';

void main() {
  test('first launch defaults to Arabic, not English or system', () async {
    final store = MemorySettingsStore();
    final provider = SettingsProvider(
      repository: SettingsRepository(store: store),
    );
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.localeOption, AppLocaleOption.arabic);
    expect(provider.locale, const Locale('ar'));
    expect(AppStrings.forLocale(provider.locale).welcomeBack, 'مرحباً بعودتك');
  });

  test('login picker and settings radios persist the same locale', () async {
    final store = MemorySettingsStore();
    final first = SettingsProvider(
      repository: SettingsRepository(store: store),
    );
    addTearDown(first.dispose);
    await first.load();
    expect(await first.setLocaleOption(AppLocaleOption.english), isTrue);

    final restored = SettingsProvider(
      repository: SettingsRepository(store: store),
    );
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.localeOption, AppLocaleOption.english);
    expect(restored.locale, const Locale('en'));
    expect(AppStrings.forLocale(restored.locale).welcomeBack, 'Welcome back');
    expect(AppStrings.forLocale(restored.locale).settings, 'Settings');
  });

  test('Arabic validators match the login copy catalog', () {
    expect(
      AuthValidators.email('nope', AppStrings.arabic),
      AppStrings.arabic.emailInvalid,
    );
    expect(
      AuthValidators.password('1', AppStrings.arabic),
      AppStrings.arabic.passwordTooShort,
    );
  });

  test('drawer and tab labels stay on the same catalog per locale', () {
    for (final copy in <AppStrings>[AppStrings.english, AppStrings.arabic]) {
      expect(copy.drawerLabel('settings'), copy.settings);
      expect(copy.drawerLabel('guide'), copy.guide);
      expect(copy.drawerLabel('anime'), copy.drawerAnime);
      expect(copy.drawerAnime, isNotEmpty);
      expect(copy.tabDiscover, isNotEmpty);
      expect(copy.tabPrivate, isNot(copy.tabGroups));
    }
    expect(AppStrings.arabic.tabDiscover, 'استكشف');
    expect(AppStrings.english.tabDiscover, 'Discover');
  });

  testWidgets('login language chips switch copy immediately', (tester) async {
    final settings = SettingsProvider(
      repository: SettingsRepository(store: MemorySettingsStore()),
    );
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.localeOption, AppLocaleOption.arabic);

    await pumpAuthScreen(tester, child: const LoginPage(), settings: settings);
    await tester.pumpAndSettle();

    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.byKey(const Key('auth-language-arabic')), findsOneWidget);
    expect(find.byKey(const Key('auth-language-english')), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-language-english')));
    await tester.pumpAndSettle();

    expect(settings.localeOption, AppLocaleOption.english);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('مرحباً بعودتك'), findsNothing);
  });

  testWidgets('settings language radios drive the same SettingsProvider', (
    tester,
  ) async {
    final settings = SettingsProvider(
      repository: SettingsRepository(
        store: MemorySettingsStore(const <String, String>{
          'locale': 'english',
          'themeMode': 'system',
        }),
      ),
    );
    addTearDown(settings.dispose);
    await settings.load();

    await pumpAuthScreen(
      tester,
      child: const SettingsPage(),
      settings: settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-language-arabic')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-language-arabic')));
    await tester.pumpAndSettle();

    expect(settings.localeOption, AppLocaleOption.arabic);
    expect(find.text('الإعدادات'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('اللغة', skipOffstage: false), findsOneWidget);
  });
}
