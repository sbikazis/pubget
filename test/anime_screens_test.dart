import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/screens/anime_browse_page.dart';
import 'package:pubget/features/anime/screens/anime_details_page.dart';
import 'package:pubget/features/anime/screens/anime_hub_page.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';

void main() {
  testWidgets('hub shows loading then trending titles', (tester) async {
    final repository = FakeAnimeRepository()..gate = Completer<void>();
    await tester.pumpWidget(
      _harness(
        repository: repository,
        child: const AnimeHubPage(),
      ),
    );
    await tester.pump();
    expect(find.byType(PubgetSkeleton), findsWidgets);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text(AnimeStrings.hubTitle), findsWidgets);
  });

  testWidgets('hub empty state', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(
          page: const AnimePage(items: <Anime>[]),
          genres: const <AnimeGenre>[],
          seasons: const <AnimeSeasonYear>[],
        ),
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.emptyCatalog), findsWidgets);
  });

  testWidgets('hub error state has retry', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(failure: const UnavailableError()),
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.unableToLoad), findsWidgets);
    expect(find.text(AnimeStrings.retry), findsWidgets);
  });

  testWidgets('search empty results', (tester) async {
    final repository = FakeAnimeRepository(
      page: const AnimePage(items: <Anime>[]),
    );
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.nothingFound), findsWidgets);
  });

  testWidgets('details success, character failure does not hide anime', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(
          charactersFailure: const NetworkError(),
        ),
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text(AnimeStrings.retry), findsWidgets);
  });

  testWidgets('details missing anime', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeDetailsPage(animeId: 'missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.detailsMissing), findsWidgets);
  });

  testWidgets('genre browse shows list', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeBrowsePage(
          genreId: '1',
          genreName: 'Action',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('season browse shows list', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeBrowsePage(
          year: 2026,
          season: AnimeSeason.winter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Winter 2026'), findsWidgets);
  });

  testWidgets('light and dark themes render hub cards', (tester) async {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        _harness(
          repository: FakeAnimeRepository(),
          theme: theme,
          child: const AnimeHubPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Frieren'), findsWidgets);
    }
  });

  testWidgets('rtl hub still shows titles', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        textDirection: TextDirection.rtl,
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
  });
}

Widget _harness({
  required FakeAnimeRepository repository,
  required Widget child,
  ThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final network = NetworkService(probe: () async => true);
  final hub = AnimeHubProvider(repository: repository);
  final list = AnimeListProvider(
    repository: repository,
    debounce: Duration.zero,
  );
  final details = AnimeDetailsProvider(repository: repository);
  final auth = AuthProvider(
    repository: FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    ),
  )..initialize();
  final onboarding = OnboardingProvider(repository: FakeUserRepository());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(value: network),
      ChangeNotifierProvider<AnimeHubProvider>.value(value: hub),
      ChangeNotifierProvider<AnimeListProvider>.value(value: list),
      ChangeNotifierProvider<AnimeDetailsProvider>.value(value: details),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Directionality(textDirection: textDirection, child: child),
    ),
  );
}
