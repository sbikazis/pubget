import '../constants/mafia_constants.dart';
import '../../models/mafia/mafia_game_model.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../services/mafia/mafia_game_repository.dart';

class MafiaGameEngine {
  final MafiaGameRepository _repository;

  MafiaGameEngine({MafiaGameRepository? repository})
      : _repository = repository ?? MafiaGameRepository();

  Future<void> startGame(MafiaGameModel game) async {
    if (game.playersCount < game.minPlayers) {
      throw Exception('لا يمكن بدء اللعبة قبل اكتمال العدد.');
    }

    await _repository.updateGame(game.id, {
      'status': MafiaGameStatus.starting.name,
      'currentPhase': MafiaGameStatus.starting.name,
      'startedAt': DateTime.now(),
      'phaseEndsAt': DateTime.now().add(const Duration(seconds: 60)),
      'countdownEndsAt': DateTime.now().add(const Duration(seconds: 60)),
      'isLocked': true,
    });
  }

  Future<void> transitionToPhase(
    String gameId,
    MafiaGameStatus nextPhase,
  ) async {
    final updateData = {
      'status': nextPhase.name,
      'currentPhase': nextPhase.name,
      'phaseEndsAt': DateTime.now().add(const Duration(seconds: 90)),
    };
    await _repository.updateGame(gameId, updateData);
  }

  Future<void> finishGame(
    String gameId,
    String winner,
  ) async {
    await _repository.updateGame(gameId, {
      'status': MafiaGameStatus.finished.name,
      'currentPhase': MafiaGameStatus.finished.name,
      'winner': winner,
      'endedAt': DateTime.now(),
    });
  }
}
