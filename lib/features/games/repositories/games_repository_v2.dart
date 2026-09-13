import '../../../core/errors/result.dart';
import '../models/games_schema_v2.dart';

final class GameHistoryPage {
  const GameHistoryPage({required this.games, this.nextCursor});
  final List<GameSessionV2> games;
  final String? nextCursor;
  bool get hasMore => nextCursor != null;
}

/// Prompt 1 repository contract. All mutating operations are callable
/// commands carrying requestId and expectedVersion.
abstract interface class GamesRepositoryV2 {
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  });
  Future<Result<void>> command(GameCommandRequest request);
  Stream<Result<GameSessionV2>> watchSession(String gameId);
  Stream<Result<Map<String, dynamic>>> watchPrivateState({
    required String gameId,
    required String userId,
  });
  Future<Result<GameHistoryPage>> groupHistory({
    required String groupId,
    String? cursor,
    int limit = 20,
  });
}
