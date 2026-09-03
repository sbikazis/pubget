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
    int? rating,
  }) async => _fail();
}
