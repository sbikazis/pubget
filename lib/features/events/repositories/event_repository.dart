import '../../../core/errors/result.dart';
import '../models/event_models.dart';

abstract interface class EventRepository {
  Future<Result<String>> saveDraft(EventDraft draft);

  Future<Result<void>> deleteDraft(String eventId);

  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  });

  Future<Result<void>> cancel(String eventId);

  Future<Result<void>> end(String eventId);

  Future<Result<void>> archive(String eventId);

  Future<Result<void>> join(String eventId);

  Future<Result<void>> leave(String eventId);

  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  });

  Stream<Result<PubgetEvent>> watchEvent(String eventId);

  Future<Result<List<PubgetEvent>>> getActiveEvents({
    int limit = 20,
    PubgetEvent? after,
  });

  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20});

  Future<Result<List<PubgetEvent>>> getRecentEvents({
    int limit = 20,
    PubgetEvent? after,
  });

  Future<Result<List<PubgetEvent>>> getGroupEvents({
    required String groupId,
    int limit = 20,
  });

  Future<Result<List<PubgetEvent>>> getMyEvents({
    required String userId,
    int limit = 20,
  });

  Future<Result<List<PubgetEvent>>> getMyDrafts({required String userId});

  Future<Result<List<PubgetEvent>>> search(String query);

  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  });

  Future<Result<EventPreview>> preview({required String eventId});

  Future<Result<EventResult>> resolve({
    required String eventId,
    String? winnerOptionId,
    List<String>? winnerIds,
  });

  Future<Result<EventAnalytics>> getAnalytics(String eventId);

  Future<Result<String>> addComment({
    required String eventId,
    required String text,
  });

  Future<Result<void>> react({
    required String eventId,
    required String reaction,
  });

  Stream<Result<List<EventComment>>> watchComments(String eventId);
}
