import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';
import '../models/anime_rating_models.dart';
import 'anime_hub_social_repository.dart';

final class UnavailableAnimeHubSocialRepository
    implements AnimeHubSocialRepository {
  const UnavailableAnimeHubSocialRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult(UnknownError(message));

  @override
  Future<Result<AnimeCommunityStats?>> getAnimeStats(String animeId) async =>
      _fail();

  @override
  Future<Result<AnimeReview?>> getMyRating(String animeId) async => _fail();

  @override
  Future<Result<List<AnimeReview>>> listReviews(
    String animeId, {
    int limit = 30,
  }) async => _fail();

  @override
  Future<Result<AnimeReview>> upsertRating({
    required String animeId,
    required AnimeCriteriaScores criteria,
    String title = '',
    String? imageUrl,
    String comment = '',
  }) async => _fail();

  @override
  Future<Result<void>> deleteRating(String animeId) async => _fail();

  @override
  Future<Result<void>> reportReview({
    required String animeId,
    required String targetUserId,
    required String reason,
    String details = '',
  }) async => _fail();

  @override
  Future<Result<List<AnimeCommunityStats>>> listTopRated({int limit = 40}) async =>
      _fail();

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async => _fail();

  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) async => _fail();

  @override
  Future<Result<List<AnimeReview>>> listUserRatings(String userId) async =>
      _fail();

  @override
  Future<Result<List<AnimeListEntry>>> listUserAnimeList(String userId) async =>
      _fail();

  @override
  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  ) async => _fail();
}
