import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';
import '../models/anime_rating_models.dart';

abstract interface class AnimeHubSocialRepository {
  Future<Result<AnimeCommunityStats?>> getAnimeStats(String animeId);

  Future<Result<AnimeReview?>> getMyRating(String animeId);

  Future<Result<List<AnimeReview>>> listReviews(String animeId, {int limit = 30});

  Future<Result<AnimeReview>> upsertRating({
    required String animeId,
    required AnimeCriteriaScores criteria,
    String title = '',
    String? imageUrl,
    String comment = '',
  });

  Future<Result<void>> deleteRating(String animeId);

  Future<Result<void>> reportReview({
    required String animeId,
    required String targetUserId,
    required String reason,
    String details = '',
  });

  Future<Result<List<AnimeCommunityStats>>> listTopRated({int limit = 40});

  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  });

  Future<Result<CharacterCommunityStats?>> getCharacterStats(String characterId);

  Future<Result<List<AnimeReview>>> listUserRatings(String userId);

  Future<Result<List<AnimeListEntry>>> listUserAnimeList(String userId);

  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  );
}
