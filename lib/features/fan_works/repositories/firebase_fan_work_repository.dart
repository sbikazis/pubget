import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/fan_work_models.dart';
import 'fan_work_repository.dart';

final class FirebaseFanWorkRepository implements FanWorkRepository {
  FirebaseFanWorkRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _works =>
      _firestore.collection('fanWorks');

  Query<Map<String, dynamic>> get _public => _works
      .where('status', isEqualTo: 'published')
      .where('moderationStatus', isEqualTo: 'approved');

  @override
  Future<Result<String>> saveDraft(FanWorkDraft draft) => _guard(() async {
    final result = await _functions
        .httpsCallable('saveFanWorkDraft')
        .call(draft.toCallableMap());
    return result.data['workId'] as String;
  });

  @override
  Future<Result<void>> deleteDraft(String workId) =>
      _call('deleteFanWorkDraft', {'workId': workId});

  @override
  Future<Result<FanWork>> publish(String workId) => _guard(() async {
    await _functions.httpsCallable('publishFanWork').call(<String, dynamic>{
      'workId': workId,
    });
    final snapshot = await _works.doc(workId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: 'Fan Work not found.',
      );
    }
    return FanWork.fromMap(snapshot.data()!, id: workId);
  });

  @override
  Future<Result<void>> archive(String workId) =>
      _call('archiveFanWork', {'workId': workId});

  @override
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required String contentType,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('startFanWorkMediaUpload')
        .call(<String, dynamic>{'workId': workId, 'contentType': contentType});
    return FanWorkUploadTicket(
      workId: result.data['workId'] as String,
      mediaId: result.data['mediaId'] as String,
      path: result.data['path'] as String,
      contentType: result.data['contentType'] as String? ?? contentType,
    );
  });

  @override
  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  }) => _guard(() async {
    await _storage
        .ref(ticket.path)
        .putData(
          Uint8List.fromList(bytes),
          SettableMetadata(
            contentType: contentType,
            customMetadata: <String, String>{
              'uploadedBy': ticket.path.split('/')[1],
            },
          ),
        );
  });

  @override
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
  }) => _call('confirmFanWorkMedia', {
    'workId': workId,
    'mediaId': mediaId,
    'path': path,
    'role': role.name,
    'caption': caption,
  });

  @override
  Future<Result<void>> like({required String workId, required bool like}) =>
      _call('likeFanWork', {'workId': workId, 'like': like});

  @override
  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  }) => _call('bookmarkFanWork', {'workId': workId, 'bookmark': bookmark});

  @override
  Future<Result<void>> rate({required String workId, required int rating}) =>
      _call('rateFanWork', {'workId': workId, 'rating': rating});

  @override
  Future<Result<int?>> myRating({
    required String workId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _works
        .doc(workId)
        .collection('ratings')
        .doc(userId)
        .get();
    final value = snapshot.data()?['rating'];
    return value is num ? value.toInt() : null;
  });

  @override
  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details = '',
  }) => _call('reportFanWork', {
    'workId': workId,
    'reason': reason.name,
    'details': details,
  });

  @override
  Future<Result<void>> addComment({
    required String workId,
    required String text,
    String? replyToCommentId,
    String? eventId,
  }) => _call('addFanWorkComment', {
    'workId': workId,
    'text': text,
    if (replyToCommentId != null && replyToCommentId.isNotEmpty)
      'replyToCommentId': replyToCommentId,
    if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
  });

  @override
  Future<Result<List<FanWorkComment>>> getComments(
    String workId, {
    FanWorkComment? after,
    int limit = 30,
  }) => _guard(() async {
    Query<Map<String, dynamic>> query = _works
        .doc(workId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, 50));
    final cursor = after?.createdAt;
    if (cursor != null) {
      query = query.startAfter(<Object>[Timestamp.fromDate(cursor)]);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => FanWorkComment.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<void>> commentAction({
    required String workId,
    required String commentId,
    required String action,
  }) => _call('fanWorkCommentAction', {
    'workId': workId,
    'commentId': commentId,
    'action': action,
  });

  @override
  Future<Result<void>> revisePublished({
    required String workId,
    String? title,
    String? description,
    FanWorkCopyright? copyright,
    List<String>? tags,
  }) => _call('revisePublishedFanWork', {
    'workId': workId,
    'title': ?title,
    'description': ?description,
    'copyright': ?copyright?.toMap(),
    'tags': ?tags,
  });

  @override
  Future<Result<void>> requestRemoval({
    required String workId,
    String details = '',
  }) => _call('requestFanWorkRemoval', {
    'workId': workId,
    'details': details,
  });

  @override
  Stream<Result<FanWork>> watchWork(String workId) {
    return _works
        .doc(workId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const FailureResult<FanWork>(
              NotFoundError('This Fan Work is unavailable.'),
            );
          }
          return Success(FanWork.fromMap(snapshot.data()!, id: snapshot.id));
        })
        .handleError(
          (Object error) => FailureResult<FanWork>(_fanWorkFailure(error)),
        );
  }

  @override
  Future<Result<FanWork>> getWork(String workId) => _guard(() async {
    final snapshot = await _works.doc(workId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: 'Fan Work not found.',
      );
    }
    return FanWork.fromMap(snapshot.data()!, id: snapshot.id);
  });

  @override
  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _public;
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    if (animeId != null && animeId.isNotEmpty) {
      query = query.where('animeId', isEqualTo: animeId);
    }
    query = query.orderBy('publishedAt', descending: true);
    if (after?.publishedAt != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(after!.publishedAt!.toUtc()),
      ]);
    }
    return _page(query.limit(limit + 1), limit);
  }

  @override
  Future<Result<FanWorkListPage>> getCreatorWorks({
    required String creatorId,
    FanWork? after,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _public
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('publishedAt', descending: true);
    if (after?.publishedAt != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(after!.publishedAt!.toUtc()),
      ]);
    }
    return _page(query.limit(limit + 1), limit);
  }

  @override
  Future<Result<List<FanWork>>> getMyDrafts({required String userId}) =>
      _list(
        _works
            .where('creatorId', isEqualTo: userId)
            .where('status', isEqualTo: 'draft')
            .orderBy('updatedAt', descending: true)
            .limit(40),
      );

  @override
  Future<Result<List<FanWorkPreview>>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const Success(<FanWorkPreview>[]);
    return _guard(() async {
      final snapshot = await _public
          .where('searchTitle', isGreaterThanOrEqualTo: normalized)
          .where('searchTitle', isLessThanOrEqualTo: '$normalized\uf8ff')
          .limit(20)
          .get();
      return snapshot.docs
          .map((doc) => FanWorkPreview.fromMap(doc.data(), id: doc.id))
          .toList(growable: false);
    });
  }

  @override
  Future<Result<bool>> hasLiked({
    required String workId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _works
        .doc(workId)
        .collection('likes')
        .doc(userId)
        .get();
    return snapshot.exists;
  });

  @override
  Future<Result<bool>> hasBookmarked({
    required String workId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _works
        .doc(workId)
        .collection('bookmarks')
        .doc(userId)
        .get();
    return snapshot.exists;
  });

  Future<Result<FanWorkListPage>> _page(
    Query<Map<String, dynamic>> query,
    int limit,
  ) => _guard(() async {
    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => FanWork.fromMap(doc.data(), id: doc.id))
        .toList();
    final hasMore = items.length > limit;
    final page = hasMore ? items.sublist(0, limit) : items;
    return FanWorkListPage(
      items: page,
      hasMore: hasMore,
      cursor: page.isEmpty ? null : page.last,
    );
  });

  Future<Result<List<FanWork>>> _list(Query<Map<String, dynamic>> query) =>
      _guard(() async {
        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => FanWork.fromMap(doc.data(), id: doc.id))
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
      return FailureResult<T>(_fanWorkFailure(error));
    }
  }
}

Failure _fanWorkFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? "You don't have permission.",
      ),
      'not-found' => NotFoundError(error.message ?? 'Fan Work not found.'),
      'unavailable' || 'resource-exhausted' || 'deadline-exceeded' =>
        NetworkError(error.message ?? 'Check your connection and try again.'),
      'already-exists' => ValidationError(
        error.message ?? 'That action was already completed.',
      ),
      'failed-precondition' => ValidationError(
        error.message ?? 'This Fan Work cannot be published yet.',
      ),
      _ => ValidationError(error.message ?? 'This Fan Work action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return const PermissionError("You don't have permission.");
  }
  if (error is FirebaseException && error.code == 'not-found') {
    return const NotFoundError('Fan Work not found.');
  }
  return UnknownError('Something went wrong. Try again.');
}
