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
    bool? favorite,
  });

  Future<Result<void>> removeEntry(String animeId);

  Future<Result<List<CharacterFavorite>>> getCharacterFavorites();

  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  });

  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId});

  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  });

  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  });

  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  });

  Future<Result<void>> deleteCustomList(String listId);

  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  });

  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  });

  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  );
}
