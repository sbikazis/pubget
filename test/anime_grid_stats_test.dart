import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_hub_social_provider.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';

import 'anime_test_support.dart';

void main() {
  testWidgets('the poster grid batches community stats for its titles', (
    tester,
  ) async {
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: <Anime>[sampleAnime(id: '16498')],
        page: 1,
        hasNextPage: false,
      ),
    );
    final list = AnimeListProvider(repository: repository, debounce: Duration.zero);
    final socialRepository = _RecordingSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    addTearDown(list.dispose);
    addTearDown(social.dispose);
    await list.openCatalog(AnimeCatalogKind.top);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(
            value: NetworkService(probe: () async => true),
          ),
          ChangeNotifierProvider<AnimeListProvider>.value(value: list),
          ChangeNotifierProvider<AnimeHubSocialProvider>.value(value: social),
        ],
        child: MaterialApp(home: Scaffold(body: AnimePaginatedList(list: list))),
      ),
    );
    await tester.pumpAndSettle();

    expect(socialRepository.requests, hasLength(1));
    expect(socialRepository.requests.single, <String>['16498']);
    expect(social.statsFor('16498')?.averageScore, 7.5);
    expect(social.statsFor('16498')?.ratingCount, 3);
  });
}

final class _RecordingSocialRepository implements AnimeHubSocialRepository {
  final List<List<String>> requests = <List<String>>[];

  @override
  Future<Result<List<AnimeCommunityStats>>> getAnimeCommunityStats(
    List<String> animeIds,
  ) async {
    requests.add(List<String>.of(animeIds));
    return Success(<AnimeCommunityStats>[
      for (final id in animeIds)
        AnimeCommunityStats(
          animeId: id,
          title: 'Title $id',
          averageScore: 7.5,
          ratingCount: 3,
        ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
