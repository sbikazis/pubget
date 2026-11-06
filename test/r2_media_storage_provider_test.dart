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
        return http.Response(jsonEncode({'key': 'groups/g1/alice/file.jpg'}), 201);
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

      final url = await provider.resolveUrl('privateChats/5:alice3:bob/alice/file.m4a');

      expect(url, 'https://media.example.workers.dev/media/signed');
      expect(requested.path, '/resolve');
      expect(
        requested.queryParameters['key'],
        'privateChats/5:alice3:bob/alice/file.m4a',
      );
    });
  });
}
