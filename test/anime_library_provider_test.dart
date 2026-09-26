import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
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
    expect(repository.writeCount, 2);
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

  test('custom lists can be created and appear in memberships', () async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository);
    addTearDown(library.dispose);
    library.bindUser('alice');
    await library.load();
    await library.createCustomList(
      name: 'Blood pressure',
      private: false,
      animeIds: const <String>['21'],
    );
    expect(library.customLists, hasLength(1));
    expect(library.customLists.single.itemsCount, 1);
    expect(library.isInCustomList('21', 'auto1'), isTrue);
    expect(library.membershipsFor('21').single.name, 'Blood pressure');
  });

  test('custom list membership toggles maintain counts', () async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository);
    addTearDown(library.dispose);
    library.bindUser('alice');
    await library.load();
    await library.createCustomList(name: 'Watch later');
    await library.addToCustomList(
      listId: 'auto1',
      animeId: '99',
      title: 'Code Geass',
    );
    expect(library.isInCustomList('99', 'auto1'), isTrue);
    expect(library.customLists.single.itemsCount, 1);
    await library.removeFromCustomList(listId: 'auto1', animeId: '99');
    expect(library.isInCustomList('99', 'auto1'), isFalse);
    expect(library.customLists.single.itemsCount, 0);
  });

  test('custom list rename, delete, and membership load work', () async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository);
    addTearDown(library.dispose);
    library.bindUser('alice');
    await library.load();
    await library.createCustomList(name: 'First');
    await library.loadCustomListMembership('21');
    expect(library.membershipsFor('21'), isEmpty);
    await library.updateCustomList(listId: 'auto1', name: 'Renamed');
    expect(library.customLists.single.name, 'Renamed');
    await library.loadCustomList('auto1');
    expect(library.customListDetail('auto1')?.list.name, 'Renamed');
    await library.removeCustomList('auto1');
    expect(library.customLists, isEmpty);
  });
}

final class _FakeLibraryRepository implements AnimeLibraryRepository {
  final Map<String, AnimeListEntry> entries = <String, AnimeListEntry>{};
  final Set<String> characters = <String>{};
  final Map<String, AnimeCustomList> customLists = <String, AnimeCustomList>{};
  final Map<String, Set<String>> customItems = <String, Set<String>>{};
  final Map<String, AnimeCustomListDetail> customDetails =
      <String, AnimeCustomListDetail>{};
  int writeCount = 0;
  int autoId = 0;

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
    writeCount += 1;
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
  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId}) async =>
      Success(customLists.values.toList(growable: false));

  @override
  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  }) async => Success(
    customDetails[listId] ??
        AnimeCustomListDetail(
          list: customLists[listId] ?? const AnimeCustomList(id: '', name: ''),
          items: (customItems[listId] ?? <String>{})
              .map((id) => AnimeCustomListItem(animeId: id, title: id))
              .toList(growable: false),
        ),
  );

  @override
  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async {
    writeCount += 1;
    autoId += 1;
    final id = 'auto$autoId';
    final list = AnimeCustomList(
      id: id,
      name: name,
      description: description,
      private: private,
      itemsCount: animeIds.length,
      ownerUid: 'alice',
    );
    customLists[id] = list;
    customItems[id] = animeIds.toSet();
    return Success(list);
  }

  @override
  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async {
    final current = customLists[listId];
    if (current == null) {
      return const FailureResult(UnknownError('missing'));
    }
    customLists[listId] = current.copyWith(
      name: name,
      description: description,
      private: private,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteCustomList(String listId) async {
    customLists.remove(listId);
    customItems.remove(listId);
    customDetails.remove(listId);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async {
    final set = customItems[listId] ?? <String>{};
    set.add(animeId);
    customItems[listId] = set;
    final current = customLists[listId];
    if (current != null) {
      customLists[listId] = current.copyWith(itemsCount: set.length);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async {
    (customItems[listId] ?? <String>{}).remove(animeId);
    final current = customLists[listId];
    if (current != null) {
      customLists[listId] = current.copyWith(itemsCount: current.itemsCount - 1);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  ) async {
    final memberships = <CustomListMembership>[];
    customItems.forEach((listId, animeIds) {
      if (animeIds.contains(animeId)) {
        final name = customLists[listId]?.name ?? '';
        memberships.add(CustomListMembership(listId: listId, name: name));
      }
    });
    return Success(memberships);
  }
}
