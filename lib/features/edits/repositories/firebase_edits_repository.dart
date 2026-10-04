import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/edit_storage_put.dart';
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
    'Something went wrong while preparing your Edit. Please try again.',
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
  if (normalized == 'resource-exhausted' || normalized == 'quota-exceeded') {
    // §15.2 daily upload quota. The server names the limit in the message;
    // surfacing it beats a generic "something went wrong".
    return RateLimitedError(
      message ?? 'You have reached your daily upload limit. Try again tomorrow.',
    );
  }
  if (normalized == 'failed-precondition') {
    return ValidationError(
      message ??
          'This Edit cannot continue yet. Try again or replace the video.',
    );
  }
  if (normalized == 'not-found') {
    return const NotFoundError('Edit not found.');
  }
  if (normalized == 'invalid-argument') {
    return ValidationError(message ?? 'That Edit request was invalid.');
  }
  return const UnknownError(
    'Something went wrong while preparing your Edit. Please try again.',
  );
}

/// Normalizes user-entered tag text into the canonical, de-duplicated,
/// lower-cased form the server expects. Accepts `#tag`, `tag`, comma,
/// whitespace, and the Arabic comma as separators.
List<String> _parseTags(String? input, {required int max, int? maxLength}) {
  if (input == null) return const <String>[];
  final seen = <String>{};
  final result = <String>[];
  final parts = input
      .split(RegExp(r'[\s,#،]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  for (final part in parts) {
    final cleaned = part.startsWith('#') ? part.substring(1) : part;
    final key = cleaned.toLowerCase();
    if (maxLength != null && key.length > maxLength) continue;
    if (seen.add(key)) result.add(key);
    if (result.length >= max) break;
  }
  return result;
}

class FirebaseEditsRepository
    implements EditsRepository, AnimeEditsRepository, CharacterEditsRepository {
  FirebaseEditsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    bool reels = false,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _reels = reels;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final bool _reels;
  UploadTask? _activeUpload;

  String get _collection => _reels ? 'reels' : 'edits';
  String _callable(String editName) {
    if (!_reels) return editName;
    return editName.replaceFirst('Edit', 'Reel').replaceFirst('edit', 'reel');
  }

  String _returnedId(Map<dynamic, dynamic> data) {
    return (data['reelId'] ?? data['editId']) as String;
  }

  Map<String, String> _uploadMetadata({String? fileName, int? sizeBytes}) {
    final metadata = <String, String>{};
    final name = fileName;
    if (name != null) metadata['fileName'] = name;
    if (sizeBytes != null) metadata['clientSize'] = '$sizeBytes';
    return metadata;
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
    String? hashtags,
    String? characterTags,
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
        hashtags: _parseTags(hashtags, max: 12, maxLength: 64),
        characterIds: _parseTags(characterTags, max: 8, maxLength: 128),
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
    String? hashtags,
    String? characterTags,
    String? audioId,
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
      final startPayload = <String, dynamic>{
        'caption': caption,
        'animeTag': animeTag,
      };
      // Tags are normalized client-side for a clean payload, but the server
      // re-validates and owns the stored values.
      final parsedHashtags = _parseTags(hashtags, max: 12, maxLength: 64);
      if (parsedHashtags.isNotEmpty) {
        startPayload['hashtags'] = parsedHashtags;
      }
      final parsedCharacters =
          _parseTags(characterTags, max: 8, maxLength: 128);
      if (parsedCharacters.isNotEmpty) {
        startPayload['characterIds'] = parsedCharacters;
      }
      // Sound track is chosen at publish time, not at play time. Sending it
      // here means the server validates the id against `reelAudios` before any
      // byte is uploaded, so a bad id fails fast instead of after the upload.
      final trimmedAudioId = audioId?.trim();
      if (trimmedAudioId != null && trimmedAudioId.isNotEmpty) {
        startPayload['audioId'] = trimmedAudioId;
      }
      final key = idempotencyKey;
      if (key != null) startPayload['idempotencyKey'] = key;
      final start = await _functions
          .httpsCallable(_callable('startEditUpload'))
          .call(startPayload);
      path = start.data['videoPath'] as String;
      editId = _returnedId(start.data);
    }
    // Always force exact video/mp4 — Storage rules reject codec-suffixed types.
    final task = putEditVideo(
      _storage.ref(path),
      source,
      SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: _uploadMetadata(
          fileName: fileName,
          sizeBytes: sizeBytes,
        ),
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

    // Explicit finalize — recovers when Storage finalize trigger is delayed/missed.
    final finalized = await finalizeEditUpload(editId);
    if (finalized.isSuccess) {
      return finalized.valueOrNull!;
    }
    // Upload itself succeeded; surface server state even if finalize soft-fails.
    return _readEdit(
      editId,
      caption: caption,
      animeTag: animeTag,
      hashtags: hashtags,
      characterTags: characterTags,
    );
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
    final task = _activeUpload;
    if (task == null) return const Success<void>(null);
    await task.cancel();
    _activeUpload = null;
    return const Success<void>(null);
  }

  @override
  Stream<Result<Edit>> watchEdit(String editId) {
    return _firestore.collection(_collection).doc(editId).snapshots().map((
      snap,
    ) {
      if (!snap.exists || snap.data() == null) {
        return const FailureResult<Edit>(NotFoundError('Edit not found.'));
      }
      return Success(Edit.fromMap(snap.data()!, id: snap.id));
    });
  }

  @override
  Future<Result<void>> retryProcessing(String editId) =>
      _call(_callable('retryEditProcessing'), {'editId': editId});

  @override
  Future<Result<EditPage>> getFeed({
    Edit? after,
    int limit = 5,
    String? audioId,
    String? animeId,
    String? characterId,
    String? hashtag,
    String? creatorId,
    FeedType feedType = FeedType.forYou,
  }) => _guard(() async {
        final normalizedHashtag = hashtag?.trim().replaceAll('#', '').toLowerCase();
        try {
          // The server owns both the scope and the ranking strategy. The
          // client only declares what it is asking for.
          final payload = <String, dynamic>{
            'limit': limit,
            'feedType': feedType.name,
            if (after != null) 'afterId': after.id,
          };
          if (audioId != null) payload['audioId'] = audioId;
          if (animeId != null) payload['animeId'] = animeId;
          if (characterId != null) payload['characterId'] = characterId;
          if (creatorId != null) payload['creatorId'] = creatorId;
          if (normalizedHashtag != null && normalizedHashtag.isNotEmpty) {
            payload['hashtag'] = normalizedHashtag;
          }
          final result = await _functions
              .httpsCallable(_callable('getEditFeed'))
              .call(payload);
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
        // Fallback: keep the server's own score ordering and apply the
        // requested scope in memory. This deliberately does NOT re-rank for
        // feedType — a client-side "trending" guess would be a lie. It also
        // avoids requiring a composite index per scope field.
        return _scopedFallbackFeed(
          limit: limit,
          after: after,
          audioId: audioId,
          animeId: animeId,
          characterId: characterId,
          hashtag: normalizedHashtag,
          creatorId: creatorId,
        );
      });

  static bool _scopeMatches(
    Edit edit, {
    String? audioId,
    String? animeId,
    String? characterId,
    String? hashtag,
    String? creatorId,
  }) {
    if (audioId != null && edit.audioId != audioId) return false;
    if (animeId != null && edit.animeId != animeId) return false;
    if (creatorId != null && edit.creatorId != creatorId) return false;
    if (characterId != null && !edit.characterIds.contains(characterId)) {
      return false;
    }
    if (hashtag != null && hashtag.isNotEmpty && !edit.hashtags.contains(hashtag)) {
      return false;
    }
    return true;
  }

  Future<EditPage> _scopedFallbackFeed({
    required int limit,
    Edit? after,
    String? audioId,
    String? animeId,
    String? characterId,
    String? hashtag,
    String? creatorId,
  }) async {
    var query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'published')
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter([after.score, after.createdAt, after.id]);
    }
    final batchSize = limit < 5 ? limit * 2 : 10;
    final matches = <Edit>[];
    var sourceExhausted = false;
    for (var batch = 0; batch < 6 && !sourceExhausted; batch++) {
      final snapshot = await query.limit(batchSize).get();
      final docs = snapshot.docs;
      if (docs.isEmpty) {
        sourceExhausted = true;
        break;
      }
      if (docs.length < batchSize) sourceExhausted = true;
      for (final doc in docs) {
        final edit = Edit.fromMap(doc.data(), id: doc.id);
        if (_scopeMatches(
          edit,
          audioId: audioId,
          animeId: animeId,
          characterId: characterId,
          hashtag: hashtag,
          creatorId: creatorId,
        )) {
          matches.add(edit);
        }
      }
      query = query.startAfterDocument(docs.last);
    }
    final page = matches.take(limit).toList(growable: false);
    // Honest paging: if we filled the page and the source still had documents
    // left to scan, there is likely more.
    final hasMore = !sourceExhausted || matches.length > limit;
    return EditPage(page, hasMore: hasMore);
  }

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

  @override
  Future<Result<List<Edit>>> getCharacterEdits(
    String characterId, {
    int limit = 12,
  }) => _guard(() async {
    final id = characterId.trim();
    if (id.isEmpty) return const <Edit>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'published')
        .where('characterIds', arrayContains: id)
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit.clamp(1, 24))
        .get();
    return snapshot.docs
        .map((doc) => Edit.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<List<Edit>>> getAnimeEdits(
    String animeId, {
    int limit = 12,
  }) => _guard(() async {
    final id = animeId.trim();
    if (id.isEmpty) return const <Edit>[];
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'published')
        .where('animeTag', isEqualTo: id)
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit.clamp(1, 24))
        .get();
    return snapshot.docs
        .map((doc) => Edit.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<Edit>> getEdit(String editId) => _guard(() async {
    final doc = await _firestore.collection(_collection).doc(editId).get();
    if (!doc.exists || doc.data() == null) {
      throw const NotFoundError('Edit not found.');
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
