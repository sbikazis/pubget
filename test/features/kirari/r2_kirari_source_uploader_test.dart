import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubget/features/kirari/data/r2_kirari_source_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storagePath = 'kirari/alice/reel-1/source.mp4';

  Future<File> sourceFile() async {
    final directory = await Directory.systemTemp.createTemp('kirari-r2-');
    final file = File('${directory.path}/source.mp4');
    await file.writeAsBytes(List<int>.generate(16, (index) => index));
    return file;
  }

  R2KirariSourceUploader uploader(
    http.Client client,
    SharedPreferences prefs, {
    int chunkSize = 8,
  }) => R2KirariSourceUploader(
    workerUrl: 'https://media.example.test',
    uidProvider: () => 'alice',
    getIdToken: () async => 'firebase-token',
    client: client,
    preferences: prefs,
    chunkSize: chunkSize,
  );

  test(
    'creates a multipart session, uploads ordered parts and completes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final file = await sourceFile();
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer firebase-token');
        if (request.method == 'POST' &&
            request.url.path == '/kirari/multipart/reel-1') {
          expect(request.headers['x-kirari-size'], '16');
          expect(request.body, '{}');
          return http.Response(
            jsonEncode({'uploadId': 'upload-1', 'key': storagePath}),
            201,
          );
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/1')) {
          expect(request.bodyBytes, List<int>.generate(8, (index) => index));
          expect(request.headers['content-length'], '8');
          return http.Response(
            jsonEncode({'partNumber': 1, 'etag': 'etag-1'}),
            201,
          );
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/2')) {
          expect(
            request.bodyBytes,
            List<int>.generate(8, (index) => index + 8),
          );
          return http.Response(
            jsonEncode({'partNumber': 2, 'etag': 'etag-2'}),
            201,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/complete')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['parts'], [
            {'partNumber': 1, 'etag': 'etag-1'},
            {'partNumber': 2, 'etag': 'etag-2'},
          ]);
          return http.Response(
            jsonEncode({'key': storagePath, 'sizeBytes': 16}),
            201,
          );
        }
        throw StateError(
          'Unexpected R2 request: ${request.method} ${request.url.path}',
        );
      });

      final progress = <double>[];
      await uploader(client, prefs).upload(
        file: file,
        storagePath: storagePath,
        contentType: 'video/mp4',
        onProgress: progress.add,
      );

      expect(calls, [
        'POST /kirari/multipart/reel-1',
        'PUT /kirari/multipart/reel-1/upload-1/1',
        'PUT /kirari/multipart/reel-1/upload-1/2',
        'POST /kirari/multipart/reel-1/upload-1/complete',
      ]);
      expect(progress.last, 1);
      expect(
        prefs.getString('kirari_r2_multipart_session:$storagePath'),
        isNull,
      );
      await file.parent.delete(recursive: true);
      client.close();
    },
  );

  test(
    'resumes a persisted session at the next part after a restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final file = await sourceFile();
      final modified = await file.lastModified();
      final fingerprint =
          '${file.absolute.path}|16|${modified.millisecondsSinceEpoch}';
      await prefs.setString(
        'kirari_r2_multipart_session:$storagePath',
        jsonEncode({
          'uploadId': 'upload-old',
          'parts': [
            {'partNumber': 1, 'etag': 'etag-1'},
          ],
          'uploadedBytes': 8,
        }),
      );
      await prefs.setString(
        'kirari_r2_multipart_fingerprint:$storagePath',
        fingerprint,
      );

      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'PUT' && request.url.path.endsWith('/2')) {
          expect(
            request.bodyBytes,
            List<int>.generate(8, (index) => index + 8),
          );
          return http.Response(
            jsonEncode({'partNumber': 2, 'etag': 'etag-2'}),
            201,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/complete')) {
          return http.Response(
            jsonEncode({'key': storagePath, 'sizeBytes': 16}),
            201,
          );
        }
        throw StateError(
          'A resumed upload must not restart the session: ${request.url}',
        );
      });

      await uploader(client, prefs).upload(
        file: file,
        storagePath: storagePath,
        contentType: 'video/mp4',
        onProgress: (_) {},
      );

      expect(calls, [
        'PUT /kirari/multipart/reel-1/upload-old/2',
        'POST /kirari/multipart/reel-1/upload-old/complete',
      ]);
      await file.parent.delete(recursive: true);
      client.close();
    },
  );

  test('an expired Worker session restarts the upload exactly once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final file = await sourceFile();
    var creations = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/kirari/multipart/reel-1') {
        creations++;
        return http.Response(
          jsonEncode({'uploadId': 'upload-$creations', 'key': storagePath}),
          201,
        );
      }
      if (request.method == 'PUT' && request.url.path.endsWith('/1')) {
        if (request.url.path.contains('/upload-1/')) {
          return http.Response('', 404);
        }
        return http.Response(
          jsonEncode({'partNumber': 1, 'etag': 'etag-1'}),
          201,
        );
      }
      if (request.method == 'PUT' && request.url.path.endsWith('/2')) {
        return http.Response(
          jsonEncode({'partNumber': 2, 'etag': 'etag-2'}),
          201,
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        return http.Response(
          jsonEncode({'key': storagePath, 'sizeBytes': 16}),
          201,
        );
      }
      throw StateError(
        'Unexpected R2 request: ${request.method} ${request.url.path}',
      );
    });

    await uploader(client, prefs).upload(
      file: file,
      storagePath: storagePath,
      contentType: 'video/mp4',
      onProgress: (_) {},
    );

    expect(creations, 2);
    expect(prefs.getString('kirari_r2_multipart_session:$storagePath'), isNull);
    await file.parent.delete(recursive: true);
    client.close();
  });

  test(
    'abort releases the Worker session and clears local resume state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'kirari_r2_multipart_session:$storagePath',
        jsonEncode({
          'uploadId': 'upload-old',
          'parts': <dynamic>[],
          'uploadedBytes': 0,
        }),
      );
      await prefs.setString(
        'kirari_r2_multipart_fingerprint:$storagePath',
        'local-fingerprint',
      );
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer firebase-token');
        return http.Response('', 204);
      });

      await uploader(client, prefs).abort(storagePath);

      expect(calls, ['DELETE /kirari/multipart/reel-1/upload-old/abort']);
      expect(
        prefs.getString('kirari_r2_multipart_session:$storagePath'),
        isNull,
      );
      expect(
        prefs.getString('kirari_r2_multipart_fingerprint:$storagePath'),
        isNull,
      );
      client.close();
    },
  );
}
