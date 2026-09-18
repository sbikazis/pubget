import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';
import 'anime_library_repository.dart';

final class UnavailableAnimeLibraryRepository
    implements AnimeLibraryRepository {
  const UnavailableAnimeLibraryRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult(UnknownError(message));

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
  }) async => _fail();

  @override
  Future<Result<void>> removeEntry(String animeId) async => _fail();

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async =>
      _fail();

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async => _fail();

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId}) async =>
      _fail();

  @override
  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  }) async => _fail();

  @override
  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async => _fail();

  @override
  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async => _fail();

  @override
  Future<Result<void>> deleteCustomList(String listId) async => _fail();

  @override
  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async => _fail();

  @override
  @override
  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async => _fail();

  @override
  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  ) async => _fail();
}
