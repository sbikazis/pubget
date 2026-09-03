import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';

abstract interface class AnimeLibraryRepository {
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  });

  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
  });

  Future<Result<void>> removeEntry(String animeId);

  Future<Result<List<CharacterFavorite>>> getCharacterFavorites();

  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    int? rating,
  });
}
