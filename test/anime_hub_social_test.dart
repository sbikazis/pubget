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
      AnimeDisplayedScore.resolveAll(
        malScore: 7.2,
        community: null,
      ).map((item) => item.badge).toList(),
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

    await social.loadMostListed();
    expect(social.mostListedState, LoadingState.loaded);
    expect(social.mostListed.single.animeId, '16498');
    expect(social.mostListed.single.listedCount, 24);
    expect(social.mostListed.single.hasListings, isTrue);

    await social.loadUser('alice');
    expect(social.userRatings.single.overall, 9.0);
    expect(social.userList.single.status, AnimeListStatus.watching);
    expect(social.userCharacters.single.characterId, 'erwin');
  });

  test('character discussion loads, posts, and deletes', () async {
    final repository = _FakeHubSocialRepository();
    final social = AnimeHubSocialProvider(repository: repository);
    addTearDown(social.dispose);

    await social.loadCharacterDiscussion('erwin');
    expect(social.discussionState, LoadingState.loaded);
    expect(social.discussions.single.text, 'Best commander.');

    final posted = await social.postCharacterDiscussion(
      characterId: 'erwin',
      text: 'A true leader.',
    );
    expect(posted.isSuccess, isTrue);
    expect(social.discussions.first.text, 'A true leader.');
    expect(social.discussions, hasLength(2));

    await social.deleteCharacterDiscussion(
      characterId: 'erwin',
      postId: 'post-new',
    );
    expect(social.discussions, hasLength(1));
    expect(social.discussions.single.id, 'post-1');
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

  // -------------------------------------------------------------------------
  // Server-authoritative aggregates: parsing, and the unavailable state
  // -------------------------------------------------------------------------

  group('AnimeCommunityStats aggregate parsing', () {
    test('reads the score distribution and the five-state breakdown', () {
      final stats = AnimeCommunityStats.fromMap(<String, dynamic>{
        'animeId': '16498',
        'scoreDistribution': <String, dynamic>{
          '1': 0,
          '7': 2,
          '9': 5,
          '10': 1,
        },
        'statusCounts': <String, dynamic>{
          'want_to_watch': 40,
          'watching': 25,
          'completed': 30,
          'watch_later': 3,
          'not_interested': 2,
        },
      }, id: '16498');

      expect(stats.scoreDistribution, isNotNull);
      expect(stats.scoreDistribution!.countFor(7), 2);
      expect(stats.scoreDistribution!.countFor(9), 5);
      expect(stats.scoreDistribution!.countFor(10), 1);
      expect(stats.scoreDistribution!.countFor(3), 0);
      expect(stats.scoreDistribution!.total, 8);
      expect(stats.hasScoreDistribution, isTrue);

      expect(stats.statusCounts, isNotNull);
      expect(stats.statusCounts!.countFor(AnimeListStatus.completed), 30);
      expect(stats.statusCounts!.countFor(AnimeListStatus.notInterested), 2);
      expect(stats.statusCounts!.total, 100);
      expect(stats.hasStatusCounts, isTrue);
    });

    test('keys outside 1-10 never leak into a bucket', () {
      final stats = AnimeCommunityStats.fromMap(<String, dynamic>{
        'scoreDistribution': <String, dynamic>{
          '0': 4,
          '11': 9,
          'bogus': 3,
          '7': 2,
        },
      });
      // Only the ten real buckets are read.
      expect(stats.scoreDistribution!.countFor(7), 2);
      expect(stats.scoreDistribution!.total, 2);
      for (var score = 1; score <= 10; score++) {
        if (score == 7) continue;
        expect(stats.scoreDistribution!.countFor(score), 0, reason: '$score');
      }
      expect(stats.scoreDistribution!.countFor(0), 0);
      expect(stats.scoreDistribution!.countFor(11), 0);
    });

    test('a distribution with no valid bucket is unavailable, not all-zero', () {
      // A real all-zero distribution and a corrupt one are different facts,
      // and only the shape of the document can tell them apart.
      final corrupt = AnimeCommunityStats.fromMap(<String, dynamic>{
        'scoreDistribution': <String, dynamic>{'0': 4, '11': 9, 'bogus': 3},
      });
      expect(corrupt.scoreDistribution, isNull);
      final empty = AnimeCommunityStats.fromMap(<String, dynamic>{
        'scoreDistribution': <String, dynamic>{
          for (var score = 1; score <= 10; score++) '$score': 0,
        },
      });
      expect(empty.scoreDistribution, isNotNull);
      expect(empty.scoreDistribution!.total, 0);
      expect(empty.hasScoreDistribution, isFalse);
    });

    test('a missing aggregate is unavailable, not an empty chart', () {
      // The pre-migration shape: counts but no distribution.
      final stats = AnimeCommunityStats.fromMap(<String, dynamic>{
        'animeId': '16498',
        'ratingCount': 12,
        'listedCount': 90,
        'averageScore': 8.8,
      });
      expect(stats.scoreDistribution, isNull);
      expect(stats.statusCounts, isNull);
      expect(stats.hasScoreDistribution, isFalse);
      expect(stats.hasStatusCounts, isFalse);
      // The counts it does have are untouched.
      expect(stats.ratingCount, 12);
      expect(stats.listedCount, 90);
    });

    test('a malformed aggregate is unavailable rather than half-read', () {
      for (final raw in <Object>[7, 'junk', <String, dynamic>{}, true]) {
        final stats = AnimeCommunityStats.fromMap(<String, dynamic>{
          'scoreDistribution': raw,
          'statusCounts': raw,
        });
        expect(stats.scoreDistribution, isNull, reason: '\$raw');
        expect(stats.statusCounts, isNull, reason: '\$raw');
      }
    });

    test('a partial status breakdown is honoured, not padded to zero', () {
      final stats = AnimeCommunityStats.fromMap(<String, dynamic>{
        'statusCounts': <String, dynamic>{'watching': 12, 'unknown_state': 5},
      });
      expect(stats.statusCounts!.countFor(AnimeListStatus.watching), 12);
      expect(stats.statusCounts!.countFor(AnimeListStatus.completed), 0);
      expect(
        stats.statusCounts!.total,
        12,
        reason: 'an unknown key is not counted',
      );
    });
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
  Future<Result<List<AnimeCommunityStats>>> listTopRated({
    int limit = 40,
  }) async => const Success(<AnimeCommunityStats>[
    AnimeCommunityStats(
      animeId: '16498',
      title: 'Attack on Titan',
      averageScore: 8.8,
      ratingCount: 12,
    ),
  ]);

  @override
  Future<Result<List<AnimeCommunityStats>>> listMostListed({
    int limit = 40,
  }) async => const Success(<AnimeCommunityStats>[
    AnimeCommunityStats(
      animeId: '16498',
      title: 'Attack on Titan',
      listedCount: 24,
    ),
  ]);

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async => const Success(<CharacterCommunityStats>[
    CharacterCommunityStats(
      characterId: 'erwin',
      name: 'Erwin Smith',
      favoritesCount: 42,
    ),
  ]);

  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) async => Success(
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
  Future<Result<List<AnimeCustomList>>> listUserCustomAnimeLists(
    String userId,
  ) async => const Success(<AnimeCustomList>[AnimeCustomList(
    id: 'list-1',
    name: 'My cool list',
    description: '',
    private: false,
    itemsCount: 3,
  )]);

  @override
  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  ) async => const Success(<CharacterFavorite>[
    CharacterFavorite(characterId: 'erwin', name: 'Erwin Smith'),
  ]);

  @override
  Future<Result<List<CharacterDiscussion>>> listCharacterDiscussions(
    String characterId, {
    int limit = 30,
  }) async => const Success(<CharacterDiscussion>[
    CharacterDiscussion(
      id: 'post-1',
      characterId: 'erwin',
      userId: 'alice',
      username: 'Alice',
      text: 'Best commander.',
    ),
  ]);

  @override
  Future<Result<CharacterDiscussion>> postCharacterDiscussion({
    required String characterId,
    required String text,
  }) async => Success(
    CharacterDiscussion(
      id: 'post-new',
      characterId: characterId,
      userId: 'alice',
      username: 'Alice',
      text: text,
    ),
  );

  @override
  Future<Result<void>> deleteCharacterDiscussion({
    required String characterId,
    required String postId,
  }) async => const Success<void>(null);
}
