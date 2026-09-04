import '../../../core/errors/result.dart';
import '../models/game_models.dart';

abstract interface class GameRepository {
  Future<Result<PubgetGame>> create(GameDraft draft);

  Future<Result<void>> initialize(String gameId);

  Future<Result<void>> join(String gameId);

  Future<Result<void>> leave(String gameId);

  Future<Result<void>> start(String gameId);

  Future<Result<void>> pause(String gameId);

  Future<Result<void>> resume(String gameId);

  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload,
    String? clientActionId,
  });

  Future<Result<void>> end(String gameId);

  Future<Result<void>> cancel(String gameId);

  Stream<Result<PubgetGame>> watchGame(String gameId);

  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId);

  Stream<Result<Map<String, dynamic>>> watchPrivate({
    required String gameId,
    required String userId,
  });

  Future<Result<List<PubgetGame>>> getActiveGames({int limit = 20});

  Future<Result<List<PubgetGame>>> getWaitingGames({int limit = 20});

  Future<Result<List<PubgetGame>>> getGroupGames({
    required String groupId,
    int limit = 20,
  });

  Future<Result<List<PubgetGame>>> getMyGames({
    required String userId,
    int limit = 20,
  });

  Future<Result<List<GameParticipant>>> getParticipants(String gameId);
}
