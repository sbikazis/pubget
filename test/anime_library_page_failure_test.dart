import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/providers/anime_my_list_provider.dart';
import 'package:pubget/features/anime/repositories/unavailable_anime_library_repository.dart';
import 'package:pubget/features/anime/screens/anime_library_page.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';

void main() {
  testWidgets(
    'a My list failure renders localized copy, not the backend text',
    (tester) async {
      final library = AnimeLibraryProvider(
        // The sentence below is the kind of locale-neutral developer string the
        // old screen painted verbatim into the Arabic UI.
        repository: const UnavailableAnimeLibraryRepository(
          'Anime list update failed.',
        ),
      )..bindUser('user-1');
      addTearDown(library.dispose);

      await tester.pumpWidget(_harness(library));
      await tester.pumpAndSettle();

      expect(library.state, LoadingState.error);
      final copy = AnimeCopy.forLocale(const Locale('ar'));
      expect(find.text(copy.serviceUnavailable), findsOneWidget);
      expect(find.textContaining('Anime list update failed.'), findsNothing);
      expect(find.textContaining('Something went wrong'), findsNothing);
    },
  );

  testWidgets('the My list header fits a short phone without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final library = AnimeLibraryProvider(
      repository: const UnavailableAnimeLibraryRepository('down'),
    )..bindUser('user-1');
    addTearDown(library.dispose);

    await tester.pumpWidget(_harness(library, withMyList: true));
    // A constraint overflow throws inside the framework and fails this test,
    // which is exactly the regression the stacked header used to cause.
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('anime-my-list-search')), findsOneWidget);
    expect(
      find.byKey(
        ValueKey<String>('anime-format-${AnimeListFormatFilter.all.wireValue}'),
      ),
      findsOneWidget,
    );
  });
}

Widget _harness(AnimeLibraryProvider library, {bool withMyList = false}) {
  final auth = AuthProvider(
    repository: FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    ),
  )..initialize();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(
        value: NetworkService(probe: () async => true),
      ),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<AnimeLibraryProvider>.value(value: library),
      if (withMyList)
        ChangeNotifierProvider<AnimeMyListProvider>.value(
          value: AnimeMyListProvider(
            repository: FakeAnimeRepository(),
            entries: () => library.entries,
          ),
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: AnimeLibraryPage(),
      ),
    ),
  );
}
