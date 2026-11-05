import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class KirariReel {
  const KirariReel({
    required this.id,
    required this.creatorId,
    required this.caption,
    required this.videoUrl,
    required this.coverUrl,
    required this.durationSeconds,
    required this.likesCount,
    required this.commentsCount,
    this.audioId,
    this.audioAttribution = const <String, dynamic>{},
    this.renditionPaths = const <String, String>{},
  });

  final String id;
  final String creatorId;
  final String caption;
  final String videoUrl;
  final String coverUrl;
  final double durationSeconds;
  final int likesCount;
  final int commentsCount;
  final String? audioId;
  final Map<String, dynamic> audioAttribution;
  final Map<String, String> renditionPaths;

  factory KirariReel.fromMap(Map<dynamic, dynamic> map) {
    return KirariReel(
      id: map['id'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      caption: map['caption'] as String? ?? '',
      videoUrl: map['playbackUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      audioId: map['audioId'] as String?,
      audioAttribution: map['audioAttribution'] is Map
          ? Map<String, dynamic>.from(map['audioAttribution'] as Map)
          : const <String, dynamic>{},
      renditionPaths: map['renditionPaths'] is Map
          ? Map<String, String>.from(map['renditionPaths'] as Map)
          : (map['renditions'] is Map
              ? (map['renditions'] as Map).map((key, value) => MapEntry(
                  key.toString(), value is Map ? (value['path'] as String? ?? '') : '',
                ))
              : const <String, String>{}),
    );
  }
}

class KirariAudioTrack {
  const KirariAudioTrack({
    required this.id, required this.title, required this.artist,
    required this.license, required this.attribution, required this.audioUrl,
  });
  final String id;
  final String title;
  final String artist;
  final String license;
  final String attribution;
  final String audioUrl;

  factory KirariAudioTrack.fromMap(Map<dynamic, dynamic> map, String url) =>
      KirariAudioTrack(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? 'Untitled audio',
        artist: map['artist'] as String? ?? '',
        license: map['license'] as String? ?? 'unknown',
        attribution: map['attribution'] as String? ?? '',
        audioUrl: url,
      );
}

class KirariUploadSession {
  const KirariUploadSession({required this.reelId, required this.storagePath});
  final String reelId;
  final String storagePath;
}

class KirariFeedPageResult {
  const KirariFeedPageResult(this.items, {required this.hasMore, this.nextCursor});
  final List<KirariReel> items;
  final bool hasMore;
  final Map<String, dynamic>? nextCursor;
}

abstract interface class KirariRepository {
  Future<KirariFeedPageResult> getFeed({String type = 'forYou', int limit = 8, Map<String, dynamic>? cursor});
  Future<KirariFeedPageResult> getHashtagFeed({required String hashtag, int limit = 8});
  Future<List<KirariAudioTrack>> getAudioLibrary({int limit = 30});
  Future<List<KirariReel>> getReelsByAudio(String audioId, {int limit = 24});
  Future<List<KirariReel>> getCreatorReels(String creatorId, {int limit = 20});
  Future<KirariReel> getReel(String reelId);
  Future<String> getPlaybackUrl(KirariReel reel, {required int quality});
  Future<void> giveCreatorRespect({required String creatorId, required int value});
  Future<List<Map<String, dynamic>>> getComments(String reelId, {String? before, int limit = 30});
  Future<void> addComment(String reelId, String text, {String? parentId});
  Future<void> commentAction(String reelId, String commentId, String kind);
  Future<void> setCreatorMute({required String creatorId, required bool muted});
  Future<List<Map<String, dynamic>>> getModerationQueue({int limit = 50});
  Future<void> reviewContent({required String reelId, String? commentId, required String decision});
  Future<KirariUploadSession> startUpload({required String caption, required List<String> hashtags, required String idempotencyKey, Map<String, dynamic> editSettings = const <String, dynamic>{}, String? audioId});
  Future<void> uploadSource({required String storagePath, required XFile video, required void Function(double progress) onProgress});
  Future<void> finalizeUpload(String reelId);
  Future<void> retryProcessing(String reelId);
  Future<void> cancelUpload(String reelId);
  Future<void> action(String reelId, String kind);
  Future<String> startPlayback(String reelId);
  Future<void> recordPlayback({required String reelId, required String sessionId, required String eventId, required double watchSeconds, required double percent});
  Future<void> deleteReel(String reelId);
  Future<XFile?> pickGalleryVideo();
}

class FirebaseKirariRepository implements KirariRepository {
  FirebaseKirariRepository({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker();

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  static const MethodChannel _androidUploadChannel = MethodChannel('pubget/kirari_upload');
  final Map<String, Future<String>> _downloadUrlCache = <String, Future<String>>{};

  Future<String> _downloadUrl(String storagePath) async {
    final cached = _downloadUrlCache.remove(storagePath);
    if (cached != null) {
      _downloadUrlCache[storagePath] = cached;
      return cached;
    }
    final pending = _storage.ref(storagePath).getDownloadURL();
    _downloadUrlCache[storagePath] = pending;
    while (_downloadUrlCache.length > 128) {
      _downloadUrlCache.remove(_downloadUrlCache.keys.first);
    }
    try {
      return await pending;
    } catch (_) {
      _downloadUrlCache.remove(storagePath);
      rethrow;
    }
  }

  Future<Map<dynamic, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable(name).call<Map<dynamic, dynamic>>(data);
    return result.data;
  }

  Future<List<KirariReel>> _resolveReels(dynamic raw) async {
    if (raw is! List) return const <KirariReel>[];
    final resolved = await Future.wait(raw.whereType<Map>().map((value) async {
      try {
        final map = Map<dynamic, dynamic>.from(value);
        final variants = map['renditions'];
        final paths = variants is Map ? variants : const <dynamic, dynamic>{};
        final preferred = paths['540'] ?? paths['360'] ?? paths['720'];
        final videoPath = preferred is Map ? preferred['path'] as String? : null;
        final coverPath = map['coverPath'] as String?;
        if (videoPath == null || videoPath.isEmpty) return null;
        final videoUrl = _downloadUrl(videoPath);
        final coverUrl = coverPath == null || coverPath.isEmpty
            ? Future<String>.value('')
            : _downloadUrl(coverPath).catchError((_) => '');
        final urls = await Future.wait<String>([videoUrl, coverUrl]);
        return KirariReel.fromMap({
          ...map,
          'playbackUrl': urls.first,
          'coverUrl': urls[1],
        });
      } catch (_) {
        // A single unavailable media object must not discard the whole feed.
        return null;
      }
    }));
    return resolved.whereType<KirariReel>().toList(growable: false);
  }

  @override
  Future<KirariFeedPageResult> getFeed({String type = 'forYou', int limit = 8, Map<String, dynamic>? cursor}) async {
    final result = await _call('getKirariFeed', {
      'type': type,
      'limit': limit,
      if (cursor != null) ...cursor,
    });
    final reels = await _resolveReels(result['items']);
    final nextCursor = result['nextCursor'];
    return KirariFeedPageResult(
      reels,
      hasMore: result['hasMore'] == true,
      nextCursor: nextCursor is Map ? Map<String, dynamic>.from(nextCursor) : null,
    );
  }

  @override
  Future<KirariFeedPageResult> getHashtagFeed({required String hashtag, int limit = 8}) async {
    final result = await _call('getKirariHashtagFeed', {'hashtag': hashtag, 'limit': limit});
    return KirariFeedPageResult(
      await _resolveReels(result['items']),
      hasMore: result['hasMore'] == true,
    );
  }

  @override
  Future<List<KirariReel>> getReelsByAudio(String audioId, {int limit = 24}) async {
    final result = await _call('getKirariReelsByAudio', {'audioId': audioId, 'limit': limit});
    return _resolveReels(result['items']);
  }

  @override
  Future<List<KirariReel>> getCreatorReels(String creatorId, {int limit = 20}) async {
    final result = await _call('getKirariCreatorReels', {'creatorId': creatorId, 'limit': limit});
    return _resolveReels(result['items']);
  }

  @override
  Future<KirariReel> getReel(String reelId) async {
    final map = await _call('getKirariReel', {'reelId': reelId});
    final variants = map['renditions'];
    final paths = variants is Map ? variants : const <dynamic, dynamic>{};
    final preferred = paths['540'] ?? paths['360'] ?? paths['720'];
    final videoPath = preferred is Map ? preferred['path'] as String? : null;
    if (videoPath == null || videoPath.isEmpty) throw StateError('This video is not available.');
    final coverPath = map['coverPath'] as String?;
    return KirariReel.fromMap({
      ...map,
      'playbackUrl': await _storage.ref(videoPath).getDownloadURL(),
      'coverUrl': coverPath == null || coverPath.isEmpty
          ? '' : await _storage.ref(coverPath).getDownloadURL(),
    });
  }

  @override
  Future<String> getPlaybackUrl(KirariReel reel, {required int quality}) async {
    final path = reel.renditionPaths['$quality'];
    if (path == null || path.isEmpty) return reel.videoUrl;
    return _downloadUrl(path);
  }

  @override
  Future<List<Map<String, dynamic>>> getModerationQueue({int limit = 50}) async {
    final result = await _call('getKirariModerationQueue', {'limit': limit});
    final raw = result['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  @override
  Future<void> reviewContent({required String reelId, String? commentId, required String decision}) async {
    await _call('reviewKirariContent', {
      'reelId': reelId,
      if (commentId != null) 'commentId': commentId,
      'decision': decision,
    });
  }

  @override
  Future<void> giveCreatorRespect({required String creatorId, required int value}) async {
    await _call('giveRespect', {'toUserId': creatorId, 'value': value});
  }

  @override
  Future<List<KirariAudioTrack>> getAudioLibrary({int limit = 30}) async {
    final result = await _call('getKirariAudioLibrary', {'limit': limit});
    final raw = result['items'];
    final tracks = <KirariAudioTrack>[];
    if (raw is List) {
      for (final value in raw.whereType<Map>()) {
        final map = Map<dynamic, dynamic>.from(value);
        final path = map['audioPath'] as String?;
        if (path == null || path.isEmpty) continue;
        final url = await _storage.ref(path).getDownloadURL();
        tracks.add(KirariAudioTrack.fromMap(map, url));
      }
    }
    return tracks;
  }

  @override
  Future<List<Map<String, dynamic>>> getComments(
    String reelId, {String? before, int limit = 30}
  ) async {
    final result = await _call('getKirariComments', {
      'reelId': reelId, 'limit': limit, if (before != null) 'before': before,
    });
    final raw = result['items'];
    return raw is List
        ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  @override
  Future<void> addComment(String reelId, String text, {String? parentId}) async {
    await _call('addKirariComment', {
      'reelId': reelId, 'text': text, if (parentId != null) 'parentId': parentId,
    });
  }

  @override
  Future<void> commentAction(String reelId, String commentId, String kind) async {
    await _call('kirariCommentAction', {
      'reelId': reelId, 'commentId': commentId, 'kind': kind,
    });
  }

  @override
  Future<void> setCreatorMute({required String creatorId, required bool muted}) async {
    await _call('setKirariCreatorMute', {'creatorId': creatorId, 'muted': muted});
  }

  @override
  Future<KirariUploadSession> startUpload({
    required String caption,
    required List<String> hashtags,
    required String idempotencyKey,
    Map<String, dynamic> editSettings = const <String, dynamic>{},
    String? audioId,
  }) async {
    final result = await _call('startKirariUpload', {
      'caption': caption,
      'hashtags': hashtags,
      'idempotencyKey': idempotencyKey,
      'editSettings': editSettings,
      if (audioId != null) 'audioId': audioId,
    });
    final path = result['storagePath'] as String?;
    final reelId = result['reelId'] as String?;
    if (path == null || reelId == null) {
      throw StateError('The server returned an incomplete Kirari upload session.');
    }
    return KirariUploadSession(reelId: reelId, storagePath: path);
  }

  @override
  Future<void> uploadSource({
    required String storagePath,
    required XFile video,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(video.path);
    final reference = _storage.ref(storagePath);

    // If the previous attempt completed the object but the app stopped before
    // finalization, do not upload the same durable local file a second time.
    try {
      final metadata = await reference.getMetadata();
      if (metadata.size == await file.length()) {
        onProgress(1);
        return;
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }

    if (Platform.isAndroid) {
      _androidUploadChannel.setMethodCallHandler((call) async {
        final arguments = call.arguments;
        if (call.method == 'progress' && arguments is Map) {
          final progress = (arguments['progress'] as num?)?.toDouble();
          if (progress != null) onProgress(progress.clamp(0, 1).toDouble());
        }
      });
      try {
        await _androidUploadChannel.invokeMethod<void>('uploadSource', {
          'storagePath': storagePath,
          'localPath': file.absolute.path,
        });
        onProgress(1);
      } finally {
        _androidUploadChannel.setMethodCallHandler(null);
      }
      return;
    }

    // iOS and other platforms use the Flutter StorageTask implementation.
    // Android uses the native SDK overload with a persisted upload session URI.
    final task = reference.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4', customMetadata: {
        'uploadedBy': 'kirari-client',
      }),
    );
    // Firebase Storage performs resumable transfers internally. Scope the
    // progress listener to this task so retries do not retain stale listeners.
    final subscription = task.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) onProgress(snapshot.bytesTransferred / total);
    });
    try {
      await task;
      onProgress(1);
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> finalizeUpload(String reelId) async {
    await _call('finalizeKirariUpload', {'reelId': reelId});
  }

  @override
  Future<void> retryProcessing(String reelId) async {
    await _call('retryKirariProcessing', {'reelId': reelId});
  }

  @override
  Future<void> cancelUpload(String reelId) async {
    await _call('cancelKirariUpload', {'reelId': reelId});
  }

  @override
  Future<void> action(String reelId, String kind) async {
    await _call('kirariAction', {'reelId': reelId, 'kind': kind});
  }

  @override
  Future<String> startPlayback(String reelId) async {
    final result = await _call('startKirariPlayback', {'reelId': reelId});
    final id = result['sessionId'] as String?;
    if (id == null || id.isEmpty) throw StateError('Playback session was not created.');
    return id;
  }

  @override
  Future<void> recordPlayback({
    required String reelId,
    required String sessionId,
    required String eventId,
    required double watchSeconds,
    required double percent,
  }) async {
    await _call('recordKirariPlayback', {
      'reelId': reelId,
      'sessionId': sessionId,
      'eventId': eventId,
      'watchSeconds': watchSeconds,
      'percent': percent,
    });
  }

  @override
  Future<void> deleteReel(String reelId) async {
    await _call('deleteKirariReel', {'reelId': reelId});
  }

  @override
  Future<XFile?> pickGalleryVideo() => _picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(seconds: 60),
  );
}

class KirariPlaybackReporter {
  KirariPlaybackReporter(this.repository, this.reelId);

  final KirariRepository repository;
  final String reelId;
  String? _sessionId;
  int _sequence = 0;
  double _lastPosition = 0;
  bool _busy = false;

  Future<void> start() async {
    _sessionId = await repository.startPlayback(reelId);
    _lastPosition = 0;
    _sequence = 0;
  }

  Future<void> report(VideoPlayerController controller) async {
    final session = _sessionId;
    if (session == null || _busy || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inMilliseconds / 1000;
    final position = controller.value.position.inMilliseconds / 1000;
    if (duration <= 0) return;
    if (position + 0.5 < _lastPosition && _lastPosition / duration >= 0.95) {
      await start();
      return;
    }
    if (position <= _lastPosition) return;
    final watched = (position - _lastPosition).clamp(0, 5).toDouble();
    if (watched <= 0) return;
    _lastPosition = position;
    _busy = true;
    try {
      await repository.recordPlayback(
        reelId: reelId,
        sessionId: session,
        eventId: '$session-${_sequence++}',
        watchSeconds: watched,
        percent: (position / duration * 100).clamp(0, 100).toDouble(),
      );
    } finally {
      _busy = false;
    }
  }
}


class UnavailableKirariRepository implements KirariRepository {
  UnavailableKirariRepository(this.message);
  final String message;
  StateError _unavailable() => StateError(message);

  @override
  Future<KirariFeedPageResult> getFeed({String type = 'forYou', int limit = 8, Map<String, dynamic>? cursor}) async => throw _unavailable();
  @override
  Future<KirariFeedPageResult> getHashtagFeed({required String hashtag, int limit = 8}) async => throw _unavailable();
  @override
  Future<List<KirariAudioTrack>> getAudioLibrary({int limit = 30}) async => throw _unavailable();
  @override
  Future<String> getPlaybackUrl(KirariReel reel, {required int quality}) async => throw _unavailable();
  @override
  Future<List<KirariReel>> getCreatorReels(String creatorId, {int limit = 20}) async => throw _unavailable();
  @override
  Future<KirariReel> getReel(String reelId) async => throw _unavailable();
  @override
  Future<List<KirariReel>> getReelsByAudio(String audioId, {int limit = 24}) async => throw _unavailable();
  @override
  Future<List<Map<String, dynamic>>> getModerationQueue({int limit = 50}) async => throw _unavailable();
  @override
  Future<void> reviewContent({required String reelId, String? commentId, required String decision}) async => throw _unavailable();
  @override
  Future<void> giveCreatorRespect({required String creatorId, required int value}) async => throw _unavailable();
  @override
  Future<List<Map<String, dynamic>>> getComments(String reelId, {String? before, int limit = 30}) async => throw _unavailable();
  @override
  Future<void> addComment(String reelId, String text, {String? parentId}) async => throw _unavailable();
  @override
  Future<void> commentAction(String reelId, String commentId, String kind) async => throw _unavailable();
  @override
  Future<void> setCreatorMute({required String creatorId, required bool muted}) async => throw _unavailable();
  @override
  Future<KirariUploadSession> startUpload({required String caption, required List<String> hashtags, required String idempotencyKey, Map<String, dynamic> editSettings = const <String, dynamic>{}, String? audioId}) async => throw _unavailable();
  @override
  Future<void> uploadSource({required String storagePath, required XFile video, required void Function(double progress) onProgress}) async => throw _unavailable();
  @override
  Future<void> finalizeUpload(String reelId) async => throw _unavailable();
  @override
  Future<void> retryProcessing(String reelId) async => throw _unavailable();
  @override
  Future<void> cancelUpload(String reelId) async => throw _unavailable();
  @override
  Future<void> action(String reelId, String kind) async => throw _unavailable();
  @override
  Future<String> startPlayback(String reelId) async => throw _unavailable();
  @override
  Future<void> recordPlayback({required String reelId, required String sessionId, required String eventId, required double watchSeconds, required double percent}) async => throw _unavailable();
  @override
  Future<void> deleteReel(String reelId) async => throw _unavailable();
  @override
  Future<XFile?> pickGalleryVideo() async => null;
}
