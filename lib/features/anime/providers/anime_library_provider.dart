import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_list_models.dart';
import '../repositories/anime_library_repository.dart';

final class AnimeLibraryProvider extends ChangeNotifier {
  AnimeLibraryProvider({
    required AnimeLibraryRepository repository,
    Analytics? analytics,
  }) : _repository = repository,
       _analytics = analytics;

  final AnimeLibraryRepository _repository;
  final Analytics? _analytics;
  final Map<String, AnimeListEntry> _entries = <String, AnimeListEntry>{};
  final Map<String, CharacterFavorite> _characterFavorites =
      <String, CharacterFavorite>{};
  final Map<String, AnimeCustomList> _customListsById =
      <String, AnimeCustomList>{};
  final Map<String, AnimeCustomListDetail> _customListDetails =
      <String, AnimeCustomListDetail>{};
  final Map<String, List<CustomListMembership>> _membershipsByAnime =
      <String, List<CustomListMembership>>{};
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _saving = false;
  bool _disposed = false;
  String? _userId;
  int _loadGeneration = 0;

  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get saving => _saving;
  List<AnimeListEntry> get entries => List<AnimeListEntry>.unmodifiable(
    _entries.values.toList(growable: false),
  );

  AnimeListEntry? entryFor(String animeId) => _entries[animeId];

  bool isCharacterFavorite(String characterId) =>
      _characterFavorites.containsKey(characterId);

  CharacterFavorite? characterFavorite(String characterId) =>
      _characterFavorites[characterId];

  List<AnimeListEntry> byStatus(AnimeListStatus status) =>
      entries.where((entry) => entry.status == status).toList(growable: false);

  List<AnimeListEntry> get favoriteAnime =>
      entries.where((entry) => entry.favorite).toList(growable: false);

  List<AnimeCustomList> get customLists =>
      List<AnimeCustomList>.unmodifiable(_customListsById.values);

  AnimeCustomList? customListById(String listId) => _customListsById[listId];

  AnimeCustomListDetail? customListDetail(String listId) =>
      _customListDetails[listId];

  List<CustomListMembership> membershipsFor(String animeId) =>
      _membershipsByAnime[animeId] ?? const <CustomListMembership>[];

  bool isInCustomList(String animeId, String listId) =>
      membershipsFor(animeId).any((membership) => membership.listId == listId);

  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _entries.clear();
    _characterFavorites.clear();
    _customListsById.clear();
    _customListDetails.clear();
    _membershipsByAnime.clear();
    _state = LoadingState.initial;
    _failure = null;
    _loadGeneration += 1;
    if (userId != null) {
      unawaited(load());
    } else {
      _safeNotify();
    }
  }

  Future<void> load() async {
    if (_userId == null) {
      _state = LoadingState.empty;
      _safeNotify();
      return;
    }
    final generation = ++_loadGeneration;
    _state = _entries.isEmpty ? LoadingState.loading : LoadingState.refreshing;
    _failure = null;
    _safeNotify();
    final lists = await _repository.getList(limit: 50);
    final characters = await _repository.getCharacterFavorites();
    final customs = await _repository.getCustomLists();
    if (_disposed || generation != _loadGeneration) return;
    lists.fold(
      onSuccess: (page) {
        _entries
          ..clear()
          ..addEntries(
            page.items.map((entry) => MapEntry(entry.animeId, entry)),
          );
        _state = LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _entries.isEmpty ? LoadingState.error : LoadingState.offline;
      },
    );
    characters.fold(
      onSuccess: (items) {
        _characterFavorites
          ..clear()
          ..addEntries(items.map((item) => MapEntry(item.characterId, item)));
      },
      onFailure: (_) {},
    );
    customs.fold(
      onSuccess: (items) {
        _customListsById
          ..clear()
          ..addEntries(items.map((item) => MapEntry(item.id, item)));
      },
      onFailure: (_) {},
    );
    _safeNotify();
  }

  Future<Result<void>> setStatus({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
    bool? favorite,
  }) async {
    _saving = true;
    _safeNotify();
    final result = await _repository.setEntry(
      animeId: animeId,
      status: status,
      title: title,
      rating: rating,
      favorite: favorite,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (entry) {
        _entries[entry.animeId] = entry;
        _analytics?.logEvent(
          'anime_list_updated',
          parameters: {'status': status.wireValue},
        );
        _state = LoadingState.loaded;
      },
      onFailure: (failure) => _failure = failure,
    );
    _saving = false;
    _safeNotify();
    return _asVoid(result);
  }

  /// Flips only the heart, leaving the personal status untouched.
  Future<Result<void>> setFavorite({
    required String animeId,
    required bool favorite,
    String title = '',
  }) => setStatus(
    animeId: animeId,
    status: entryFor(animeId)?.status ?? AnimeListStatus.wantToWatch,
    title: title,
    rating: entryFor(animeId)?.rating,
    favorite: favorite,
  );

  bool isFavorite(String animeId) => entryFor(animeId)?.favorite ?? false;

  Future<Result<void>> remove(String animeId) async {
    _saving = true;
    _safeNotify();
    final result = await _repository.removeEntry(animeId);
    if (_disposed) return result;
    if (result.isSuccess) _entries.remove(animeId);
    _saving = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> toggleCharacter({
    required String characterId,
    required String name,
    String? imageUrl,
  }) async {
    final previous = _characterFavorites[characterId];
    final next = previous == null;
    if (next) {
      _characterFavorites[characterId] = CharacterFavorite(
        characterId: characterId,
        name: name,
        imageUrl: imageUrl,
      );
    } else {
      _characterFavorites.remove(characterId);
    }
    _safeNotify();
    final result = await _repository.setCharacterFavorite(
      characterId: characterId,
      favorite: next,
      name: name,
      imageUrl: imageUrl,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {
        _analytics?.logEvent(
          next ? 'character_favorite' : 'character_unfavorite',
          parameters: {'length': characterId.length},
        );
      },
      onFailure: (failure) {
        if (previous == null) {
          _characterFavorites.remove(characterId);
        } else {
          _characterFavorites[characterId] = previous;
        }
        _failure = failure;
      },
    );
    _safeNotify();
    return _asVoid(result);
  }

  Future<Result<void>> setCharacterRating({
    required String characterId,
    required int rating,
    String name = '',
    String? imageUrl,
  }) async {
    final clamped = rating.clamp(1, 10);
    final previous = _characterFavorites[characterId];
    _characterFavorites[characterId] = CharacterFavorite(
      characterId: characterId,
      name: name.isEmpty ? previous?.name ?? '' : name,
      imageUrl: imageUrl ?? previous?.imageUrl,
      rating: clamped,
    );
    _saving = true;
    _safeNotify();
    final result = await _repository.setCharacterFavorite(
      characterId: characterId,
      favorite: true,
      name: name,
      imageUrl: imageUrl,
      rating: clamped,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {
        _analytics?.logEvent(
          'character_rating',
          parameters: {'rating': clamped},
        );
      },
      onFailure: (failure) {
        if (previous == null) {
          _characterFavorites.remove(characterId);
        } else {
          _characterFavorites[characterId] = previous;
        }
        _failure = failure;
      },
    );
    _saving = false;
    _safeNotify();
    return _asVoid(result);
  }

  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async {
    _saving = true;
    _safeNotify();
    final result = await _repository.createCustomList(
      name: name,
      description: description,
      private: private,
      animeIds: animeIds,
    );
    if (_disposed) return result;
    result.fold(
      onSuccess: (list) {
        if (list.id.isNotEmpty) {
          _customListsById[list.id] = list;
          for (final animeId in animeIds) {
            final current =
                _membershipsByAnime[animeId] ?? const <CustomListMembership>[];
            if (!current.any((item) => item.listId == list.id)) {
              _membershipsByAnime[animeId] = <CustomListMembership>[
                CustomListMembership(listId: list.id, name: list.name),
                ...current,
              ];
            }
          }
        }
        _analytics?.logEvent('custom_list_created');
      },
      onFailure: (failure) => _failure = failure,
    );
    _saving = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async {
    final previous = _customListsById[listId];
    if (previous != null) {
      _customListsById[listId] = previous.copyWith(
        name: name,
        description: description,
        private: private,
      );
    }
    _saving = true;
    _safeNotify();
    final result = await _repository.updateCustomList(
      listId: listId,
      name: name,
      description: description,
      private: private,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) {
        if (previous != null) _customListsById[listId] = previous;
        _failure = failure;
      },
    );
    _saving = false;
    _safeNotify();
    return _asVoid(result);
  }

  Future<Result<void>> removeCustomList(String listId) async {
    final previous = _customListsById[listId];
    _customListsById.remove(listId);
    _customListDetails.remove(listId);
    _saving = true;
    _safeNotify();
    final result = await _repository.deleteCustomList(listId);
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {
        _analytics?.logEvent('custom_list_deleted');
      },
      onFailure: (failure) {
        if (previous != null) _customListsById[listId] = previous;
        _failure = failure;
      },
    );
    _saving = false;
    _safeNotify();
    return _asVoid(result);
  }

  Future<void> loadCustomList(String listId, {String? userId}) async {
    final result = await _repository.getCustomList(
      listId: listId,
      userId: userId,
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (detail) {
        _customListDetails[listId] = detail;
        if (detail.list.id.isNotEmpty) {
          _customListsById[detail.list.id] = detail.list;
        }
      },
      onFailure: (_) {},
    );
    _safeNotify();
  }

  Future<void> loadCustomListMembership(String animeId) async {
    final result = await _repository.getCustomListMembership(animeId);
    if (_disposed) return;
    result.fold(
      onSuccess: (items) {
        _membershipsByAnime[animeId] = items;
        _safeNotify();
      },
      onFailure: (_) {},
    );
  }

  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async {
    final membership = CustomListMembership(
      listId: listId,
      name: _customListsById[listId]?.name ?? '',
    );
    final current =
        _membershipsByAnime[animeId] ?? const <CustomListMembership>[];
    if (!current.any((item) => item.listId == listId)) {
      _membershipsByAnime[animeId] = <CustomListMembership>[
        membership,
        ...current,
      ];
    }
    final list = _customListsById[listId];
    if (list != null) {
      _customListsById[listId] = list.copyWith(itemsCount: list.itemsCount + 1);
    }
    _safeNotify();
    final result = await _repository.addToCustomList(
      listId: listId,
      animeId: animeId,
      title: title,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) {
        _membershipsByAnime[animeId] = current;
        if (list != null) _customListsById[listId] = list;
        _failure = failure;
      },
    );
    _safeNotify();
    return _asVoid(result);
  }

  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async {
    final current =
        _membershipsByAnime[animeId] ?? const <CustomListMembership>[];
    _membershipsByAnime[animeId] = current
        .where((item) => item.listId != listId)
        .toList(growable: false);
    final list = _customListsById[listId];
    if (list != null) {
      final next = list.itemsCount - 1;
      _customListsById[listId] = list.copyWith(itemsCount: next < 0 ? 0 : next);
    }
    _safeNotify();
    final result = await _repository.removeFromCustomList(
      listId: listId,
      animeId: animeId,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) {
        _membershipsByAnime[animeId] = current;
        if (list != null) _customListsById[listId] = list;
        _failure = failure;
      },
    );
    _safeNotify();
    return _asVoid(result);
  }

  Result<void> _asVoid<T>(Result<T> result) {
    return result.fold(
      onSuccess: (_) => const Success<void>(null),
      onFailure: FailureResult<void>.new,
    );
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

AnimeLibraryProvider? maybeAnimeLibrary(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<AnimeLibraryProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
