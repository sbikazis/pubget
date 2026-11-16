import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  late final int length;
  late final Stream<List<int>> body;
  if (source.path != null) {
    final file = File(source.path!);
    length = await file.length();
    body = file.openRead();
  } else if (source.bytes != null) {
    final bytes = Uint8List.fromList(source.bytes!);
    length = bytes.length;
    body = Stream<List<int>>.value(bytes);
  } else {
    throw ArgumentError('An upload source is required.');
  }
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

Future<void> cancelEditVideoUpload(String editId) async {
  _activeEditUploadClient?.close();
  _activeEditUploadClient = null;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final token = await user.getIdToken();
  if (token == null || token.isEmpty) return;
  final response = await http.delete(
    Uri.parse('$_workerBaseUrl/edits/upload/\${Uri.encodeComponent(editId)}'),
    headers: {'authorization': 'Bearer $token'},
  );
  if (response.statusCode != 204 && response.statusCode != 404) {
    throw HttpException('Could not cancel Reel upload (\${response.statusCode}).');
  }
}
