import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/media_upload_service.dart';
import '../../../core/storage/r2_storage_service.dart';
import '../models/edit_models.dart';
import 'edits_repository.dart';

Failure mapEditException(Object error) {
  if (error is Failure) return error;
  if (error is FirebaseFunctionsException) {
    return _mapCode(error.code, error.message);
  }
  if (error is FirebaseException) {
    return _mapCode(error.code, error.message);
  }
  final text = error.toString().toLowerCase();
  if (text.contains('not authorized') || text.contains('permission')) {
    return const PermissionError(
      'Could not upload this video securely. Sign in again, then retry.',
    );
  }
  return const UnknownError(
    'Something went wrong while preparing your Reel. Please try again.',
  );
}

Failure _mapCode(String code, String? message) {
  final normalized = code.toLowerCase();
  final body = (message ?? '').toLowerCase();
  if (normalized == 'canceled') {
    return const CancelledError('Upload canceled.');
  }
  if (normalized == 'unavailable' ||
      normalized == 'deadline-exceeded' ||
      normalized == 'network-request-failed') {
    return const NetworkError('Check your connection and try again.');
  }
  if (normalized == 'unauthenticated') {
    return const PermissionError(
      'Could not upload this video securely. Sign in again, then retry.',
    );
  }
  // Storage rules deny (unauthorized) is usually not an expired session —
  // e.g. production rules still blocking resumable UPDATE on edits/*.mp4.
  if (normalized == 'unauthorized' ||
      normalized == 'permission-denied' ||
      body.contains('not authorized') ||
      body.contains('permission')) {
    return const PermissionError(
      'Upload was blocked by storage security. Stay signed in and retry; if it keeps failing, rules may still be deploying.',
    );
  }
  if (normalized == 'failed-precondition') {
    return ValidationError(
      message ??
          'This Reel cannot continue yet. Try again or replace the video.',
    );
  }
  if (normalized == 'not-found') {
    return const NotFoundError('Reel not found.');
  }
  if (normalized == 'invalid-argument') {
    return ValidationError(message ?? 'That Reel request was invalid.');
  }
  return const UnknownError(
    'Something went wrong while preparing your Reel. Please try again.',
  );
}

class FirebaseEditsRepository implements EditsRepository {
  FirebaseEditsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool reels = false,
    MediaUploadService? mediaUploadService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _reels = reels,
       _mediaUploadService = mediaUploadService ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final MediaUploadService _mediaUploadService;
  final bool _reels;

  String get _collection => _reels ? 'reels' : 'edits';
  String _callable(String editName) {
    if (!_reels) return editName;
    return editName.replaceFirst('Edit', 'Reel').replaceFirst('edit', 'reel');
  }

  String _returnedId(Map<dynamic, dynamic> data) {
    return (data['reelId'] ?? data['editId']) as String;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Failure catch (error) {
      return FailureResult(error);
    } on Object catch (error) {
      return FailureResult(mapEditException(error));
    }
  }

  Future<Edit> _readEdit(
    String editId, {
    String? caption,
    String? animeTag,
  }) async {
    final snap = await _firestore.collection(_collection).doc(editId).get();
    if (!snap.exists || snap.data() == null) {
      return Edit(
        id: editId,
        creatorId: '',
        videoUrl: '',
        thumbnailUrl: '',
        caption: caption ?? '',
        animeTag: animeTag ?? '',
        likesCount: 0,
        commentsCount: 0,
        viewsCount: 0,
        score: 0,
        createdAt: DateTime.now(),
        status: 'processing',
      );
    }
    return Edit.fromMap(snap.data()!, id: editId);
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
    late final String editId;
    final resumeId = resumeEditId?.trim();
    if (resumeId != null && resumeId.isNotEmpty) {
      editId = resumeId;
    } else {
      final startPayload = <String, dynamic>{
        'caption': caption,
        'animeTag': animeTag,
      };
      final key = idempotencyKey;
      if (key != null) startPayload['idempotencyKey'] = key;
      final start = await _functions
          .httpsCallable(_callable('startEditUpload'))
          .call(startPayload);
      editId = _returnedId(start.data);
    }

    onStarted?.call(editId, resumeVideoPath ?? '');
    onProgress?.call(0.3);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    R2UploadResult result;
    final bytes = source.bytes;
    final path = source.path;
    if (path != null && path.isNotEmpty) {
      result = await _mediaUploadService.uploadReel(
        userId: uid,
        video: File(path),
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$editId.mp4');
      await file.writeAsBytes(bytes);
      result = await _mediaUploadService.uploadReel(userId: uid, video: file);
      await file.delete();
    } else {
      throw const UnknownError('No video data to upload');
    }

    onProgress?.call(0.7);

    try {
      await _firestore.collection(_collection).doc(editId).set({
        'videoUrl': result.publicUrl,
        'mediaKey': result.key,
        'status': 'processing',
      }, SetOptions(merge: true));
    } catch (_) {}

    onProgress?.call(1);

    try {
      final finalized = await finalizeEditUpload(editId);
      if (finalized.isSuccess) {
        return finalized.valueOrNull!;
      }
    } catch (_) {}

    return _readEdit(editId, caption: caption, animeTag: animeTag);
  });

  @override
  Future<Result<Edit>> finalizeEditUpload(String editId) => _guard(() async {
    await _functions.httpsCallable(_callable('finalizeEditUpload')).call({
      'editId': editId,
    });
    return _readEdit(editId);
  });

  @override
  Future<Result<void>> cancelUpload() async {
    return const Success<void>(null);
  }

  @override
  Stream<Result<Edit>> watchEdit(String editId) {
    return _firestore.collection(_collection).doc(editId).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) {
        return const FailureResult<Edit>(NotFoundError('Reel not found.'));
      }
      return Success(Edit.fromMap(snap.data()!, id: snap.id));
    });
  }

  @override
  Future<Result<void>> retryProcessing(String editId) =>
      _call(_callable('retryEditProcessing'), {'editId': editId});

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) =>
      _guard(() async {
        try {
          final result = await _functions
              .httpsCallable(_callable('getEditFeed'))
              .call({'limit': limit, if (after != null) 'afterId': after.id});
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
              return EditPage(items, hasMore: result.data['hasMore'] == true);
            }
          }
        } on Object {
          // Fall through to the published score query.
        }
        var query = _firestore
            .collection(_collection)
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
        .collection(_collection)
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

  /// Equality-only query on the stored `audioId`, so no composite index is
  /// required. Publishing state is filtered client-side.
  @override
  Future<Result<List<Edit>>> getEditsByAudio(
    String audioId, {
    int limit = 24,
  }) => _guard(() async {
    final id = audioId.trim();
    if (id.isEmpty) return const <Edit>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('audioId', isEqualTo: id)
        .limit(limit.clamp(1, 50))
        .get();
    return _publishedNewestFirst(snapshot.docs);
  });

  /// Single `array-contains` query on the stored `hashtags` array, so no
  /// composite index is required.
  @override
  Future<Result<List<Edit>>> getEditsByHashtag(
    String hashtag, {
    int limit = 24,
  }) => _guard(() async {
    final tag = hashtag.trim().replaceFirst(RegExp(r'^#+'), '');
    if (tag.isEmpty) return const <Edit>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('hashtags', arrayContains: tag)
        .limit(limit.clamp(1, 50))
        .get();
    return _publishedNewestFirst(snapshot.docs);
  });

  List<Edit> _publishedNewestFirst(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items =
        docs
            .map((doc) => Edit.fromMap(doc.data(), id: doc.id))
            .where((edit) => edit.isPublished)
            .toList(growable: false)
          ..sort((a, b) {
            final left = a.publishedAt ?? a.createdAt;
            final right = b.publishedAt ?? b.createdAt;
            if (left == null && right == null) return 0;
            if (left == null) return 1;
            if (right == null) return -1;
            return right.compareTo(left);
          });
    return items;
  }

  @override
  Future<Result<Edit>> getEdit(String editId) => _guard(() async {
    final doc = await _firestore.collection(_collection).doc(editId).get();
    if (!doc.exists || doc.data() == null) {
      throw const NotFoundError('Reel not found.');
    }
    return Edit.fromMap(doc.data()!, id: doc.id);
  });

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  @override
  Future<Result<Edit>> repostEdit(String editId) => _guard(() async {
    final result = await _functions.httpsCallable(_callable('repostEdit')).call(
      {'editId': editId},
    );
    return (await getEdit(_returnedId(result.data))).valueOrNull!;
  });

  @override
  Future<Result<void>> deleteEdit(String editId) =>
      _call(_callable('deleteEdit'), {'editId': editId});

  @override
  Future<Result<void>> likeEdit({required String editId, required bool like}) =>
      _call(_callable('likeEdit'), {'editId': editId, 'like': like});

  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) => _call(_callable('addEditComment'), {
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
  }) => _call(_callable('recordEditView'), {
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
  }) => _call(_callable('recordEditView'), {
    'editId': editId,
    'sessionId': sessionId,
    'eventType': 'impression',
    'watchPercent': 0,
    'watchSeconds': 0,
  });

  @override
  Future<Result<String>> startPlayback(String editId) => _guard(() async {
    final result = await _functions
        .httpsCallable(_callable('startEditPlayback'))
        .call({'editId': editId});
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
        .collection(_collection)
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
  }) => _call(_callable('editCommentAction'), {
    'editId': editId,
    'commentId': commentId,
    'action': action,
  });

  @override
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  }) => _call(_callable('recordEditSignal'), {'editId': editId, 'type': type});
}
