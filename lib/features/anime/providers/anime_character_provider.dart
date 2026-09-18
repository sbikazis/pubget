import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import '../repositories/anime_hub_social_repository.dart';
import '../repositories/anime_repository.dart';
import 'anime_providers.dart';

final class AnimeCharacterProvider extends ChangeNotifier {
  AnimeCharacterProvider({
    required AnimeRepository repository,
    AnimeHubSocialRepository? social,
  }) : _repository = repository,
       _social = social;

  final AnimeRepository _repository;
  final AnimeHubSocialRepository? _social;

  AnimeCharacter? _character;
  CharacterCommunityStats? _stats;
  int? _rank;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _disposed = false;
  String? _loadedId;

  AnimeCharacter? get character => _character;
  CharacterCommunityStats? get stats => _stats;
  int? get rank => _rank;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> load(String characterId, {bool refresh = false}) async {
    final id = characterId.trim();
    if (id.isEmpty) {
      _state = LoadingState.empty;
      _failure = const NotFoundError(AnimeStrings.detailsMissing);
      _safeNotify();
      return;
    }
    if (!refresh && _loadedId == id && _character != null) return;
    _loadedId = id;
    _state = LoadingState.loading;
    _failure = null;
    if (!refresh) {
      _character = null;
      _stats = null;
      _rank = null;
    }
    _safeNotify();
    unawaited(_loadAggregates(id));
    final profile = await _repository.getCharacterDetails(id);
    if (_disposed || _loadedId != id) return;
    profile.fold(
      onSuccess: (character) {
        _character = character;
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = failure is NotFoundError
            ? LoadingState.empty
            : animeFailureState(failure, hasContent: _character != null);
      },
    );
    _safeNotify();
  }

  Future<void> retry() {
    final id = _loadedId;
    if (id == null) return Future<void>.value();
    return load(id, refresh: true);
  }

  Future<void> _loadAggregates(String characterId) async {
    final social = _social;
    if (social == null) return;
    final stats = await social.getCharacterStats(characterId);
    final ranking = await social.listPopularCharacters(limit: 100);
    if (_disposed || _loadedId != characterId) return;
    _stats = stats.valueOrNull ?? _stats;
    final items = ranking.valueOrNull;
    if (items != null) {
      final index = items.indexWhere((item) => item.characterId == characterId);
      _rank = index < 0 ? null : index + 1;
    }
    _safeNotify();
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

AnimeCharacterProvider? maybeAnimeCharacter(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<AnimeCharacterProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
