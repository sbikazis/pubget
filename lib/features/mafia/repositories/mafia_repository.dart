import '../../../core/errors/result.dart';
import '../models/mafia_models.dart';

abstract interface class MafiaRepository {
  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 4,
    int maxPlayers = 8,
  });

  Future<Result<void>> join(String gameId);

  Future<Result<void>> start(String gameId);

  Future<Result<void>> leave(String gameId);

  Future<Result<void>> submitNightAction({
    required String gameId,
    required String targetId,
    required int nightNumber,
  });

  Future<Result<void>> submitVote({
    required String gameId,
    required String targetId,
    required int dayNumber,
  });

  Future<Result<void>> sendChat({
    required String gameId,
    required String text,
    required MafiaPlayer self,
  });

  Future<Result<void>> heartbeat(String gameId);

  Stream<Result<MafiaGame>> watchGame(String gameId);

  Stream<Result<List<MafiaPlayer>>> watchPlayers(String gameId);

  Stream<Result<MafiaPrivateState>> watchPrivate({
    required String gameId,
    required String userId,
  });

  Stream<Result<List<Map<String, dynamic>>>> watchEvents(String gameId);

  Stream<Result<List<Map<String, dynamic>>>> watchChat(String gameId);
}
