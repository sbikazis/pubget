import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_hub_social_provider.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';

void main() {
  test('details, rankings, and profile panel load fixture ratings', () async {
    final repository = _FakeHubSocialRepository();
    final social = AnimeHubSocialProvider(repository: repository);
    addTearDown(social.dispose);

    await social.loadAnime('16498');
    expect(social.stats?.averageScore, 8.8);
    expect(social.stats?.ratingCount, 12);
    expect(social.myRating?.overall, 9.0);
    expect(social.reviews.single.comment, 'Masterpiece.');

    final saved = await social.saveRating(
      criteria: const AnimeCriteriaScores(
        story: 10,
        art: 9,
        characters: 9,
        action: 8,
        sound: 8,
        enjoyment: 10,
      ),
      title: 'Attack on Titan',
      comment: 'Even better on rewatch.',
    );
    expect(saved.isSuccess, isTrue);
    expect(social.myRating?.comment, 'Even better on rewatch.');

    await social.loadTopRated();
    expect(social.topState, LoadingState.loaded);
    expect(social.topRated.single.animeId, '16498');
    expect(social.statsFor('16498')?.hasRatings, isTrue);
    expect(
      AnimeDisplayedScore.resolve(
        malScore: 7.2,
        community: social.statsFor('16498'),
      )?.badge,
      'A',
    );
    expect(
      AnimeDisplayedScore.resolveAll(
        malScore: 7.2,
        community: social.statsFor('16498'),
      ).map((item) => item.badge).toList(),
      <String>['A', 'M'],
    );
    expect(
      AnimeDisplayedScore.resolve(malScore: 7.2, community: null)?.badge,
      'M',
    );
    expect(
      AnimeDisplayedScore.resolveAll(malScore: 7.2, community: null)
          .map((item) => item.badge)
          .toList(),
      <String>['M'],
    );
    expect(
      AnimeDisplayedScore.resolveAll(
        malScore: 7.2,
        community: const AnimeCommunityStats(animeId: 'x'),
      ).map((item) => item.badge).toList(),
      <String>['M'],
    );

    await social.loadPopularCharacters();
    expect(social.popularCharacters.single.favoritesCount, 42);

    await social.loadUser('alice');
    expect(social.userRatings.single.overall, 9.0);
    expect(social.userList.single.status, AnimeListStatus.watching);
    expect(social.userCharacters.single.characterId, 'erwin');
  });

  test('unweighted mean of the six default criteria', () {
    const scores = AnimeCriteriaScores(
      story: 8,
      art: 9,
      characters: 10,
      action: 7,
      sound: 8,
      enjoyment: 9,
    );
    expect(scores.overall, closeTo(8.5, 0.0001));
    expect(scores.toMap().keys, hasLength(6));
  });
}

final class _FakeHubSocialRepository implements AnimeHubSocialRepository {
  AnimeReview mine = const AnimeReview(
    animeId: '16498',
    userId: 'alice',
    username: 'Alice',
    title: 'Attack on Titan',
    overall: 9.0,
    comment: 'Masterpiece.',
    criteria: AnimeCriteriaScores(
      story: 9,
      art: 9,
      characters: 10,
      action: 8,
      sound: 8,
      enjoyment: 10,
    ),
  );

  @override
  Future<Result<AnimeCommunityStats?>> getAnimeStats(String animeId) async =>
      Success(
        AnimeCommunityStats(
          animeId: animeId,
          title: 'Attack on Titan',
          averageScore: 8.8,
          ratingCount: 12,
        ),
      );

  @override
  Future<Result<AnimeReview?>> getMyRating(String animeId) async =>
      Success(mine);

  @override
  Future<Result<List<AnimeReview>>> listReviews(
    String animeId, {
    int limit = 30,
  }) async => Success(<AnimeReview>[mine]);

  @override
  Future<Result<AnimeReview>> upsertRating({
    required String animeId,
    required AnimeCriteriaScores criteria,
    String title = '',
    String? imageUrl,
    String comment = '',
  }) async {
    mine = AnimeReview(
      animeId: animeId,
      userId: 'alice',
      username: 'Alice',
      title: title,
      imageUrl: imageUrl,
      criteria: criteria,
      overall: (criteria.overall * 10).round() / 10,
      comment: comment,
    );
    return Success(mine);
  }

  @override
  Future<Result<void>> deleteRating(String animeId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> reportReview({
    required String animeId,
    required String targetUserId,
    required String reason,
    String details = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<List<AnimeCommunityStats>>> listTopRated({int limit = 40}) async =>
      const Success(<AnimeCommunityStats>[
        AnimeCommunityStats(
          animeId: '16498',
          title: 'Attack on Titan',
          averageScore: 8.8,
          ratingCount: 12,
        ),
      ]);

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async =>
      const Success(<CharacterCommunityStats>[
        CharacterCommunityStats(
          characterId: 'erwin',
          name: 'Erwin Smith',
          favoritesCount: 42,
        ),
      ]);

  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) async =>
      Success(
        CharacterCommunityStats(
          characterId: characterId,
          name: 'Erwin Smith',
          favoritesCount: 42,
        ),
      );

  @override
  Future<Result<List<AnimeReview>>> listUserRatings(String userId) async =>
      Success(<AnimeReview>[mine]);

  @override
  Future<Result<List<AnimeListEntry>>> listUserAnimeList(String userId) async =>
      const Success(<AnimeListEntry>[
        AnimeListEntry(
          animeId: '16498',
          status: AnimeListStatus.watching,
          title: 'Attack on Titan',
        ),
      ]);

  @override
  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  ) async =>
      const Success(<CharacterFavorite>[
        CharacterFavorite(characterId: 'erwin', name: 'Erwin Smith'),
      ]);
}
