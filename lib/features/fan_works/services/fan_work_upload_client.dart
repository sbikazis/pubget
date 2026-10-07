import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';

import '../repositories/fan_work_repository.dart' show FanWorkUploadProgress;

/// One `Content-Range` slice of a resumable upload.
///
/// [start] is inclusive and [end] is inclusive, matching the GCS V4 protocol.
final class FanWorkUploadChunk {
  const FanWorkUploadChunk({
    required this.sessionUrl,
    required this.start,
    required this.end,
    required this.total,
    required this.contentType,
    required this.bytes,
  });

  final String sessionUrl;
  final int start;
  final int end;
  final int total;
  final String contentType;
  final Uint8List bytes;

  /// `bytes start-end/total`, which is what GCS expects on every chunk.
  String get contentRange => 'bytes $start-$end/$total';
}

/// What a transport reports back after a chunk lands.
final class FanWorkChunkAck {
  const FanWorkChunkAck({this.lastByteReceived, this.complete = false});

  /// `null` when the response carried no `Range` header.
  final int? lastByteReceived;

  /// `true` once the server signals the object is complete.
  final bool complete;
}

/// The whole object for a one-shot signed `PUT`.
///
/// This is not a [FanWorkUploadChunk]: a signed URL has no session, so there
/// is no `Content-Range` to send and no `308` to answer. What it does have is
/// a signature over the headers the server chose, and those have to come back
/// on the request verbatim.
final class FanWorkUploadObject {
  const FanWorkUploadObject({
    required this.url,
    required this.contentType,
    required this.contentLengthRange,
    required this.bytes,
  });

  final String url;
  final String contentType;

  /// The `x-goog-content-length-range` header the server signed into the URL
  /// (`1,<maxBytes>` in `fanWorksStorage.js`). A signed header that is absent
  /// from the request is a signature that does not match, so this must be
  /// echoed exactly — which is why it travels with the ticket's `maxBytes`
  /// rather than being invented here.
  final String? contentLengthRange;

  final Uint8List bytes;
}

/// Which wire protocol a ticket's `uploadUrl` speaks.
///
/// The server picks one when it mints the ticket: the document role gets a
/// resumable session URI, every image role gets a bounded one-shot signed
/// `PUT` (see `isDocumentRole` in `functions/src/fanWorksSchema.js`). The
/// client has to answer with the matching request shape, because neither URL
/// accepts the other's protocol.
enum FanWorkUploadProtocol {
  /// `Content-Range` slices, each answered with `308 Resume Incomplete`.
  resumableSession,

  /// One request carrying the whole object, signed headers, no ranges.
  signedPut,
}

/// The one operation this client needs from the network, isolated so the
/// chunking, progress, and cancellation logic can be tested without a socket.
abstract interface class FanWorkUploadTransport {
  Future<FanWorkChunkAck> sendChunk(
    FanWorkUploadChunk chunk, {
    Object? cancelKey,
  });

  /// Sends an entire object to a one-shot signed `PUT` URL.
  ///
  /// Throws a [Failure] for any non-2xx status, so the caller never has to
  /// interpret a status code itself.
  Future<void> sendObject(FanWorkUploadObject object, {Object? cancelKey});
}

/// Default transport: a real `PUT` against the signed session URI.
///
/// The transport deliberately knows nothing about Fan Works. It only has to
/// speak the GCS V4 resumable protocol, which is what makes it replaceable.
final class HttpFanWorkUploadTransport implements FanWorkUploadTransport {
  HttpFanWorkUploadTransport({http.Client? client, http.Client? ownedClient})
    : _client = client ?? ownedClient ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const _resumeIncomplete = 308;

  @override
  Future<FanWorkChunkAck> sendChunk(
    FanWorkUploadChunk chunk, {
    Object? cancelKey,
  }) async {
    final request = http.Request('PUT', Uri.parse(chunk.sessionUrl))
      ..headers['Content-Range'] = chunk.contentRange
      ..headers['Content-Type'] = chunk.contentType
      ..bodyBytes = chunk.bytes;

    final response = await _client.send(request).timeout(_timeout);
    final status = response.statusCode;
    // A resumable session answers 308 with a `Range` header for every chunk it
    // accepted. Anything in the 2xx range means the object is finished.
    if (status == _resumeIncomplete || (status >= 200 && status < 300)) {
      final range = response.headers['range'];
      return FanWorkChunkAck(
        lastByteReceived: _parseLastByte(range),
        complete: status != _resumeIncomplete,
      );
    }
    throw _failureFor(status, response.reasonPhrase);
  }

  static const _timeout = Duration(minutes: 5);

  @override
  Future<void> sendObject(
    FanWorkUploadObject object, {
    Object? cancelKey,
  }) async {
    final request = http.Request('PUT', Uri.parse(object.url))
      // The signature covers this header, so it has to be the exact MIME the
      // server signed, not whatever the picker reported.
      ..headers['Content-Type'] = object.contentType
      ..bodyBytes = object.bytes;
    final range = object.contentLengthRange;
    if (range != null && range.isNotEmpty) {
      request.headers['x-goog-content-length-range'] = range;
    }
    // Deliberately no `Content-Range`: that header belongs to the resumable
    // protocol, and a signed URL is not a session.
    final response = await _client.send(request).timeout(_timeout);
    // Drain before judging, so the connection can be reused rather than left
    // holding a body nobody reads.
    await response.stream.drain<void>();
    final status = response.statusCode;
    if (status >= 200 && status < 300) return;
    throw _failureFor(status, response.reasonPhrase);
  }

  /// `"bytes=0-1023"` -> `1024`, the count of bytes the server holds.
  static int? _parseLastByte(String? range) {
    if (range == null) return null;
    final match = RegExp(r'bytes=0-(\d+)').firstMatch(range.trim());
    final last = match?.group(1);
    if (last == null) return null;
    final parsed = int.tryParse(last);
    return parsed == null ? null : parsed + 1;
  }

  static Failure _failureFor(int status, String? reason) {
    return switch (status) {
      401 ||
      403 => const PermissionError('This upload is no longer authorized.'),
      400 || 413 => const ValidationError('That file cannot be uploaded here.'),
      404 => const NotFoundError('The upload session has expired.'),
      408 || 429 => const RateLimitedError('The upload is busy. Try again.'),
      _ => NetworkError(
        reason == null || reason.isEmpty
            ? 'The upload failed.'
            : 'The upload failed: $reason',
      ),
    };
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Uploads bytes to a signed, short-lived resumable session.
///
/// The server opens the session and hands back a URI in
/// `FanWorkUploadTicket.uploadUrl`. Uploading through that URI — rather than
/// through the storage SDK — is the security property that matters: a session
/// cannot mint a permanent `downloadToken`, so a Fan Work file can never be
/// shared as a permanent link after the fact.
final class FanWorkUploadClient {
  FanWorkUploadClient({
    FanWorkUploadTransport? transport,
    this.chunkSize = defaultChunkSize,
  }) : _transport = transport ?? HttpFanWorkUploadTransport();

  /// 8 MiB. Large enough that a 50 MB PDF is seven requests instead of
  /// hundreds, small enough that progress stays smooth on a phone.
  static const defaultChunkSize = 8 * 1024 * 1024;

  final FanWorkUploadTransport _transport;

  /// Overridable so tests can force many chunks.
  final int chunkSize;

  bool _cancelled = false;

  /// Cancels an in-flight upload. Safe to call from a widget teardown; the
  /// client refuses to start new chunks once it is set.
  ///
  /// One client instance drives one upload attempt. A retry is a fresh
  /// [upload] call on a fresh instance, which is what lets a retry start from a
  /// clean slate without this method having to reset anything.
  void cancel() => _cancelled = true;

  /// Uploads [bytes] to [sessionUrl].
  ///
  /// [protocol] selects the wire shape: [FanWorkUploadProtocol.resumableSession]
  /// for a session URI (a PDF), [FanWorkUploadProtocol.signedPut] for a
  /// one-shot signed URL (an image). [maxBytes] is only read for the signed
  /// PUT, where it rebuilds the length header the server signed into the URL.
  ///
  /// Returns the number of bytes the server acknowledged. A cancelled upload
  /// reports a [CancelledError] and leaves the session resumable, so the editor
  /// can retry the same ticket instead of starting a second upload.
  Future<Result<int>> upload({
    required String sessionUrl,
    required List<int> bytes,
    required String contentType,
    FanWorkUploadProgress? onProgress,
    FanWorkUploadProtocol protocol = FanWorkUploadProtocol.resumableSession,
    int maxBytes = 0,
  }) async {
    // Deliberately no `_cancelled = false` here: a cancel raised between the
    // caller starting an upload and the first chunk leaving (a widget torn down
    // mid-flight, say) must still take effect.
    if (_cancelled) return const FailureResult(CancelledError());
    if (bytes.isEmpty) {
      return const FailureResult(ValidationError('That file is empty.'));
    }
    if (sessionUrl.isEmpty) {
      return const FailureResult(
        UnavailableError('The upload could not be prepared. Try again.'),
      );
    }
    if (protocol == FanWorkUploadProtocol.signedPut) {
      return _uploadSignedPut(
        url: sessionUrl,
        bytes: bytes,
        contentType: contentType,
        maxBytes: maxBytes,
        onProgress: onProgress,
      );
    }
    final total = bytes.length;
    final view = Uint8List.fromList(bytes);
    final size = math.max(1, math.min(chunkSize, total));
    var acknowledged = 0;
    onProgress?.call(0);

    while (acknowledged < total) {
      if (_cancelled) return const FailureResult(CancelledError());
      final start = acknowledged;
      final end = math.min(start + size, total) - 1;
      final FanWorkChunkAck ack;
      try {
        ack = await _transport.sendChunk(
          FanWorkUploadChunk(
            sessionUrl: sessionUrl,
            start: start,
            end: end,
            total: total,
            contentType: contentType,
            bytes: Uint8List.sublistView(view, start, end + 1),
          ),
        );
      } on Failure catch (failure) {
        return FailureResult(failure);
      } catch (_) {
        return const FailureResult(NetworkError('The upload failed.'));
      }
      if (_cancelled) return const FailureResult(CancelledError());

      // The server's acknowledgement is authoritative: a truncated response
      // must not be mistaken for progress, or the next chunk would overwrite
      // bytes the server never received.
      final held = ack.lastByteReceived;
      if (held != null && held > acknowledged) acknowledged = held;
      if (ack.complete) {
        acknowledged = total;
        break;
      }
      if (acknowledged <= start) {
        // No forward movement means the session is stuck; looping would spin.
        return const FailureResult(
          NetworkError('The upload stalled. Try again.'),
        );
      }
      onProgress?.call((acknowledged / total).clamp(0.0, 1.0));
    }

    onProgress?.call(1);
    return Success(total);
  }

  /// The signed-PUT half of [upload]: one request, no ranges, no session.
  ///
  /// Everything that can fail is on that single request — a wrong header, an
  /// expired signature, a body over the signed ceiling — so there is nothing
  /// to resume and nothing to retry within this call. The editor retries by
  /// re-PUTting the same ticket, which lands on the same object path.
  Future<Result<int>> _uploadSignedPut({
    required String url,
    required List<int> bytes,
    required String contentType,
    required int maxBytes,
    FanWorkUploadProgress? onProgress,
  }) async {
    final total = bytes.length;
    onProgress?.call(0);
    try {
      await _transport.sendObject(
        FanWorkUploadObject(
          url: url,
          contentType: contentType,
          contentLengthRange: maxBytes > 0 ? '1,$maxBytes' : null,
          bytes: Uint8List.fromList(bytes),
        ),
      );
    } on Failure catch (failure) {
      return FailureResult(failure);
    } catch (_) {
      return const FailureResult(NetworkError('The upload failed.'));
    }
    // The bytes may be there and the caller still asked to stop; reporting the
    // cancel is what lets the editor offer a retry instead of confirming a
    // file the user walked away from.
    if (_cancelled) return const FailureResult(CancelledError());
    onProgress?.call(1);
    return Success(total);
  }

  void close() {
    final transport = _transport;
    if (transport is HttpFanWorkUploadTransport) transport.close();
  }
}
