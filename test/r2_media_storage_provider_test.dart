import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/r2_media_storage_provider.dart';

void main() {
  group('R2MediaStorageProvider conversation scope', () {
    test('sends scope identifiers with proxied uploads', () async {
      late String multipartBody;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/upload');
        expect(
          request.headers.entries
              .firstWhere((entry) => entry.key.toLowerCase() == 'authorization')
              .value,
          'Bearer test-token',
        );
        // MockClient normalizes streamed multipart requests to http.Request.
        // Inspect the encoded body rather than casting back to MultipartRequest.
        multipartBody = request.body;
        return http.Response(
          jsonEncode({'key': 'groups/g1/alice/file.jpg'}),
          201,
        );
      });
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev',
        idTokenProvider: () async => 'test-token',
        client: client,
      );

      final key = await provider.upload(
        ownerUid: 'alice',
        kind: MediaKind.image,
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        extension: 'jpg',
        scopeType: 'groups',
        scopeId: 'g1',
      );

      expect(key, 'groups/g1/alice/file.jpg');
      expect(multipartBody, contains('name="scopeType"'));
      expect(multipartBody, contains('groups'));
      expect(multipartBody, contains('name="scopeId"'));
      expect(multipartBody, contains('g1'));
      expect(multipartBody, contains('name="kind"'));
      expect(multipartBody, contains('image'));
    });

    test('resolves a conversation key using the signed-in identity', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'url': 'https://media.example.workers.dev/media/signed',
            'expiresAt': 123456,
          }),
          200,
        );
      });
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev/',
        idTokenProvider: () async => 'test-token',
        client: client,
      );

      final url = await provider.resolveUrl(
        'privateChats/5:alice3:bob/alice/file.m4a',
      );

      expect(url, 'https://media.example.workers.dev/media/signed');
      expect(requested.path, '/resolve');
      expect(
        requested.queryParameters['key'],
        'privateChats/5:alice3:bob/alice/file.m4a',
      );
    });

    test('presigned PUT 503 is an outage, not a lost connection', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://r2.example/upload',
              'key': 'images/alice/a.jpg',
              'headers': <String, String>{},
            }),
            200,
          );
        }
        expect(request.method, 'PUT');
        return http.Response('upstream unavailable', 503);
      });
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev',
        idTokenProvider: () async => 'test-token',
        client: client,
        directUploadMaxBytes: 1, // force the presigned PUT path
      );

      expect(
        () => provider.upload(
          ownerUid: 'alice',
          kind: MediaKind.image,
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
          extension: 'jpg',
        ),
        throwsA(isA<UnavailableError>()),
      );
    });

    test('presigned PUT 429 is rate limiting', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://r2.example/upload',
              'key': 'images/alice/a.jpg',
              'headers': <String, String>{},
            }),
            200,
          );
        }
        return http.Response('slow down', 429);
      });
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev',
        idTokenProvider: () async => 'test-token',
        client: client,
        directUploadMaxBytes: 1,
      );

      expect(
        () => provider.upload(
          ownerUid: 'alice',
          kind: MediaKind.image,
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
          extension: 'jpg',
        ),
        throwsA(isA<RateLimitedError>()),
      );
    });

    test('DELETE 5xx is classified through the shared mapper', () async {
      final client = MockClient(
        (_) async => http.Response('server error', 502),
      );
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev',
        idTokenProvider: () async => 'test-token',
        client: client,
      );

      expect(
        () => provider.delete('images/alice/a.jpg'),
        throwsA(isA<UnavailableError>()),
      );
    });

    test('resolveUrlWithExpiry exposes the Worker signature expiry', () async {
      final expires =
          DateTime.utc(2026, 11, 22, 12, 10).millisecondsSinceEpoch ~/ 1000;
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'url': 'https://media.example.workers.dev/media/signed',
            'expiresAt': expires,
          }),
          200,
        ),
      );
      final provider = R2MediaStorageProvider(
        workerUrl: 'https://media.example.workers.dev',
        idTokenProvider: () async => 'test-token',
        client: client,
      );

      final resolved = await provider.resolveUrlWithExpiry(
        'images/alice/a.jpg',
      );
      expect(resolved.url, 'https://media.example.workers.dev/media/signed');
      expect(resolved.expiresAt.toUtc(), DateTime.utc(2026, 11, 22, 12, 10));
    });
  });
}
