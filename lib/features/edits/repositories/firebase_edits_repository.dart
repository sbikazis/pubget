import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
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

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      return FailureResult(
        error is FirebaseException && error.code == 'unavailable'
            ? const NetworkError('Check your connection and try again.')
            : UnknownError(error.toString()),
      );
    }
  }

  @override
  Future<Result<Edit>> uploadEdit({
    required Uint8List bytes,
    required String contentType,
    required String caption,
    required String animeTag,
    UploadProgress? onProgress,
  }) => _guard(() async {
    final start = await _functions.httpsCallable('startEditUpload').call({
      'caption': caption,
      'animeTag': animeTag,
    });
    final path = start.data['videoPath'] as String;
    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    await task;
    onProgress?.call(1);
    final editId = start.data['editId'] as String;
    final completed = await _firestore
        .collection('edits')
        .doc(editId)
        .snapshots()
        .firstWhere((doc) => doc.data()?['status'] != 'processing')
        .timeout(const Duration(minutes: 5));
    final data = completed.data();
    if (data == null || data['status'] != 'published') {
      throw StateError(
        'Video processing failed. Choose a valid MP4 and retry.',
      );
    }
    return Edit.fromMap(data, id: editId);
  });

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) =>
      _guard(() async {
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
  }) => _call('addEditComment', {'editId': editId, 'text': text});

  @override
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
  }) => _call('recordEditView', {
    'editId': editId,
    'sessionId': sessionId,
    'watchPercent': watchPercent,
    'watchSeconds': watchSeconds,
  });

  @override
  Future<Result<String>> startPlayback(String editId) => _guard(() async {
    final result = await _functions.httpsCallable('startEditPlayback').call({
      'editId': editId,
    });
    return result.data['sessionId'] as String;
  });

  @override
  Future<Result<List<EditComment>>> getComments(String editId) =>
      _guard(() async {
        final snapshot = await _firestore
            .collection('edits')
            .doc(editId)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();
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
