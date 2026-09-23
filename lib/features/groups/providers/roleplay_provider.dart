import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../anime/models/anime_models.dart';
import '../../anime/models/anime_rating_models.dart';
import '../../anime/repositories/anime_hub_social_repository.dart';
import '../../anime/repositories/anime_repository.dart';
import '../models/group_models.dart';
import '../repositories/roleplay_repository.dart';

final class RoleplayProvider extends ChangeNotifier {
  RoleplayProvider({
    required RoleplayRepository repository,
    AnimeRepository? animeRepository,
    AnimeHubSocialRepository? socialRepository,
  }) : _repository = repository,
       _animeRepository = animeRepository,
       _socialRepository = socialRepository;

  final RoleplayRepository _repository;
  final AnimeRepository? _animeRepository;
  final AnimeHubSocialRepository? _socialRepository;
  List<RoleplayCharacter> _characters = const <RoleplayCharacter>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;

  List<RoleplayCharacter> get characters => _characters;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> load(String groupId) async {
    _state = LoadingState.loading;
    notifyListeners();
    final context = await _repository.roleplayContext(groupId);
    if (context.isSuccess) {
      await _loadCatalog(context.valueOrNull!);
    } else {
      _setFailure(context.failureOrNull!);
    }
  }

  Future<void> _loadCatalog(RoleplayGroupContext context) async {
    final reserved = context.reservedKeys;
    final catalog = await _realCatalog(context);
    catalog.fold(
      onSuccess: (characters) {
        final filtered = characters
            .where((item) => !reserved.contains(item.key))
            .toList(growable: false);
        _characters = filtered;
        _state = filtered.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
      },
      onFailure: _setFailure,
    );
    notifyListeners();
  }

  Future<Result<List<RoleplayCharacter>>> _realCatalog(
    RoleplayGroupContext context,
  ) async {
    switch (context.type) {
      case GroupType.public:
      case null:
        return const Success(<RoleplayCharacter>[]);
      case GroupType.animeRoleplay:
        final animeId = context.animeId?.trim();
        if (animeId == null || animeId.isEmpty) {
          return const Success(<RoleplayCharacter>[]);
        }
        final anime = _animeRepository;
        if (anime == null) return const Success(<RoleplayCharacter>[]);
        return anime.getCharacters(animeId).then(
          (result) => result.fold(
            onSuccess: (items) =>
                Success(items.map(_fromAnimeCharacter).toList()),
            onFailure: FailureResult<List<RoleplayCharacter>>.new,
          ),
        );
      case GroupType.openRoleplay:
        final social = _socialRepository;
        if (social == null) return const Success(<RoleplayCharacter>[]);
        return social.listPopularCharacters().then(
          (result) => result.fold(
            onSuccess: (items) =>
                Success(items.map(_fromCharacterStats).toList()),
            onFailure: FailureResult<List<RoleplayCharacter>>.new,
          ),
        );
    }
  }

  RoleplayCharacter _fromAnimeCharacter(AnimeCharacter item) =>
      RoleplayCharacter(
        key: item.id,
        name: item.name,
        avatarUrl: item.imageUrl ?? '',
      );

  RoleplayCharacter _fromCharacterStats(CharacterCommunityStats item) =>
      RoleplayCharacter(
        key: item.characterId,
        name: item.name,
        avatarUrl: item.imageUrl ?? '',
      );

  Future<Result<void>> reserve(
    String groupId,
    RoleplayCharacter character,
  ) async {
    _state = LoadingState.refreshing;
    notifyListeners();
    final result = await _repository.reserveCharacter(
      groupId: groupId,
      characterKey: character.key,
      character: character,
    );
    result.fold(
      onSuccess: (_) {
        _characters = _characters
            .where((item) => item.key != character.key)
            .toList(growable: false);
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
    return result;
  }

  void _setFailure(Failure failure) {
    _failure = failure;
    _state = failure is NetworkError
        ? LoadingState.offline
        : LoadingState.error;
    notifyListeners();
  }
}