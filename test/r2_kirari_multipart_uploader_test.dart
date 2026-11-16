import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubget/features/kirari/data/r2_kirari_multipart_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uploads a source in R2 multipart parts and finalizes with ETags', () async {
    final directory = await Directory.systemTemp.createTemp('pubget-r2-kirari-');
    final file = File('${directory.path}/source.mp4');
    await file.writeAsBytes(Uint8List(9 * 1024 * 1024));
    final methods = <String>[];
    final uploadedParts = <int>[];
    final client = MockClient((request) async {
      methods.add('${request.method} ${request.url.path}');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      if (request.method == 'HEAD') return http.Response('', 404);
      if (request.method == 'POST' && request.url.path.endsWith('/reel-1')) {
        expect(request.headers['x-kirari-size'], (9 * 1024 * 1024).toString());
        return http.Response(jsonEncode({'uploadId': 'multipart-1'}), 201);
      }
      if (request.method == 'PUT') {
        final number = int.parse(request.url.path.split('/').last);
        uploadedParts.add(number);
        final body = (request as http.Request).bodyBytes;
        expect(body.length, number == 1 ? 8 * 1024 * 1024 : 1024 * 1024);
        return http.Response(jsonEncode({'partNumber': number, 'etag': 'etag-$number'}), 201);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/complete')) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['parts'], [
          {'partNumber': 1, 'etag': 'etag-1'},
          {'partNumber': 2, 'etag': 'etag-2'},
        ]);
        return http.Response(jsonEncode({'key': 'kirari/alice/reel-1/source.mp4'}), 201);
      }
      return http.Response('unexpected', 500);
    });
    final uploader = R2KirariMultipartUploader(
      workerUrl: 'https://pubget-media.example',
      uidProvider: () => 'alice',
      getIdToken: () async => 'firebase-token',
      client: client,
      preferences: await SharedPreferences.getInstance(),
    );
    final progress = <double>[];

    await uploader.upload(
      file: file,
      reelId: 'reel-1',
      onProgress: progress.add,
    );

    expect(uploadedParts, [1, 2]);
    expect(methods, contains('POST /kirari/multipart/reel-1/multipart-1/complete'));
    expect(progress.last, 1);
    await directory.delete(recursive: true);
  });

  test('uploads custom covers through the authenticated Worker route', () async {
    final directory = await Directory.systemTemp.createTemp('pubget-r2-cover-');
    final file = File('${directory.path}/cover.png');
    final pngBytes = Uint8List(2048);
    pngBytes.setRange(0, 8, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    await file.writeAsBytes(pngBytes);
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode({'key': 'kirari/alice/reel-1/cover-source.jpg'}), 201);
    });
    final uploader = R2KirariMultipartUploader(
      workerUrl: 'https://pubget-media.example',
      uidProvider: () => 'alice',
      getIdToken: () async => 'firebase-token',
      client: client,
      preferences: await SharedPreferences.getInstance(),
    );

    await uploader.uploadCover(file: file, reelId: 'reel-1');

    expect(sent.method, 'PUT');
    expect(sent.url.path, '/kirari/cover/reel-1');
    expect(sent.headers['authorization'], 'Bearer firebase-token');
    expect(sent.headers['content-type'], 'image/png');
    expect((sent.bodyBytes).length, 2048);
    await directory.delete(recursive: true);
  });

  test('does not retransmit an already completed identical R2 source', () async {
    final directory = await Directory.systemTemp.createTemp('pubget-r2-existing-');
    final file = File('${directory.path}/source.mp4');
    await file.writeAsBytes(Uint8List(1024));
    final modified = await file.lastModified();
    final fingerprint = sha256.convert(utf8.encode('${file.absolute.path}|1024|${modified.millisecondsSinceEpoch}')).toString();
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.method, 'HEAD');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response('', 200, headers: {
        'content-length': '1024',
        'x-kirari-fingerprint': fingerprint,
      });
    });
    final uploader = R2KirariMultipartUploader(
      workerUrl: 'https://pubget-media.example',
      uidProvider: () => 'alice',
      getIdToken: () async => 'firebase-token',
      client: client,
      preferences: await SharedPreferences.getInstance(),
    );
    var progress = 0.0;

    await uploader.upload(
      file: file,
      reelId: 'reel-existing',
      onProgress: (value) => progress = value,
    );

    expect(requests, 1);
    expect(progress, 1);
    await directory.delete(recursive: true);
  });

  test('resolves a published Kirari object only through the Worker', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer firebase-token');
      return http.Response(jsonEncode({'url': 'https://pubget-media.example/kirari/asset?signed=1'}), 200);
    });
    final uploader = R2KirariMultipartUploader(
      workerUrl: 'https://pubget-media.example/',
      uidProvider: () => 'alice',
      getIdToken: () async => 'firebase-token',
      client: client,
      preferences: await SharedPreferences.getInstance(),
    );

    final url = await uploader.resolveUrl('kirari-processed/alice/reel-1/540.mp4');

    expect(requested.path, '/kirari/resolve');
    expect(requested.queryParameters['key'], 'kirari-processed/alice/reel-1/540.mp4');
    expect(url, 'https://pubget-media.example/kirari/asset?signed=1');
  });
}
