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

  Future<Result<List<PubgetEvent>>> getEventsByAnime({
    required String animeId,
    int limit = 20,
  });

  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  });

  /// The current user's own reaction doc: returns 'like', 'dislike', or null.
  Future<Result<String?>> getMyReaction({
    required String eventId,
    required String userId,
  });

  Future<Result<EventCreationQuota>> getCreationQuota();

  /// Extends a live event to additional groups (or global) without copying it.
  Future<Result<void>> crosspost({
    required String eventId,
    List<String> groupIds = const <String>[],
    bool toGlobal = false,
  });

  Future<Result<EventPreview>> preview({required String eventId});

  /// §14.6 — files an abuse report against an Event for moderation triage.
  Future<Result<void>> reportEvent({
    required String eventId,
    required String category,
    String detail = '',
  });

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
