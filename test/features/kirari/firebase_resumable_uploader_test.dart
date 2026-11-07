import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubget/features/kirari/data/firebase_resumable_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseResumableUploader', () {
    test('parses committed byte ranges safely', () {
      expect(FirebaseResumableUploader.nextOffsetFromRange(null), 0);
      expect(FirebaseResumableUploader.nextOffsetFromRange('bytes=0-4095'), 4096);
      expect(
        () => FirebaseResumableUploader.nextOffsetFromRange('bytes=4-4095'),
        throwsFormatException,
      );
    });

    test('resumes from the server committed offset after app restart', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final directory = await Directory.systemTemp.createTemp('kirari-resume-');
      final file = File('${directory.path}/source.mp4');
      await file.writeAsBytes(List<int>.generate(16, (index) => index));
      final modified = await file.lastModified();
      const storagePath = 'kirari/alice/reel-1/source.mp4';
      const sessionUrl = 'https://storage.example.test/session/1';
      final fingerprint = '${file.absolute.path}|16|${modified.millisecondsSinceEpoch}';
      await preferences.setString('kirari_resumable_session:$storagePath', sessionUrl);
      await preferences.setString('kirari_resumable_fingerprint:$storagePath', fingerprint);

      final ranges = <String>[];
      final client = MockClient((request) async {
        final range = request.headers['content-range'] ?? '';
        ranges.add(range);
        if (range == 'bytes */16') {
          return http.Response('', 308, headers: {'range': 'bytes=0-3'});
        }
        if (range == 'bytes 4-11/16') {
          expect(request.bodyBytes, List<int>.generate(8, (index) => index + 4));
          return http.Response('', 308, headers: {'range': 'bytes=0-11'});
        }
        if (range == 'bytes 12-15/16') {
          expect(request.bodyBytes, [12, 13, 14, 15]);
          return http.Response('', 201);
        }
        throw StateError('Unexpected resumable request: $range');
      });

      final uploader = FirebaseResumableUploader(
        bucket: 'pubget-aaf27.appspot.com',
        uidProvider: () => 'alice',
        getIdToken: () async => 'firebase-token',
        getAppCheckToken: () async => 'app-check-token',
        client: client,
        preferences: preferences,
        chunkSize: 8,
      );
      final progress = <double>[];
      await uploader.upload(
        file: file,
        storagePath: storagePath,
        contentType: 'video/mp4',
        onProgress: progress.add,
      );

      expect(ranges, ['bytes */16', 'bytes 4-11/16', 'bytes 12-15/16']);
      expect(progress.last, 1);
      expect(preferences.getString('kirari_resumable_session:$storagePath'), isNull);
      await directory.delete(recursive: true);
      client.close();
    });
  });
}
