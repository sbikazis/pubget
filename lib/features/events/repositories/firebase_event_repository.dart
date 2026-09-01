import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/event_models.dart';
import 'event_repository.dart';

final class FirebaseEventRepository implements EventRepository {
  FirebaseEventRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  @override
  Future<Result<String>> saveDraft(EventDraft draft) => _guard(() async {
    final result = await _functions
        .httpsCallable('saveEventDraft')
        .call(draft.toCallableMap());
    return result.data['eventId'] as String;
  });

  @override
  Future<Result<void>> deleteDraft(String eventId) =>
      _call('deleteEventDraft', {'eventId': eventId});

  @override
  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  }) => _guard(() async {
    await _functions.httpsCallable('publishEvent').call(<String, dynamic>{
      'eventId': eventId,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
    });
    final snapshot = await _events.doc(eventId).get();
    return PubgetEvent.fromMap(snapshot.data() ?? const {}, id: eventId);
  });

  @override
  Future<Result<void>> cancel(String eventId) =>
      _call('cancelEvent', {'eventId': eventId});

  @override
  Future<Result<void>> end(String eventId) =>
      _call('endEvent', {'eventId': eventId});

  @override
  Future<Result<void>> archive(String eventId) =>
      _call('archiveEvent', {'eventId': eventId});

  @override
  Future<Result<void>> join(String eventId) =>
      _call('joinEvent', {'eventId': eventId});

  @override
  Future<Result<void>> leave(String eventId) =>
      _call('leaveEvent', {'eventId': eventId});

  @override
  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  }) => _call('submitEventResponse', {
    'eventId': eventId,
    'responseData': responseData,
  });

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) {
    return _events
        .doc(eventId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const FailureResult<PubgetEvent>(
              NotFoundError('This event no longer exists.'),
            );
          }
          return Success(
            PubgetEvent.fromMap(snapshot.data()!, id: snapshot.id),
          );
        })
        .handleError(
          (Object error) => FailureResult<PubgetEvent>(_eventFailure(error)),
        );
  }

  @override
  Future<Result<List<PubgetEvent>>> getActiveEvents({int limit = 20}) => _query(
    _events
        .where('status', isEqualTo: 'active')
        .orderBy('participantsCount', descending: true)
        .orderBy('endAt')
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20}) =>
      _query(
        _events
            .where('status', isEqualTo: 'scheduled')
            .orderBy('startAt')
            .limit(limit),
      );

  @override
  Future<Result<List<PubgetEvent>>> getRecentEvents({int limit = 20}) => _query(
    _events
        .where('status', whereIn: <String>['ended', 'archived'])
        .orderBy('endAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetEvent>>> getGroupEvents({
    required String groupId,
    int limit = 20,
  }) => _query(
    _events
        .where('groupId', isEqualTo: groupId)
        .where('status', whereIn: <String>['active', 'scheduled', 'ended'])
        .orderBy('startAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetEvent>>> getMyEvents({
    required String userId,
    int limit = 20,
  }) => _query(
    _events
        .where('creatorId', isEqualTo: userId)
        .where('status', isNotEqualTo: 'draft')
        .orderBy('status')
        .orderBy('updatedAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetEvent>>> getMyDrafts({required String userId}) =>
      _query(
        _events
            .where('creatorId', isEqualTo: userId)
            .where('status', isEqualTo: 'draft')
            .orderBy('updatedAt', descending: true)
            .limit(20),
      );

  @override
  Future<Result<List<PubgetEvent>>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const Success(<PubgetEvent>[]);
    return _query(
      _events
          .where('status', whereIn: <String>['active', 'scheduled', 'ended'])
          .where('searchName', isGreaterThanOrEqualTo: normalized)
          .where('searchName', isLessThanOrEqualTo: '$normalized\uf8ff')
          .limit(20),
    );
  }

  @override
  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _events
        .doc(eventId)
        .collection('responses')
        .doc(userId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return EventResponse.fromMap(snapshot.data()!, userId: userId);
  });

  Future<Result<List<PubgetEvent>>> _query(Query<Map<String, dynamic>> query) =>
      _guard(() async {
        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => PubgetEvent.fromMap(doc.data(), id: doc.id))
            .toList(growable: false);
      });

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_eventFailure(error));
    }
  }
}

Failure _eventFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? "You don't have permission.",
      ),
      'not-found' => NotFoundError(error.message ?? 'Event not found.'),
      'unavailable' || 'resource-exhausted' => NetworkError(
        error.message ?? 'Check your connection and try again.',
      ),
      'already-exists' => ValidationError(
        error.message ?? 'You already submitted a response.',
      ),
      _ => ValidationError(error.message ?? 'This event action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  return UnknownError(error.toString());
}
