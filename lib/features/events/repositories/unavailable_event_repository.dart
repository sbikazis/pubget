import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/event_models.dart';
import 'event_repository.dart';

final class UnavailableEventRepository implements EventRepository {
  UnavailableEventRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(UnknownError(message));

  @override
  Future<Result<String>> saveDraft(EventDraft draft) async => _fail();

  @override
  Future<Result<void>> deleteDraft(String eventId) async => _fail();

  @override
  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  }) async => _fail();

  @override
  Future<Result<void>> cancel(String eventId) async => _fail();

  @override
  Future<Result<void>> end(String eventId) async => _fail();

  @override
  Future<Result<void>> archive(String eventId) async => _fail();

  @override
  Future<Result<void>> join(String eventId) async => _fail();

  @override
  Future<Result<void>> leave(String eventId) async => _fail();

  @override
  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  }) async => _fail();

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) =>
      Stream<Result<PubgetEvent>>.value(_fail());

  @override
  Future<Result<List<PubgetEvent>>> getActiveEvents({int limit = 20}) async =>
      _fail();

  @override
  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20}) async =>
      _fail();

  @override
  Future<Result<List<PubgetEvent>>> getRecentEvents({int limit = 20}) async =>
      _fail();

  @override
  Future<Result<List<PubgetEvent>>> getGroupEvents({
    required String groupId,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<List<PubgetEvent>>> getMyEvents({
    required String userId,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<List<PubgetEvent>>> getMyDrafts({
    required String userId,
  }) async => _fail();

  @override
  Future<Result<List<PubgetEvent>>> search(String query) async => _fail();

  @override
  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  }) async => _fail();
}
