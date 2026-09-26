import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_hub_social_provider.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';
import 'package:pubget/features/anime/repositories/anime_library_repository.dart';
import 'package:pubget/features/anime/screens/anime_favorite_characters_page.dart';
import 'package:pubget/features/anime/screens/anime_ratings_page.dart';
import 'package:pubget/features/anime/widgets/anime_hub_widgets.dart';

import 'anime_test_support.dart';

void main() {
  testWidgets('favorite characters page renders a three column grid', (
    tester,
  ) async {
    final socialRepository = _FakeSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    final library = _LibrarySpy();
    await tester.pumpWidget(
      _harness(
        social: social,
        library: library,
        child: const AnimeFavoriteCharactersPage(userId: 'alice'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My favorite characters'), findsWidgets);
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Erwin Smith'), findsOneWidget);
    expect(find.byType(AnimeHubGrid), findsOneWidget);

    final grid = tester.widget<AnimeHubGrid>(find.byType(AnimeHubGrid));
    expect(grid.itemCount, 2);

    // A character grid never paints the anime year/rating overlays.
    expect(find.text('2026'), findsNothing);
    expect(find.textContaining('8.7'), findsNothing);
  });

  testWidgets('favorite characters page filters as the member searches', (
    tester,
  ) async {
    final social = AnimeHubSocialProvider(repository: _FakeSocialRepository());
    await tester.pumpWidget(
      _harness(
        social: social,
        library: _LibrarySpy(),
        child: const AnimeFavoriteCharactersPage(userId: 'alice'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Erwin Smith'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('anime-favorite-characters-search')),
      'erwin',
    );
    await tester.pumpAndSettle();
    expect(find.text('Erwin Smith'), findsOneWidget);
    expect(find.text('Frieren'), findsNothing);
  });

  testWidgets('favorite characters page long press removes a character', (
    tester,
  ) async {
    final socialRepository = _FakeSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    final library = _LibrarySpy();
    await tester.pumpWidget(
      _harness(
        social: social,
        library: library,
        child: const AnimeFavoriteCharactersPage(userId: 'alice'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Frieren'));
    await tester.pumpAndSettle();
    expect(library.toggled, <String>['2816']);
  });

  testWidgets('favorite characters page shows the empty state', (
    tester,
  ) async {
    final social = AnimeHubSocialProvider(
      repository: _FakeSocialRepository(characters: const <CharacterFavorite>[]),
    );
    await tester.pumpWidget(
      _harness(
        social: social,
        library: _LibrarySpy(),
        child: const AnimeFavoriteCharactersPage(userId: 'alice'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No favorite characters yet'), findsWidgets);
  });

  testWidgets('MAL ranking page opens the Jikan top rated catalog', (
    tester,
  ) async {
    final repository = FakeAnimeRepository();
    final socialRepository = _FakeSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    await tester.pumpWidget(
      _harness(
        repository: repository,
        social: social,
        library: _LibrarySpy(),
        child: const AnimeRatingsPage(source: AnimeRankingSource.mal),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Global MAL ranking'), findsWidgets);
    expect(find.text('Frieren'), findsWidgets);
    expect(socialRepository.topRatedCalls, 0);
  });

  testWidgets('Pubget rating page reads the community ranking', (
    tester,
  ) async {
    // ignore: avoid_print
    final repository = FakeAnimeRepository();
    final socialRepository = _FakeSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    await tester.pumpWidget(
      _harness(
        repository: repository,
        social: social,
        library: _LibrarySpy(),
        child: const AnimeRatingsPage(source: AnimeRankingSource.pubget),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pubget community ranking'), findsWidgets);
    // ignore: avoid_print
    expect(socialRepository.topRatedCalls, 1);
    expect(find.text('Frieren: Beyond Journeys End'), findsOneWidget);
  });
}

final class _FakeSocialRepository implements AnimeHubSocialRepository {
  _FakeSocialRepository({
    this.characters = const <CharacterFavorite>[
      CharacterFavorite(characterId: '2816', name: 'Frieren'),
      CharacterFavorite(characterId: '2783', name: 'Erwin Smith'),
    ],
  });

  final List<CharacterFavorite> characters;
  var topRatedCalls = 0;

  @override
  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  ) async => Success<List<CharacterFavorite>>(characters);

  @override
  Future<Result<List<AnimeCustomList>>> listUserCustomAnimeLists(
    String userId,
  ) async => const Success(<AnimeCustomList>[]);

  @override
  Future<Result<List<AnimeReview>>> listUserRatings(String userId) async {
    return const Success(<AnimeReview>[]);
  }

  @override
  Future<Result<List<AnimeListEntry>>> listUserAnimeList(String userId) async {
    return const Success(<AnimeListEntry>[]);
  }

  @override
  Future<Result<List<AnimeCommunityStats>>> listTopRated({int limit = 40}) async {
    topRatedCalls += 1;
    return const Success(<AnimeCommunityStats>[
      AnimeCommunityStats(
        animeId: '52991',
        title: 'Frieren: Beyond Journeys End',
        averageScore: 9.1,
        ratingCount: 1200,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LibrarySpy implements AnimeLibraryRepository {
  final List<String> toggled = <String>[];

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId}) async {
    return const Success(<AnimeCustomList>[]);
  }

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async {
    return const Success(<CharacterFavorite>[]);
  }

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 50,
  }) async => const Success(AnimeListPage());

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async {
    toggled.add(characterId);
    return Success<CharacterFavorite>(
      CharacterFavorite(
        characterId: characterId,
        name: name,
        imageUrl: imageUrl,
        rating: rating,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness({
  required Widget child,
  required AnimeHubSocialProvider social,
  required _LibrarySpy library,
  FakeAnimeRepository? repository,
}) {
  final anime = repository ?? FakeAnimeRepository();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(
        value: NetworkService(probe: () async => true),
      ),
      ChangeNotifierProvider<AnimeHubSocialProvider>.value(value: social),
      Provider<AnimeLibraryRepository>.value(value: library),
      ChangeNotifierProvider<AnimeLibraryProvider>(
        create: (_) =>
            AnimeLibraryProvider(repository: library)..bindUser('alice'),
      ),
      ChangeNotifierProvider<AnimeListProvider>(
        create: (_) => AnimeListProvider(
          repository: anime,
          debounce: Duration.zero,
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}
