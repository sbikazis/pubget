import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/game_models.dart';
import 'game_repository.dart';

final class UnavailableGameRepository implements GameRepository {
  UnavailableGameRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(UnknownError(message));

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) async => _fail();

  @override
  Future<Result<void>> initialize(String gameId) async => _fail();

  @override
  Future<Result<void>> join(String gameId) async => _fail();

  @override
  Future<Result<void>> leave(String gameId) async => _fail();

  @override
  Future<Result<void>> start(String gameId) async => _fail();

  @override
  Future<Result<void>> pause(String gameId) async => _fail();

  @override
  Future<Result<void>> resume(String gameId) async => _fail();

  @override
  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? clientActionId,
  }) async => _fail();

  @override
  Future<Result<void>> end(String gameId) async => _fail();

  @override
  Future<Result<void>> cancel(String gameId) async => _fail();

  @override
  Stream<Result<PubgetGame>> watchGame(String gameId) =>
      Stream<Result<PubgetGame>>.value(_fail());

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) =>
      Stream<Result<List<GameParticipant>>>.value(_fail());

  @override
  Stream<Result<Map<String, dynamic>>> watchPrivate({
    required String gameId,
    required String userId,
  }) => Stream<Result<Map<String, dynamic>>>.value(_fail());

  @override
  Future<Result<List<PubgetGame>>> getActiveGames({int limit = 20}) async =>
      _fail();

  @override
  Future<Result<List<PubgetGame>>> getWaitingGames({int limit = 20}) async =>
      _fail();

  @override
  Future<Result<List<PubgetGame>>> getGroupGames({
    required String groupId,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<List<PubgetGame>>> getMyGames({
    required String userId,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<List<GameParticipant>>> getParticipants(String gameId) async =>
      _fail();
}
