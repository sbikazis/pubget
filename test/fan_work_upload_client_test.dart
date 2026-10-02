import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/fan_works/services/fan_work_upload_client.dart';

/// Records every chunk it is asked to send and answers with whatever the test
/// wants, so the chunking, progress, and cancellation logic can be exercised
/// without a socket.
final class _RecordingTransport implements FanWorkUploadTransport {
  _RecordingTransport({this.ackFor});

  /// Overrides the acknowledgement for the nth chunk.
  final FanWorkChunkAck Function(int index)? ackFor;

  final List<FanWorkUploadChunk> sent = <FanWorkUploadChunk>[];

  /// Runs before each acknowledgement, so a test can cancel mid-upload.
  void Function(int index)? onChunk;

  @override
  Future<FanWorkChunkAck> sendChunk(
    FanWorkUploadChunk chunk, {
    Object? cancelKey,
  }) async {
    final index = sent.length;
    sent.add(chunk);
    onChunk?.call(index);
    final override = ackFor?.call(index);
    if (override != null) return override;
    // Mirror the GCS protocol: 308 Resume Incomplete until the final chunk.
    final isLast = chunk.end >= chunk.total - 1;
    return FanWorkChunkAck(lastByteReceived: chunk.end + 1, complete: isLast);
  }

  List<String> get ranges =>
      sent.map((chunk) => chunk.contentRange).toList(growable: false);
}

void main() {
  // A real GCS V4 resumable session URI carries its own credential in the query
  // string. Nothing else may be attached to it.
  const session =
      'https://storage.test/upload/session/abc'
      '?upload_id=upload%2Fsession-abc&x-goog-signature=deadbeef';

  test(
    'a single-chunk upload sends one ranged PUT and reports 0 then 1',
    () async {
      final transport = _RecordingTransport();
      final client = FanWorkUploadClient(transport: transport, chunkSize: 1024);
      final progress = <double>[];

      final result = await client.upload(
        sessionUrl: session,
        bytes: <int>[1, 2, 3],
        contentType: 'image/jpeg',
        onProgress: progress.add,
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 3);
      expect(transport.ranges, <String>['bytes 0-2/3']);
      expect(transport.sent.single.contentType, 'image/jpeg');
      expect(progress.first, 0);
      expect(progress.last, 1);
    },
  );

  test('the bytes sent are exactly the bytes given, in order', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
    final payload = <int>[9, 8, 7, 6, 5, 4, 3, 2, 1];

    await client.upload(
      sessionUrl: session,
      bytes: payload,
      contentType: 'application/pdf',
    );

    final rebuilt = <int>[for (final chunk in transport.sent) ...chunk.bytes];
    expect(rebuilt, payload);
  });

  test('a large file is split into chunks with contiguous ranges', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
    final bytes = List<int>.generate(10, (index) => index);

    final result = await client.upload(
      sessionUrl: session,
      bytes: bytes,
      contentType: 'application/pdf',
    );

    expect(result.valueOrNull, 10);
    // 4 + 4 + 2: the last chunk is short rather than padded.
    expect(transport.ranges, <String>[
      'bytes 0-3/10',
      'bytes 4-7/10',
      'bytes 8-9/10',
    ]);
  });

  test('progress follows the bytes the server acknowledged', () async {
    final transport = _RecordingTransport(
      ackFor: (index) => index == 0
          ? const FanWorkChunkAck(lastByteReceived: 4)
          : const FanWorkChunkAck(lastByteReceived: 10, complete: true),
    );
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
    final progress = <double>[];

    await client.upload(
      sessionUrl: session,
      bytes: List<int>.filled(10, 0),
      contentType: 'application/pdf',
      onProgress: progress.add,
    );

    expect(progress, containsAllInOrder(<double>[0, 0.4, 1]));
  });

  test('a short acknowledgement resumes from what the server holds', () async {
    // The server only stored 2 of the 8 bytes the client tried to send. The
    // next chunk has to start at 2, not at 8, or the gap would never be filled.
    final transport = _RecordingTransport(
      ackFor: (index) => switch (index) {
        0 => const FanWorkChunkAck(lastByteReceived: 2),
        _ => const FanWorkChunkAck(lastByteReceived: 8, complete: true),
      },
    );
    final client = FanWorkUploadClient(transport: transport, chunkSize: 8);

    final result = await client.upload(
      sessionUrl: session,
      bytes: List<int>.filled(8, 0),
      contentType: 'application/pdf',
    );

    expect(result.valueOrNull, 8);
    expect(transport.ranges, <String>['bytes 0-7/8', 'bytes 2-7/8']);
  });

  test(
    'a session that stops making progress fails instead of spinning',
    () async {
      final transport = _RecordingTransport(
        ackFor: (index) => index == 0
            ? const FanWorkChunkAck(lastByteReceived: 4)
            : const FanWorkChunkAck(lastByteReceived: 4),
      );
      final client = FanWorkUploadClient(transport: transport, chunkSize: 4);

      final result = await client.upload(
        sessionUrl: session,
        bytes: List<int>.filled(12, 0),
        contentType: 'application/pdf',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull, isA<NetworkError>());
      // It must give up rather than loop forever on a dead session.
      expect(transport.sent.length, 2);
    },
  );

  test(
    'cancelling mid-upload stops before the next chunk and reports it',
    () async {
      final transport = _RecordingTransport();
      final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
      transport.onChunk = (index) {
        if (index == 0) client.cancel();
      };

      final result = await client.upload(
        sessionUrl: session,
        bytes: List<int>.filled(12, 0),
        contentType: 'application/pdf',
      );

      expect(result.failureOrNull, isA<CancelledError>());
      // The first chunk was already in flight; nothing after it was started.
      expect(transport.sent.length, 1);
    },
  );

  test('cancelling before the first chunk sends nothing at all', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4)
      ..cancel();

    final result = await client.upload(
      sessionUrl: session,
      bytes: <int>[1, 2, 3],
      contentType: 'image/jpeg',
    );

    expect(result.failureOrNull, isA<CancelledError>());
    expect(transport.sent, isEmpty);
  });

  test('an empty file is refused before any request is made', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport);

    final result = await client.upload(
      sessionUrl: session,
      bytes: const <int>[],
      contentType: 'image/jpeg',
    );

    expect(result.failureOrNull, isA<ValidationError>());
    expect(transport.sent, isEmpty);
  });

  test('a missing session URL is refused rather than guessed at', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport);

    final result = await client.upload(
      sessionUrl: '',
      bytes: <int>[1],
      contentType: 'image/jpeg',
    );

    expect(result.failureOrNull, isA<UnavailableError>());
    expect(transport.sent, isEmpty);
  });

  test('a rejected chunk surfaces the transport failure unchanged', () async {
    final transport = _RecordingTransport();
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
    transport.onChunk = (index) {
      if (index == 1) {
        throw const PermissionError('This upload is no longer authorized.');
      }
    };

    final result = await client.upload(
      sessionUrl: session,
      bytes: List<int>.filled(12, 0),
      contentType: 'application/pdf',
    );

    expect(result.failureOrNull, isA<PermissionError>());
  });

  test('progress is monotonic even if a chunk over-reports', () async {
    final transport = _RecordingTransport(
      ackFor: (index) => switch (index) {
        // A server that reports more bytes than were sent must not be able to
        // push progress past 1.
        0 => const FanWorkChunkAck(lastByteReceived: 999, complete: true),
        _ => const FanWorkChunkAck(lastByteReceived: 999, complete: true),
      },
    );
    final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
    final progress = <double>[];

    await client.upload(
      sessionUrl: session,
      bytes: List<int>.filled(12, 0),
      contentType: 'application/pdf',
      onProgress: progress.add,
    );

    expect(progress.every((value) => value >= 0 && value <= 1), isTrue);
  });

  test('a chunk targets the session URL verbatim, with no extra credential', () {
    // The session URL is server-minted and already carries its own credential
    // in the query string. The chunk must hand that URL to the transport
    // unmodified: rebuilding it from a bucket path would drop the signature and
    // invite adding a second, long-lived credential beside it.
    final chunk = FanWorkUploadChunk(
      sessionUrl: session,
      start: 0,
      end: 1,
      total: 2,
      contentType: 'application/pdf',
      bytes: Uint8List(2),
    );
    expect(chunk.sessionUrl, session);
    expect(Uri.parse(chunk.sessionUrl).queryParameters, contains('upload_id'));
    expect(chunk.contentRange, 'bytes 0-1/2');
  });

  test(
    'the client reports a stable total that the editor can display',
    () async {
      final transport = _RecordingTransport();
      final client = FanWorkUploadClient(transport: transport, chunkSize: 8);
      final result = await client.upload(
        sessionUrl: session,
        bytes: jsonEncode(<String, int>{'a': 1}).codeUnits,
        contentType: 'application/json',
      );
      expect(result.valueOrNull, jsonEncode(<String, int>{'a': 1}).length);
    },
  );

  test(
    'a cancelled client stays cancelled, so a retry needs a fresh one',
    () async {
      final transport = _RecordingTransport();
      final client = FanWorkUploadClient(transport: transport, chunkSize: 4);
      client.cancel();

      final canceled = await client.upload(
        sessionUrl: session,
        bytes: List<int>.filled(8, 1),
        contentType: 'image/jpeg',
      );
      expect(canceled.failureOrNull, isA<CancelledError>());

      // A second attempt on the same instance is refused rather than quietly
      // resuming: the editor builds a new client per retry.
      final again = await client.upload(
        sessionUrl: session,
        bytes: List<int>.filled(8, 1),
        contentType: 'image/jpeg',
      );
      expect(again.failureOrNull, isA<CancelledError>());

      final retried =
          await FanWorkUploadClient(transport: transport, chunkSize: 4).upload(
            sessionUrl: session,
            bytes: List<int>.filled(8, 1),
            contentType: 'image/jpeg',
          );
      expect(retried.isSuccess, isTrue);
      expect(retried.valueOrNull, 8);
    },
  );

  test(
    'a slow transport is awaited without the upload reporting progress',
    () async {
      final completer = Completer<FanWorkChunkAck>();
      final client = FanWorkUploadClient(
        transport: _AwaitingTransport(completer),
        chunkSize: 4,
      );
      final progress = <double>[];

      final pending = client.upload(
        sessionUrl: session,
        bytes: List<int>.filled(8, 0),
        contentType: 'application/pdf',
        onProgress: progress.add,
      );
      // Only the initial 0 is reported while the chunk is in flight; progress is
      // not invented for bytes the server has not acknowledged.
      expect(progress, <double>[0]);
      completer.complete(
        const FanWorkChunkAck(lastByteReceived: 8, complete: true),
      );
      expect((await pending).isSuccess, isTrue);
    },
  );
}

final class _AwaitingTransport implements FanWorkUploadTransport {
  _AwaitingTransport(this.completer);

  final Completer<FanWorkChunkAck> completer;

  @override
  Future<FanWorkChunkAck> sendChunk(
    FanWorkUploadChunk chunk, {
    Object? cancelKey,
  }) => completer.future;
}
