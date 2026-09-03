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
  final Set<String> _characterIds = <String>{};
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
      _characterIds.contains(characterId);

  List<AnimeListEntry> byStatus(AnimeListStatus status) => entries
      .where((entry) => entry.status == status)
      .toList(growable: false);

  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _entries.clear();
    _characterIds.clear();
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
        _characterIds
          ..clear()
          ..addAll(items.map((item) => item.characterId));
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
  }) async {
    _saving = true;
    _safeNotify();
    final result = await _repository.setEntry(
      animeId: animeId,
      status: status,
      title: title,
      rating: rating,
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
  }) async {
    final next = !_characterIds.contains(characterId);
    if (next) {
      _characterIds.add(characterId);
    } else {
      _characterIds.remove(characterId);
    }
    _safeNotify();
    final result = await _repository.setCharacterFavorite(
      characterId: characterId,
      favorite: next,
      name: name,
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
        if (next) {
          _characterIds.remove(characterId);
        } else {
          _characterIds.add(characterId);
        }
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
