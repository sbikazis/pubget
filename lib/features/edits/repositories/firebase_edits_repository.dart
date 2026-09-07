import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/edit_storage_put.dart';
import '../models/edit_models.dart';
import 'edits_repository.dart';

final class FirebaseEditsRepository implements EditsRepository {
  FirebaseEditsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  UploadTask? _activeUpload;

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Failure catch (error) {
      return FailureResult(error);
    } on FirebaseException catch (error) {
      if (error.code == 'canceled') {
        return const FailureResult(ValidationError('Upload canceled.'));
      }
      return FailureResult(
        error.code == 'unavailable' || error.code == 'deadline-exceeded'
            ? const NetworkError('Check your connection and try again.')
            : UnknownError(error.message ?? error.toString()),
      );
    } on Object catch (error) {
      return FailureResult(UnknownError(error.toString()));
    }
  }

  @override
  Future<Result<Edit>> uploadEdit({
    required EditUploadSource source,
    required String contentType,
    required String caption,
    required String animeTag,
    String? fileName,
    int? sizeBytes,
    String? idempotencyKey,
    String? resumeEditId,
    String? resumeVideoPath,
    UploadStarted? onStarted,
    UploadProgress? onProgress,
  }) => _guard(() async {
    late final String path;
    late final String editId;
    final resumeId = resumeEditId?.trim();
    final resumePath = resumeVideoPath?.trim();
    if (resumeId != null &&
        resumeId.isNotEmpty &&
        resumePath != null &&
        resumePath.isNotEmpty) {
      editId = resumeId;
      path = resumePath;
    } else {
      final start = await _functions.httpsCallable('startEditUpload').call({
        'caption': caption,
        'animeTag': animeTag,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      });
      path = start.data['videoPath'] as String;
      editId = start.data['editId'] as String;
    }
    final task = putEditVideo(
      _storage.ref(path),
      source,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          if (fileName != null) 'fileName': fileName,
          if (sizeBytes != null) 'clientSize': '$sizeBytes',
        },
      ),
    );
    onStarted?.call(editId, path);
    _activeUpload = task;
    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    await task;
    _activeUpload = null;
    onProgress?.call(1);
    final snap = await _firestore.collection('edits').doc(editId).get();
    if (!snap.exists || snap.data() == null) {
      return Edit(
        id: editId,
        creatorId: '',
        videoUrl: '',
        thumbnailUrl: '',
        caption: caption,
        animeTag: animeTag,
        likesCount: 0,
        commentsCount: 0,
        viewsCount: 0,
        score: 0,
        createdAt: DateTime.now(),
        status: 'processing',
      );
    }
    return Edit.fromMap(snap.data()!, id: editId);
  });

  @override
  Future<Result<void>> cancelUpload() async {
    final task = _activeUpload;
    if (task == null) return const Success<void>(null);
    await task.cancel();
    _activeUpload = null;
    return const Success<void>(null);
  }

  @override
  Stream<Result<Edit>> watchEdit(String editId) {
    return _firestore.collection('edits').doc(editId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return const FailureResult<Edit>(NotFoundError('Edit not found.'));
      }
      return Success(Edit.fromMap(snap.data()!, id: snap.id));
    });
  }

  @override
  Future<Result<void>> retryProcessing(String editId) =>
      _call('retryEditProcessing', {'editId': editId});

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) =>
      _guard(() async {
        try {
          final result = await _functions.httpsCallable('getEditFeed').call({
            'limit': limit,
            if (after != null) 'afterId': after.id,
          });
          final raw = result.data['items'];
          if (raw is List && raw.isNotEmpty) {
            final items = raw
                .whereType<Map>()
                .map(
                  (item) => Edit.fromMap(
                    Map<String, dynamic>.from(item),
                    id: item['id'] as String? ?? '',
                  ),
                )
                .where((edit) => edit.id.isNotEmpty)
                .toList(growable: false);
            if (items.isNotEmpty) {
              return EditPage(
                items,
                hasMore: result.data['hasMore'] == true,
              );
            }
          }
        } on Object {
          // Fall through to the published score query.
        }
        var query = _firestore
            .collection('edits')
            .where('status', isEqualTo: 'published')
            .orderBy('score', descending: true)
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true);
        if (after != null) {
          query = query.startAfter([after.score, after.createdAt, after.id]);
        }
        final snapshot = await query.limit(limit + 1).get();
        final items = snapshot.docs
            .map((doc) => Edit.fromMap(doc.data(), id: doc.id))
            .toList();
        final more = items.length > limit;
        return EditPage(more ? items.sublist(0, limit) : items, hasMore: more);
      });

  @override
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('edits')
        .where('creatorId', isEqualTo: creatorId)
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => Edit.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<Edit>> getEdit(String editId) => _guard(() async {
    final doc = await _firestore.collection('edits').doc(editId).get();
    if (!doc.exists || doc.data() == null) throw StateError('Edit not found.');
    return Edit.fromMap(doc.data()!, id: doc.id);
  });

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  @override
  Future<Result<Edit>> repostEdit(String editId) => _guard(() async {
    final result = await _functions.httpsCallable('repostEdit').call({
      'editId': editId,
    });
    return (await getEdit(result.data['editId'] as String)).valueOrNull!;
  });

  @override
  Future<Result<void>> deleteEdit(String editId) =>
      _call('deleteEdit', {'editId': editId});

  @override
  Future<Result<void>> likeEdit({required String editId, required bool like}) =>
      _call('likeEdit', {'editId': editId, 'like': like});

  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) => _call('addEditComment', {
    'editId': editId,
    'text': text,
    'kind': kind,
    if (mentions.isNotEmpty) 'mentions': mentions,
    if (replyToCommentId != null && replyToCommentId.isNotEmpty)
      'replyToCommentId': replyToCommentId,
  });

  @override
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
    String eventType = 'progress',
  }) => _call('recordEditView', {
    'editId': editId,
    'sessionId': sessionId,
    'watchPercent': watchPercent,
    'watchSeconds': watchSeconds,
    'eventType': eventType,
  });

  @override
  Future<Result<void>> recordImpression({
    required String editId,
    required String sessionId,
  }) => _call('recordEditView', {
    'editId': editId,
    'sessionId': sessionId,
    'watchPercent': 0,
    'watchSeconds': 0,
    'eventType': 'impression',
  });

  @override
  Future<Result<String>> startPlayback(String editId) => _guard(() async {
    final result = await _functions.httpsCallable('startEditPlayback').call({
      'editId': editId,
    });
    return result.data['sessionId'] as String;
  });

  @override
  Future<Result<List<EditComment>>> getComments(
    String editId, {
    EditComment? after,
    int limit = 30,
    EditCommentSort sort = EditCommentSort.newest,
  }) => _guard(() async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('edits')
        .doc(editId)
        .collection('comments')
        .orderBy(
          sort == EditCommentSort.top ? 'likesCount' : 'createdAt',
          descending: true,
        )
        .limit(limit.clamp(1, 50));
    final cursor = after;
    if (cursor != null) {
      if (sort == EditCommentSort.top) {
        query = query.startAfter(<Object>[cursor.likesCount]);
      } else if (cursor.createdAt != null) {
        query = query.startAfter(<Object>[
          Timestamp.fromDate(cursor.createdAt!),
        ]);
      }
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => EditComment.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<void>> commentAction({
    required String editId,
    required String commentId,
    required String action,
  }) => _call('editCommentAction', {
    'editId': editId,
    'commentId': commentId,
    'action': action,
  });

  @override
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  }) => _call('recordEditSignal', {'editId': editId, 'type': type});
}
