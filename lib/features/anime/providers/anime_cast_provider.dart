import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_models.dart';
import '../repositories/anime_repository.dart';
import 'anime_providers.dart';

/// Loads and filters every character of one anime for the full-page cast
/// browser. Filtering is client-side: Jikan returns the complete cast in a
/// single response and AniList caps at 40, so there is nothing to paginate.
final class AnimeCastProvider extends ChangeNotifier {
  AnimeCastProvider({required AnimeRepository repository})
    : _repository = repository;

  final AnimeRepository _repository;

  List<AnimeCharacter> _characters = const <AnimeCharacter>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String _query = '';
  int _loads = 0;
  bool _disposed = false;
  String? _loadedId;

  List<AnimeCharacter> get characters => _characters;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  String get query => _query;
  int get loads => _loads;

  /// The characters matching the active query; empty query shows the full cast.
  List<AnimeCharacter> get visible {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _characters;
    return _characters
        .where(
          (item) =>
              item.name.toLowerCase().contains(needle) ||
              (item.role ?? '').toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  void search(String query) {
    if (_query == query) return;
    _query = query;
    _safeNotify();
  }

  Future<void> load(String animeId, {bool refresh = false}) async {
    final id = animeId.trim();
    if (id.isEmpty) {
      _state = LoadingState.empty;
      _failure = const NotFoundError('Anime is required.');
      _safeNotify();
      return;
    }
    _loadedId = id;
    _state = LoadingState.loading;
    _failure = null;
    _safeNotify();
    final result = await _repository.getCharacters(id);
    if (_disposed || _loadedId != id) return;
    result.fold(
      onSuccess: (characters) {
        _characters = characters;
        _state = characters.isEmpty
            ? LoadingState.empty
            : LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = animeFailureState(
          failure,
          hasContent: _characters.isNotEmpty,
        );
      },
    );
    _loads++;
    _safeNotify();
  }

  void retry() {
    final id = _loadedId;
    if (id == null) return;
    load(id, refresh: true);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}