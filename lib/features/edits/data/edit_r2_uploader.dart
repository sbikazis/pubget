import 'dart:async';
import 'edit_r2_upload_source.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/edit_models.dart';

http.Client? _activeEditUploadClient;

const String _workerBaseUrl = 'https://pubget-media.pubget.workers.dev';

Future<void> uploadEditVideoToR2({
  required String editId,
  required EditUploadSource source,
  required String contentType,
  void Function(double progress)? onProgress,
}) async {
  if (contentType != 'video/mp4') {
    throw ArgumentError.value(contentType, 'contentType', 'Only MP4 is supported.');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Authentication required.');
  final token = await user.getIdToken();
  if (token == null || token.isEmpty) throw StateError('Authentication token unavailable.');

  final (length, body) = await prepareEditR2UploadSource(source);
  if (length <= 0 || length > 100 * 1024 * 1024) {
    throw ArgumentError('The video must be between 1 byte and 100 MB.');
  }

  final client = http.Client();
  _activeEditUploadClient = client;
  try {
    final request = http.StreamedRequest(
      'PUT',
      Uri.parse('$_workerBaseUrl/edits/upload/${Uri.encodeComponent(editId)}'),
    )..contentLength = length;
    request.headers.addAll({
      'authorization': 'Bearer $token',
      'content-type': 'video/mp4',
    });
    var transferred = 0;
    final monitoredBody = body.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        transferred += chunk.length;
        onProgress?.call((transferred / length).clamp(0.0, 1.0).toDouble());
        sink.add(chunk);
      },
    ));
    await request.sink.addStream(monitoredBody);
    await request.sink.close();
    final response = await client.send(request);
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 201) {
      throw HttpException(
        'Reel upload failed (${response.statusCode}): ${(responseBody.length > 240 ? responseBody.substring(0, 240) : responseBody)}',
      );
    }
  } finally {
    if (identical(_activeEditUploadClient, client)) _activeEditUploadClient = null;
    client.close();
  }
}

Future<void> cancelEditVideoUpload() async {
  // Closing the active client interrupts the stream. The caller then invokes
  // the owner-checked deleteEdit callable, which marks the document deleting
  // before removing any R2 objects.
  _activeEditUploadClient?.close();
  _activeEditUploadClient = null;
}
