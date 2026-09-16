import '../../../core/errors/result.dart';
import '../models/anime_models.dart';

abstract interface class AnimeRepository {
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
    AnimeSearchFilter? filter,
  });

  Future<Result<Anime>> getAnimeDetails(String id);

  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20});

  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20});

  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId);

  Future<Result<AnimeCharacter>> getCharacterDetails(String characterId);

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
  static const details = Duration(hours: 12);
  static const characters = Duration(hours: 12);
  static const characterDetails = Duration(hours: 12);
  static const genres = Duration(hours: 24);
  static const seasonsIndex = Duration(hours: 24);
  static const seasonList = Duration(hours: 6);
  static const trending = Duration(hours: 2);
  static const popular = Duration(hours: 2);
  static const top = Duration(hours: 2);
  static const airing = Duration(hours: 1);
  static const upcoming = Duration(hours: 2);
  static const thisSeason = Duration(hours: 1);
  static const search = Duration(minutes: 20);
  static const genreList = Duration(hours: 2);
}
