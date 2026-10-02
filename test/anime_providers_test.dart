import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';
import 'social_test_support.dart';

void main() {
  test('hub loads catalog sections, genres, and seasons', () async {
    final hub = AnimeHubProvider(repository: FakeAnimeRepository());
    addTearDown(hub.dispose);
    await hub.load();
    expect(hub.state, LoadingState.loaded);
    expect(hub.section(AnimeCatalogKind.thisSeason).items, isNotEmpty);
    expect(hub.section(AnimeCatalogKind.popular).items, isNotEmpty);
    expect(hub.section(AnimeCatalogKind.trending).items, isEmpty);
    expect(hub.genres, isNotEmpty);
    expect(hub.seasons, isNotEmpty);
    expect(hub.section(AnimeCatalogKind.top).items, isEmpty);
  });

  test('hub does not fetch Jikan top-rated or currently-airing strips', () async {
    final repository = FakeAnimeRepository();
    final hub = AnimeHubProvider(repository: repository);
    addTearDown(hub.dispose);
    await hub.load();
    expect(repository.trendingCalls, 0);
    expect(repository.thisSeasonCalls, 1);
    expect(repository.popularCalls, 1);
    expect(repository.upcomingCalls, 0);
    expect(repository.topCalls, 0);
    expect(repository.airingCalls, 0);
  });

  test('hub error without content becomes error state', () async {
    final hub = AnimeHubProvider(
      repository: FakeAnimeRepository(failure: const UnavailableError()),
    );
    addTearDown(hub.dispose);
    await hub.load();
    expect(hub.state, LoadingState.error);
  });

  test('details success and independent character failure', () async {
    final details = AnimeDetailsProvider(
      repository: FakeAnimeRepository(
        charactersFailure: const NetworkError(),
      ),
    );
    addTearDown(details.dispose);
    await details.load('52991');
    expect(details.state, LoadingState.loaded);
    expect(details.anime?.title, 'Frieren');
    expect(details.charactersState, LoadingState.offline);
  });

  test('details missing id is empty', () async {
    final details = AnimeDetailsProvider(repository: FakeAnimeRepository());
    addTearDown(details.dispose);
    await details.load('missing');
    expect(details.state, LoadingState.empty);
  });

  test('toggle favorite persists only anime ids', () async {
    final profiles = FakeProfileRepository();
    final onboarding = OnboardingProvider(repository: FakeUserRepository());
    addTearDown(onboarding.dispose);
    await onboarding.saveProfile(
      authUser: const AuthUser(id: 'user-1', email: 'fan@example.com'),
      username: 'fan',
      isProfileCompleted: true,
    );
    final details = AnimeDetailsProvider(
      repository: FakeAnimeRepository(),
      profiles: profiles,
    );
    addTearDown(details.dispose);
    details.bindFavorites(
      userId: 'user-1',
      favoriteIds: const <String>[],
      onboarding: onboarding,
    );
    await details.load('52991');
    await details.toggleFavorite();
    expect(details.isFavorite, isTrue);
    expect(profiles.lastUpdate?.favoriteAnimeIds, <String>['52991']);
    expect(onboarding.profile?.favoriteAnimeIds, <String>['52991']);
  });

  test('offline catalog maps to offline state', () async {
    final list = AnimeListProvider(
      repository: FakeAnimeRepository(failure: const NetworkError()),
    );
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.top);
    expect(list.state, LoadingState.offline);
  });

  test('hub loads studios alongside genres', () async {
    final hub = AnimeHubProvider(repository: FakeAnimeRepository());
    addTearDown(hub.dispose);
    await hub.load();
    expect(hub.studios, isNotEmpty);
    expect(hub.studios.first.name, 'Madhouse');
    expect(hub.studiosState, LoadingState.loaded);
  });

  test('openStudio browses a studio and paginates', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openStudio(const AnimeStudio(id: '11', name: 'Madhouse'));
    expect(list.studioId, '11');
    expect(list.title, 'Madhouse');
    expect(repository.studioCalls, 1);
    expect(list.items, isNotEmpty);
    await list.loadMore();
    expect(repository.studioCalls, 2);
    expect(list.items.map((item) => item.id), contains('52991-p2'));
  });

  test('character profiles are prefetched and reused instantly', () async {    const preview = AnimeCharacter(
      id: '10',
      name: 'Frieren',
      role: 'Main',
    );
    final repository = FakeAnimeRepository(
      characters: const <AnimeCharacter>[preview],
    );
    final details = AnimeDetailsProvider(repository: repository);
    addTearDown(details.dispose);
    await details.load('52991');
    await Future<void>.delayed(Duration.zero);
    expect(repository.characterDetailsCalls, 1);
    final profile = await details.characterProfile(preview);
    expect(profile.about, 'An elf mage.');
    expect(profile.nameKanji, 'フリーレン');
    expect(profile.role, 'Main');
    expect(repository.characterDetailsCalls, 1);
  });

  test('hub landing destination is the newest-first catalog', () async {
    final repository = FakeAnimeRepository();
    final catalogs = AnimeHubCatalogProvider(repository: repository);
    addTearDown(catalogs.dispose);
    await catalogs.openLanding();
    expect(repository.latestCalls, 1);
    expect(repository.searchCalls, 0);
    expect(repository.latestPages, <int>[1]);
    expect(
      catalogs.catalog(AnimeHubDestination.latest).items,
      isNotEmpty,
    );
  });

  test('hub destinations load lazily and only once', () async {
    final repository = FakeAnimeRepository();
    final catalogs = AnimeHubCatalogProvider(repository: repository);
    addTearDown(catalogs.dispose);
    // Opening the hub costs one request, not one per destination.
    await catalogs.openLanding();
    expect(repository.latestCalls, 1);
    expect(repository.thisSeasonCalls, 0);
    expect(repository.popularCalls, 0);

    await catalogs.open(AnimeHubDestination.thisSeason);
    expect(repository.thisSeasonCalls, 1);
    // Re-opening a destination must not discard the pages already loaded.
    await catalogs.open(AnimeHubDestination.thisSeason);
    await catalogs.openLanding();
    expect(repository.thisSeasonCalls, 1);
    expect(repository.latestCalls, 1);
  });

  test('each hub destination keeps its own pages', () async {
    final repository = FakeAnimeRepository();
    final catalogs = AnimeHubCatalogProvider(repository: repository);
    addTearDown(catalogs.dispose);
    await catalogs.openLanding();
    await catalogs.catalog(AnimeHubDestination.latest).loadMore();
    expect(
      catalogs.catalog(AnimeHubDestination.latest).items.length,
      greaterThan(1),
    );
    await catalogs.open(AnimeHubDestination.popular);
    expect(catalogs.catalog(AnimeHubDestination.popular).items.length, 1);
    expect(repository.latestPages, containsAllInOrder(<int>[1, 2]));
  });

  test('community is not a catalog destination', () async {
    final catalogs = AnimeHubCatalogProvider(
      repository: FakeAnimeRepository(),
    );
    addTearDown(catalogs.dispose);
    expect(AnimeHubDestination.community.isCatalog, isFalse);
    expect(AnimeHubDestination.community.catalogKind, isNull);
    await catalogs.open(AnimeHubDestination.community);
    expect(catalogs.catalog(AnimeHubDestination.community).state,
        LoadingState.initial);
  });

  test('hub catalog provider notifies while a destination pages', () async {
    final catalogs = AnimeHubCatalogProvider(
      repository: FakeAnimeRepository(),
    );
    addTearDown(catalogs.dispose);
    var notifications = 0;
    catalogs.addListener(() => notifications++);
    await catalogs.openLanding();
    expect(notifications, greaterThan(0));
  });
}
