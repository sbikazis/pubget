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
    expect(hub.section(AnimeCatalogKind.trending).items, isNotEmpty);
    expect(hub.genres, isNotEmpty);
    expect(hub.seasons, isNotEmpty);
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
}
