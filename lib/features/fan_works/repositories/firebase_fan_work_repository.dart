import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../services/fan_work_upload_client.dart';
import 'fan_work_repository.dart';

final class FirebaseFanWorkRepository
    implements FanWorkRepository, CharacterFanWorkRepository {
  // No storage SDK dependency on purpose: every byte in and out of a Fan Work
  // goes through a signed upload session or a short-lived read grant, so there
  // is no client-side path that could mint a permanent `downloadToken`.
  FirebaseFanWorkRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  FanWorkUploadClient? _activeUploadClient;

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
    required FanWorkMediaRole role,
    required String contentType,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('startFanWorkMediaUpload')
        .call(<String, dynamic>{
          'workId': workId,
          'role': role.name,
          'contentType': contentType,
        });
    final data = result.data;
    return FanWorkUploadTicket(
      workId: data['workId'] as String,
      mediaId: data['mediaId'] as String,
      path: data['path'] as String,
      contentType: data['contentType'] as String? ?? contentType,
      role: FanWorkMediaRole.values.firstWhere(
        (value) => value.name == data['role'],
        orElse: () => role,
      ),
      uploadUrl: data['uploadUrl'] as String? ?? '',
      maxBytes: (data['maxBytes'] as num?)?.toInt() ?? 0,
      expiresAt:
          _millis(data['expiresAt']) ??
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );
  });

  @override
  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
    FanWorkUploadProgress? onProgress,
  }) => _guard(() async {
    // The server already refused an oversized or wrong-role payload when it
    // minted the ticket; re-checking here keeps a stale ticket from silently
    // uploading more than the rules would allow.
    final limit = ticket.maxBytes > 0
        ? ticket.maxBytes
        : FanWorkLifecycle.maxImageBytes;
    if (bytes.length > limit) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: ticket.role == FanWorkMediaRole.document
            ? 'PDF files must be 50 MB or smaller.'
            : 'Images must be 12 MB or smaller.',
      );
    }
    // The bytes go through the signed resumable session the server opened, not
    // through the storage SDK. That is the point of the session: it cannot mint
    // a permanent `downloadToken`, so the object stays private and readable
    // only via a short-lived signed grant. A `putData` call would write the
    // object without ever using the ticket the server validated.
    _activeUploadClient?.cancel();
    final client = FanWorkUploadClient();
    _activeUploadClient = client;
    try {
      final result = await client.upload(
        sessionUrl: ticket.uploadUrl,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
      final failure = result.failureOrNull;
      if (failure != null) throw failure;
      return;
    } finally {
      client.close();
      if (identical(_activeUploadClient, client)) {
        _activeUploadClient = null;
      }
    }
  });

  @override
  Future<Result<void>> cancelMediaUpload() => _guard(() async {
    // Cancelling stops the chunk loop from starting another request. The
    // session stays resumable, so the editor can retry the same ticket.
    _activeUploadClient?.cancel();
  });

  @override
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
    String characterId = '',
    int? pageCount,
  }) => _call('confirmFanWorkMedia', {
    'workId': workId,
    'mediaId': mediaId,
    'path': path,
    'role': role.name,
    'caption': caption,
    if (characterId.isNotEmpty) 'characterId': characterId,
    if (pageCount != null && pageCount > 0) 'pageCount': pageCount,
  });

  @override
  Future<Result<FanWorkDocumentAccess>> getDocumentAccess({
    required String workId,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('getFanWorkDocumentAccess')
        .call(<String, dynamic>{'workId': workId});
    final data = result.data;
    final expiresAt =
        _millis(data['expiresAt']) ??
        DateTime.now().toUtc().add(const Duration(minutes: 3));
    final pageCount = (data['pageCount'] as num?)?.toInt();
    return FanWorkDocumentAccess(
      url: data['url'] as String,
      expiresAt: expiresAt,
      pageCount: pageCount != null && pageCount > 0 ? pageCount : null,
    );
  });

  @override
  Future<Result<FanWorkReadingProgress>> getReadingProgress({
    required String workId,
    required String userId,
  }) => _guard(() async {
    final snapshot = await _works
        .doc(workId)
        .collection('readingProgress')
        .doc(userId)
        .get();
    return FanWorkReadingProgress.fromMap(snapshot.data());
  });

  @override
  Future<Result<void>> saveReadingProgress({
    required String workId,
    required FanWorkReadingProgress progress,
  }) => _call('saveFanWorkReadingProgress', {
    'workId': workId,
    'page': progress.page,
    'pageCount': progress.pageCount,
    'progress': progress.progress,
  });

  @override
  Future<Result<void>> markAsRead({required String workId}) =>
      _call('markFanWorkAsRead', {'workId': workId});

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
  }) => _call('requestFanWorkRemoval', {'workId': workId, 'details': details});

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
    query = query
        .orderBy('publishedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after?.publishedAt != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(after!.publishedAt!.toUtc()),
        after.id,
      ]);
    }
    return _page(query.limit(limit + 1), limit);
  }

  @override
  Future<Result<FanWorkListPage>> getCharacterFeed(
    String characterId, {
    FanWork? after,
    int limit = 20,
  }) {
    final id = characterId.trim();
    if (id.isEmpty) {
      return Future<Result<FanWorkListPage>>.value(
        const Success<FanWorkListPage>(
          FanWorkListPage(items: <FanWork>[], hasMore: false),
        ),
      );
    }
    var query = _public
        .where('characterIds', arrayContains: id)
        .orderBy('publishedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after?.publishedAt != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(after!.publishedAt!.toUtc()),
        after.id,
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
        .orderBy('publishedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after?.publishedAt != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(after!.publishedAt!.toUtc()),
        after.id,
      ]);
    }
    return _page(query.limit(limit + 1), limit);
  }

  @override
  Future<Result<List<FanWork>>> getMyDrafts({required String userId}) => _list(
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

  @override
  Future<Result<List<FanWorkRevision>>> getRevisions(String workId) =>
      _guard(() async {
        final snapshot = await _works
            .doc(workId)
            .collection('revisions')
            .orderBy('version', descending: true)
            .get();
        return snapshot.docs
            .map((doc) {
              final version = (doc.data()['version'] as num?)?.toInt() ?? 0;
              return FanWorkRevision.fromMap(doc.data(), version: version);
            })
            .toList(growable: false);
      });

  @override
  Future<Result<FanWorkAnalytics>> getAnalytics(String creatorId) => _guard(
    () async {
      final worksSnapshot = await _works
          .where('creatorId', isEqualTo: creatorId)
          .get();
      final works = worksSnapshot.docs
          .map((doc) => FanWork.fromMap(doc.data(), id: doc.id))
          .toList();

      final totalWorks = works.length;
      final publishedWorks = works.where((w) => w.isPublished).length;
      final draftWorks = works.where((w) => w.isDraft).length;
      final totalLikes = works.fold<int>(0, (total, w) => total + w.likesCount);
      final totalBookmarks = works.fold<int>(
        0,
        (total, w) => total + w.bookmarksCount,
      );
      final totalComments = works.fold<int>(
        0,
        (total, w) => total + w.commentsCount,
      );
      final ratingsSum = works.fold<double>(
        0.0,
        (total, w) => total + w.ratingsAverage * w.ratingsCount,
      );
      final totalRatings = works.fold<int>(
        0,
        (total, w) => total + w.ratingsCount,
      );
      final averageRating = totalRatings > 0 ? ratingsSum / totalRatings : 0.0;

      final worksByType = <String, int>{};
      for (final w in works) {
        worksByType[w.type.name] = (worksByType[w.type.name] ?? 0) + 1;
      }

      final sortedWorks = [...works]
        ..sort((a, b) => b.likesCount.compareTo(a.likesCount));
      final topWorks = sortedWorks.take(5).map((w) => w.preview).toList();

      return FanWorkAnalytics(
        totalWorks: totalWorks,
        publishedWorks: publishedWorks,
        draftWorks: draftWorks,
        totalLikes: totalLikes,
        totalBookmarks: totalBookmarks,
        totalComments: totalComments,
        totalRatings: totalRatings,
        averageRating: averageRating,
        worksByType: worksByType,
        topWorks: topWorks,
      );
    },
  );

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

/// Callable timestamps travel as epoch milliseconds; older documents and local
/// drafts may use a string, so both are accepted here.
DateTime? _millis(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final asInt = int.tryParse(value);
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    return DateTime.tryParse(value);
  }
  return null;
}

Failure _fanWorkFailure(Object error) {
  // A `Failure` raised further down (for example by the resumable upload
  // client, which already classifies HTTP status codes) carries a better
  // message than anything reconstructed here, so it is passed through as-is.
  if (error is Failure) return error;
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'canceled' || 'cancelled' => const CancelledError('Upload canceled.'),
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
      (error.code == 'canceled' || error.code == 'cancelled')) {
    return const CancelledError('Upload canceled.');
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed')) {
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
