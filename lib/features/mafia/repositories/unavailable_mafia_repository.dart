import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/mafia_models.dart';
import 'mafia_repository.dart';

final class UnavailableMafiaRepository implements MafiaRepository {
  UnavailableMafiaRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(UnknownError(message));

  @override
  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 4,
    int maxPlayers = 8,
  }) async => _fail();

  @override
  Future<Result<void>> join(String gameId) async => _fail();

  @override
  Future<Result<void>> start(String gameId) async => _fail();

  @override
  Future<Result<void>> leave(String gameId) async => _fail();

  @override
  Future<Result<void>> submitNightAction({
    required String gameId,
    required String targetId,
    required int nightNumber,
  }) async => _fail();

  @override
  Future<Result<void>> submitVote({
    required String gameId,
    required String targetId,
    required int dayNumber,
  }) async => _fail();

  @override
  Future<Result<void>> sendChat({
    required String gameId,
    required String text,
    required MafiaPlayer self,
  }) async => _fail();

  @override
  Future<Result<void>> heartbeat(String gameId) async => _fail();

  @override
  Stream<Result<MafiaGame>> watchGame(String gameId) =>
      Stream<Result<MafiaGame>>.value(_fail());

  @override
  Stream<Result<List<MafiaPlayer>>> watchPlayers(String gameId) =>
      Stream<Result<List<MafiaPlayer>>>.value(_fail());

  @override
  Stream<Result<MafiaPrivateState>> watchPrivate({
    required String gameId,
    required String userId,
  }) => Stream<Result<MafiaPrivateState>>.value(_fail());

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchEvents(String gameId) =>
      Stream<Result<List<Map<String, dynamic>>>>.value(_fail());

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchChat(String gameId) =>
      Stream<Result<List<Map<String, dynamic>>>>.value(_fail());
}
