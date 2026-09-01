import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/group_models.dart';
import '../repositories/roleplay_repository.dart';

final class RoleplayProvider extends ChangeNotifier {
  RoleplayProvider({required RoleplayRepository repository})
    : _repository = repository;

  final RoleplayRepository _repository;
  List<RoleplayCharacter> _characters = const <RoleplayCharacter>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;

  List<RoleplayCharacter> get characters => _characters;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> load(String groupId) async {
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getAvailableCharacters(groupId);
    result.fold(
      onSuccess: (characters) {
        _characters = characters;
        _state = characters.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

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
