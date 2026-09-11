import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/games_schema_v2.dart';
import 'games_repository_v2.dart';

final class UnavailableGamesRepositoryV2 implements GamesRepositoryV2 {
  UnavailableGamesRepositoryV2(this.message);
  final String message;
  FailureResult<T> _fail<T>() => FailureResult(UnknownError(message));

  @override
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  }) async => _fail();
  @override
  Future<Result<void>> command(GameCommandRequest request) async => _fail();
  @override
  Stream<Result<GameSessionV2>> watchSession(String gameId) =>
      Stream.value(_fail());
  @override
  Stream<Result<Map<String, dynamic>>> watchPrivateState({
    required String gameId,
    required String userId,
  }) => Stream.value(_fail());
  @override
  Future<Result<GameHistoryPage>> groupHistory({
    required String groupId,
    String? cursor,
    int limit = 20,
  }) async => _fail();
}
