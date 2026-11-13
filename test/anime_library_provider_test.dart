import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/repositories/anime_library_repository.dart';

void main() {
  test('list status upserts one entry per anime', () async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository);
    addTearDown(library.dispose);
    library.bindUser('alice');
    await library.load();
    await library.setStatus(
      animeId: '21',
      status: AnimeListStatus.watching,
      title: 'One Piece',
      rating: 9,
    );
    await library.setStatus(
      animeId: '21',
      status: AnimeListStatus.completed,
      title: 'One Piece',
      rating: 10,
    );
    expect(library.entryFor('21')?.status, AnimeListStatus.completed);
    expect(library.entryFor('21')?.rating, 10);
    expect(library.byStatus(AnimeListStatus.watching), isEmpty);
    expect(repository.writes, 2);
  });

  test('character favorites toggle without duplicating ids', () async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository);
    addTearDown(library.dispose);
    library.bindUser('alice');
    await library.load();
    await library.toggleCharacter(characterId: 'luffy', name: 'Luffy');
    expect(library.isCharacterFavorite('luffy'), isTrue);
    await library.toggleCharacter(characterId: 'luffy', name: 'Luffy');
    expect(library.isCharacterFavorite('luffy'), isFalse);
  });

  test('unauthenticated library stays empty', () async {
    final library = AnimeLibraryProvider(repository: _FakeLibraryRepository());
    addTearDown(library.dispose);
    await library.load();
    expect(library.state, LoadingState.empty);
  });
}

final class _FakeLibraryRepository implements AnimeLibraryRepository {
  final Map<String, AnimeListEntry> entries = <String, AnimeListEntry>{};
  final Set<String> characters = <String>{};
  int writes = 0;

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  }) async {
    final items = entries.values
        .where((entry) => status == null || entry.status == status)
        .toList(growable: false);
    return Success(AnimeListPage(items: items, hasMore: false));
  }

  @override
  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
    bool? favorite,
  }) async {
    writes += 1;
    final entry = AnimeListEntry(
      animeId: animeId,
      status: status,
      title: title,
      rating: rating,
      favorite: favorite ?? false,
    );
    entries[animeId] = entry;
    return Success(entry);
  }

  @override
  Future<Result<void>> removeEntry(String animeId) async {
    entries.remove(animeId);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async =>
      Success(
        characters
            .map((id) => CharacterFavorite(characterId: id, name: id))
            .toList(growable: false),
      );

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async {
    if (favorite) {
      characters.add(characterId);
    } else {
      characters.remove(characterId);
    }
    return Success(
      CharacterFavorite(characterId: characterId, name: name, rating: rating),
    );
  }

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({
    String? userId,
  }) async =>
      Success<List<AnimeCustomList>>(const <AnimeCustomList>[]);

  @override
  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  }) async => Success<AnimeCustomListDetail>(
    AnimeCustomListDetail(
      list: AnimeCustomList(id: listId, name: ''),
    ),
  );

  @override
  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async => Success<AnimeCustomList>(
    AnimeCustomList(
      id: 'list-1',
      name: name,
      description: description,
      private: private,
      itemsCount: animeIds.length,
    ),
  );

  @override
  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> deleteCustomList(String listId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async => const Success<void>(null);

  @override
  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  ) async =>
      Success<List<CustomListMembership>>(const <CustomListMembership>[]);
}
