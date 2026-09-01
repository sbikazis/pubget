import '../../../core/errors/result.dart';
import '../models/anime_models.dart';

abstract interface class AnimeRepository {
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
  });

  Future<Result<Anime>> getAnimeDetails(String id);

  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20});

  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId);

  Future<Result<List<AnimeGenre>>> getGenres();

  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  });

  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons();

  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  });
}

abstract final class AnimeCacheTtl {
  static const details = Duration(hours: 6);
  static const characters = Duration(hours: 6);
  static const genres = Duration(hours: 24);
  static const seasonsIndex = Duration(hours: 24);
  static const seasonList = Duration(hours: 1);
  static const trending = Duration(minutes: 15);
  static const popular = Duration(minutes: 15);
  static const top = Duration(minutes: 15);
  static const airing = Duration(minutes: 10);
  static const upcoming = Duration(minutes: 15);
  static const thisSeason = Duration(minutes: 15);
  static const search = Duration(minutes: 5);
  static const genreList = Duration(minutes: 30);
}
