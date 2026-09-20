import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart' as result_lib;
import '../models/audio_models.dart';
import 'audio_repository.dart';

Failure mapAudioException(Object error) {
  if (error is Failure) return error;
  if (error is FirebaseFunctionsException) {
    return _mapCode(error.code, error.message);
  }
  return const UnknownError(
    'Something went wrong with audio. Please try again.',
  );
}

Failure _mapCode(String code, String? message) {
  final normalized = code.toLowerCase();
  if (normalized == 'cancelled')
    return const CancelledError('Audio operation canceled.');
  if (normalized == 'unavailable' || normalized == 'deadline-exceeded') {
    return const NetworkError('Check your connection and try again.');
  }
  if (normalized == 'unauthenticated') {
    return const PermissionError('Sign in again to use audio features.');
  }
  if (normalized == 'permission-denied') {
    return const PermissionError(
      'You do not have permission for this audio action.',
    );
  }
  if (normalized == 'not-found') return const NotFoundError('Audio not found.');
  if (normalized == 'failed-precondition') {
    return ValidationError(
      message ?? 'This audio action cannot be completed right now.',
    );
  }
  return const UnknownError(
    'Something went wrong with audio. Please try again.',
  );
}

class FirebaseAudioRepository implements AudioRepository {
  FirebaseAudioRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<result_lib.Result<String>> extractAudio({
    required String reelId,
    String? audioName,
    int startMs = 0,
    int durationMs = 15000,
  }) async {
    try {
      final result = await _functions.httpsCallable('extractReelAudio').call({
        'reelId': reelId,
        if (audioName != null && audioName.isNotEmpty) 'audioName': audioName,
        'startMs': startMs,
        'durationMs': durationMs,
      });
      return result_lib.Success(result.data['audioId'] as String);
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }

  @override
  Future<result_lib.Result<ReelAudioPage>> listAudios({
    int limit = 20,
    String? afterId,
    String type = 'trending',
  }) async {
    try {
      final result = await _functions.httpsCallable('listReelAudios').call({
        'limit': limit,
        if (afterId != null && afterId.isNotEmpty) 'afterId': afterId,
        'type': type,
      });
      final raw = result.data['items'] as List?;
      if (raw == null || raw.isEmpty)
        return result_lib.Success(ReelAudioPage(const [], hasMore: false));
      final items = raw
          .whereType<Map>()
          .map(
            (item) => ReelAudio.fromMap(
              Map<String, dynamic>.from(item),
              id: item['audioId'] as String? ?? '',
            ),
          )
          .toList(growable: false);
      return result_lib.Success(
        ReelAudioPage(items, hasMore: result.data['hasMore'] == true),
      );
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }

  @override
  Future<result_lib.Result<ReelAudio>> getAudio(String audioId) async {
    try {
      final result = await _functions.httpsCallable('getReelAudio').call({
        'audioId': audioId,
      });
      return result_lib.Success(
        ReelAudio.fromMap(
          Map<String, dynamic>.from(result.data),
          id: result.data['audioId'] as String? ?? audioId,
        ),
      );
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }

  @override
  Future<result_lib.Result<void>> useAudio({
    required String audioId,
    required String reelId,
  }) async {
    try {
      await _functions.httpsCallable('useReelAudio').call({
        'audioId': audioId,
        'reelId': reelId,
      });
      return const result_lib.Success<void>(null);
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }

  @override
  Future<result_lib.Result<void>> removeAudio(String reelId) async {
    try {
      await _functions.httpsCallable('removeReelAudio').call({
        'reelId': reelId,
      });
      return const result_lib.Success<void>(null);
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }

  @override
  Future<result_lib.Result<List<ReelAudio>>> searchAudios({
    required String query,
    int limit = 15,
  }) async {
    try {
      final result = await _functions.httpsCallable('searchReelAudios').call({
        'query': query,
        'limit': limit,
      });
      final raw = result.data['items'] as List?;
      if (raw == null || raw.isEmpty) return result_lib.Success(const []);
      return result_lib.Success(
        raw
            .whereType<Map>()
            .map(
              (item) => ReelAudio.fromMap(
                Map<String, dynamic>.from(item),
                id: item['audioId'] as String? ?? '',
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (e) {
      return result_lib.FailureResult(mapAudioException(e));
    }
  }
}

class UnavailableAudioRepository implements AudioRepository {
  UnavailableAudioRepository(this.message);
  final String message;

  Failure _unavailable() => UnavailableError(message);

  @override
  Future<result_lib.Result<String>> extractAudio({
    required String reelId,
    String? audioName,
    int startMs = 0,
    int durationMs = 15000,
  }) => Future.value(result_lib.FailureResult(_unavailable()));

  @override
  Future<result_lib.Result<ReelAudioPage>> listAudios({
    int limit = 20,
    String? afterId,
    String type = 'trending',
  }) => Future.value(result_lib.FailureResult(_unavailable()));

  @override
  Future<result_lib.Result<ReelAudio>> getAudio(String audioId) =>
      Future.value(result_lib.FailureResult(_unavailable()));

  @override
  Future<result_lib.Result<void>> useAudio({
    required String audioId,
    required String reelId,
  }) => Future.value(result_lib.FailureResult(_unavailable()));

  @override
  Future<result_lib.Result<void>> removeAudio(String reelId) =>
      Future.value(result_lib.FailureResult(_unavailable()));

  @override
  Future<result_lib.Result<List<ReelAudio>>> searchAudios({
    required String query,
    int limit = 15,
  }) => Future.value(result_lib.FailureResult(_unavailable()));
}
