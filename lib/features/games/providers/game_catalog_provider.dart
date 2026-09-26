import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../models/game_models.dart';
import '../repositories/game_repository.dart';

/// Searches the canonical Anime and Character catalog.
///
/// Games must only ever submit real catalog IDs, so this provider is the only
/// way the client names an Anime or Character. Results are cached per query so
/// a rebuild or a back navigation does not spend another provider call, and a
/// stale response is dropped so results always match the current query.
final class GameCatalogProvider extends ChangeNotifier {
  GameCatalogProvider({required GameRepository repository})
    : _repository = repository;

  final GameRepository _repository;
  final Map<String, List<CharacterSearchItem>> _characterCache =
      <String, List<CharacterSearchItem>>{};
  final Map<String, List<AnimeSearchItem>> _animeCache =
      <String, List<AnimeSearchItem>>{};

  List<CharacterSearchItem> _characters = const <CharacterSearchItem>[];
  List<AnimeSearchItem> _anime = const <AnimeSearchItem>[];
  String _characterQuery = '';
  String _animeQuery = '';
  bool _searching = false;
  Failure? _failure;
  Timer? _debounce;
  int _request = 0;
  bool _disposed = false;

  List<CharacterSearchItem> get characters => _characters;
  List<AnimeSearchItem> get anime => _anime;
  String get characterQuery => _characterQuery;
  String get animeQuery => _animeQuery;
  bool get searching => _searching;
  Failure? get failure => _failure;

  static String _charactersKey(String query, String? animeId) =>
      '${animeId ?? ''}::$query';

  /// Debounced so typing does not fan out into one provider call per keystroke.
  void queryCharacters(String query, {String? animeId}) {
    if (_characterQuery == query) return;
    _characterQuery = query;
    final key = _charactersKey(query, animeId);
    final cached = _characterCache[key];
    if (cached != null) {
      _characters = cached;
      _searching = false;
      _failure = null;
      _safeNotify();
      return;
    }
    _searching = true;
    _safeNotify();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadCharacters(query, animeId, key));
    });
  }

  Future<void> _loadCharacters(
    String query,
    String? animeId,
    String key,
  ) async {
    final request = ++_request;
    final result = await _repository.searchCharacters(query, animeId: animeId);
    if (_disposed || request != _request) return;
    result.fold(
      onSuccess: (items) {
        _characterCache[key] = items;
        _characters = items;
        _failure = null;
      },
      onFailure: (failure) => _failure = failure,
    );
    _searching = false;
    _safeNotify();
  }

  void queryAnime(String query) {
    if (_animeQuery == query) return;
    _animeQuery = query;
    final cached = _animeCache[query];
    if (cached != null) {
      _anime = cached;
      _searching = false;
      _failure = null;
      _safeNotify();
      return;
    }
    _searching = true;
    _safeNotify();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadAnime(query));
    });
  }

  Future<void> _loadAnime(String query) async {
    final request = ++_request;
    final result = await _repository.searchAnime(query);
    if (_disposed || request != _request) return;
    result.fold(
      onSuccess: (items) {
        _animeCache[query] = items;
        _anime = items;
        _failure = null;
      },
      onFailure: (failure) => _failure = failure,
    );
    _searching = false;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
