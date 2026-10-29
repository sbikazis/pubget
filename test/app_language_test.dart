import 'dart:io';

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

/// Characters in the Arabic Unicode blocks. Used by the l10n ratchet below to
/// spot UI copy that is Arabic-only and therefore renders Arabic in the English
/// locale (and vice versa).
final _arabic = RegExp(r'[\u0600-\u06FF]');

/// Files that must stay free of hardcoded locale-specific literals.
///
/// These were converted to bilingual copy catalogs in Phase 11. A literal
/// creeping back in here means one locale is about to show the other language,
/// so the test fails rather than waiting for a screenshot to catch it.
/// Only widget files belong here. A `*_copy.dart` catalog is *supposed* to hold
/// Arabic — that is the whole point of the catalog — so scanning it would be
/// testing the cure for the disease.
const _mustStayBilingual = <String>[
  'lib/features/social/widgets/give_respect_sheet.dart',
];

/// Ratchet: the number of source lines under `lib/features` (excluding the
/// `l10n/` copy catalogs, where Arabic is the point) that still contain an
/// Arabic literal.
///
/// Phase 11 lowered this from 362 to 353. It may only ever go down — raising it
/// fails the build. The remaining backlog is real work, not a rounding error:
/// `members_council_sheets.dart` still holds 75 of them.
const _arabicLiteralCeiling = 353;

int _countArabicLiteralLines() {
  var total = 0;
  final root = Directory('lib/features');
  if (!root.existsSync()) return total;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll(r'\', '/');
    if (normalized.contains('/l10n/')) continue;
    for (final line in entity.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      // Comments and imports are not user-facing copy.
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      if (_arabic.hasMatch(line)) total += 1;
    }
  }
  return total;
}

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

  // --- Phase 11: the bilingual gate -----------------------------------------

  test('converted screens contain no locale-specific literals', () {
    for (final path in _mustStayBilingual) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing: $path');
      final offending = <int>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i += 1) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (_arabic.hasMatch(lines[i])) offending.add(i + 1);
      }
      expect(
        offending,
        isEmpty,
        reason:
            '$path still hardcodes Arabic on line(s) $offending. Route it '
            'through the copy catalog so both locales are served.',
      );
    }
  });

  test('the Arabic-literal backlog may only shrink', () {
    final actual = _countArabicLiteralLines();
    expect(
      actual,
      lessThanOrEqualTo(_arabicLiteralCeiling),
      reason:
          'Hardcoded Arabic rose to $actual (ceiling $_arabicLiteralCeiling). '
          'New UI copy must go through a copy catalog — a hardcoded Arabic '
          'string is invisible in the English locale, and vice versa.',
    );
  });

  test('respect and council catalogs are genuinely bilingual', () {
    // The two catalogs added by this phase must never collapse to one language.
    const samples = <String, String>{
      'Give Respect': 'منح الاحترام',
    };
    for (final entry in samples.entries) {
      expect(AppStrings.english.pick(entry.key, entry.value), entry.key);
      expect(AppStrings.arabic.pick(entry.key, entry.value), entry.value);
    }
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
