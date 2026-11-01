import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../errors/failure.dart';
import '../errors/result.dart';
import 'media_asset.dart';
import 'media_compressor.dart';
import 'media_duration.dart';
import 'media_kind.dart';
import 'media_keys.dart';
import 'media_limits.dart';
import 'media_storage_provider.dart';
import 'media_validation.dart';

/// Coarse upload phases for progress UIs.
enum MediaUploadPhase { validating, compressing, uploading, done }

typedef MediaUploadProgress = void Function(
  MediaUploadPhase phase,
  double fraction,
);

/// Maps anything thrown during an upload into a [Failure] the UI already
/// knows how to render.
Failure mapMediaException(Object error) {
  if (error is Failure) return error;
  if (error is TimeoutException) {
    return const TimeoutError('The upload timed out. Please try again.');
  }
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'canceled' || code == 'cancelled') {
      return const CancelledError('Upload canceled.');
    }
    if (code == 'unauthenticated') {
      return const PermissionError('Sign in again, then retry the upload.');
    }
    if (code == 'unauthorized' || code == 'permission-denied') {
      return const PermissionError(
        'Upload was blocked by storage security. Stay signed in and retry.',
      );
    }
    if (code == 'quota-exceeded' || code == 'resource-exhausted') {
      return const RateLimitedError('Storage is busy right now. Try again.');
    }
    if (code == 'not-found') {
      return const NotFoundError('The file was not found.');
    }
    if (code == 'network-request-failed' ||
        code == 'retry-limit-exceeded' ||
        code == 'unknown' ||
        code == 'internal') {
      return const NetworkError('Check your connection and try again.');
    }
    if (code == 'invalid-argument' || code == 'custom-object-metadata') {
      return ValidationError(error.message ?? 'That upload was invalid.');
    }
  }
  if (error is http.ClientException) {
    return const NetworkError('Check your connection and try again.');
  }
  return UnknownError(
    error is FormatException ? 'This file could not be read.' : 'Upload failed.',
  );
}

/// Validates → (compresses) → verifies → uploads, in that order, and returns
/// the metadata for what was stored.
///
/// Guarantees:
/// * the file name is never part of the storage key;
/// * duration and size are checked against the real bytes, not the extension;
/// * a failed compression can never push a file past the hard ceiling — the
///   ceiling is re-checked on the compressed output.
final class MediaUploadService {
  MediaUploadService({
    required MediaStorageProvider provider,
    required MediaCompressor compressor,
    this.limits = const MediaLimits(),
    Random? random,
    DateTime Function()? clock,
    Future<void> Function(Duration delay)? delay,
  })  : _provider = provider,
        _compressor = compressor,
        _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now,
        _delay = delay ?? ((d) => Future<void>.delayed(d));

  final MediaStorageProvider _provider;
  final MediaCompressor _compressor;
  final MediaLimits limits;
  final Random _random;
  final DateTime Function() _clock;
  final Future<void> Function(Duration delay) _delay;

  /// Backoff steps between transient upload attempts.
  static const List<int> _retryBackoffMs = <int>[300, 900];

  Future<Result<MediaAsset>> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
    MediaUploadProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    Failure? cancelledFailure() =>
        cancelled() ? const CancelledError('Upload canceled.') : null;

    try {
      onProgress?.call(MediaUploadPhase.validating, 0);

      if (ownerUid.trim().isEmpty) {
        return const FailureResult(
          PermissionError('Sign in to upload media.'),
        );
      }
      if (cancelled()) return FailureResult(cancelledFailure()!);

      final validation = validateMediaUpload(
        kind: kind,
        bytes: bytes,
        claimedContentType: claimedContentType,
        limits: limits,
        declaredExtension: fileName == null || fileName.isEmpty
            ? null
            : extensionOfFileName(fileName),
      );
      if (!validation.isAccepted) {
        return FailureResult(validation.failure!);
      }
      final signature = validation.signature!;

      final duration = parseMediaDuration(bytes, kind);
      if (!limits.allowsDuration(kind, duration)) {
        return FailureResult(_durationFailure(kind, duration));
      }
      if (cancelled()) return FailureResult(cancelledFailure()!);

      // Compression applies to images only; nothing else may be rewritten
      // here because video/audio transcoding happens server-side.
      Uint8List uploadBytes = bytes;
      String contentType = signature.contentType;
      int? width;
      int? height;
      if (kind == MediaKind.image) {
        onProgress?.call(MediaUploadPhase.compressing, 0.1);
        final compressed = await _compressor.compressImage(
          bytes,
          sourceContentType: signature.contentType,
          targetBytes: limits.imageTargetBytes,
        );
        uploadBytes = compressed.bytes;
        if (compressed.contentType.isNotEmpty) {
          contentType = compressed.contentType;
        }
        width = compressed.width;
        height = compressed.height;

        // Hard ceiling re-checked on the *compressed* output: a compression
        // failure must never authorize an oversized upload.
        if (uploadBytes.length > limits.maxBytesFor(kind)) {
          return FailureResult(
            ValidationError(
              'This image could not be compressed below the '
              '${limits.maxBytesFor(kind) ~/ (1024 * 1024)} MB limit.',
            ),
          );
        }
      }
      if (cancelled()) return FailureResult(cancelledFailure()!);

      onProgress?.call(MediaUploadPhase.uploading, 0.2);
      final extension = signature.extension;
      final storageKey = await _uploadWithRetry(
        ownerUid: ownerUid,
        kind: kind,
        bytes: uploadBytes,
        contentType: contentType,
        extension: extension,
        isCancelled: cancelled,
        onProgress: (p) => onProgress?.call(
          MediaUploadPhase.uploading,
          0.2 + 0.8 * p,
        ),
      );
      if (cancelled()) {
        // The object is already stored: remove it so a canceled upload never
        // leaves an unreachable object behind.
        try {
          await _provider.delete(storageKey);
        } on Object {
          // Best effort — the repository's delete path owns consistency.
        }
        return const FailureResult(CancelledError('Upload canceled.'));
      }

      onProgress?.call(MediaUploadPhase.done, 1);
      final now = _clock();
      return Success(
        MediaAsset(
          mediaId: _newMediaId(),
          ownerUid: ownerUid,
          storageKey: storageKey,
          backend: _provider.backend,
          kind: kind,
          contentType: contentType,
          sizeBytes: uploadBytes.length,
          createdAt: now,
          status: MediaUploadStatus.uploaded,
          durationSeconds:
              kind == MediaKind.image ? null : duration?.inSeconds,
          width: width,
          height: height,
          originalFileName: fileName,
          updatedAt: now,
        ),
      );
    } on Object catch (error) {
      return FailureResult(mapMediaException(error));
    }
  }

  Future<String> _uploadWithRetry({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    required bool Function() isCancelled,
    required void Function(double progress) onProgress,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      if (isCancelled()) throw const CancelledError('Upload canceled.');
      try {
        return await _provider.upload(
          ownerUid: ownerUid,
          kind: kind,
          bytes: bytes,
          contentType: contentType,
          extension: extension,
          onProgress: onProgress,
        );
      } on Object catch (error) {
        final failure = mapMediaException(error);
        final transient = failure is NetworkError ||
            failure is TimeoutError ||
            failure is UnavailableError ||
            failure is RateLimitedError;
        if (!transient || attempt >= limits.maxUploadAttempts) rethrow;
        await _delay(
          Duration(
            milliseconds:
                _retryBackoffMs[(attempt - 1).clamp(0, _retryBackoffMs.length - 1)],
          ),
        );
      }
    }
  }

  Failure _durationFailure(MediaKind kind, Duration? duration) {
    switch (kind) {
      case MediaKind.reels:
        if (duration == null) {
          return const ValidationError(
            'Could not verify this video\'s duration, so it was not uploaded.',
          );
        }
        final seconds = duration.inSeconds;
        if (seconds < limits.reelsMinDurationSeconds) {
          return ValidationError(
            'Reels must be at least '
            '${limits.reelsMinDurationSeconds} seconds.',
          );
        }
        return ValidationError(
          'Reels can be at most ${limits.reelsMaxDurationSeconds} seconds '
          '(this one is $seconds s).',
        );
      case MediaKind.audio:
        if (duration == null) {
          return const ValidationError(
            'Could not verify this audio file\'s duration.',
          );
        }
        return ValidationError(
          'Audio can be at most ${limits.audioMaxDurationSeconds} seconds '
          '(this one is ${duration.inSeconds} s).',
        );
      case MediaKind.image:
        return const ValidationError('This file is invalid.');
    }
  }

  String _newMediaId() => generateMediaId(_random);
}
