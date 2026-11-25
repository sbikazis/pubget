import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:pubget/core/api/core_read_worker_client.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/home/repositories/discovery_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpCoreReadWorkerClient', () {
    test('sends Firebase token and JSON payload to the Worker', () async {
      Request? captured;
      final client = HttpCoreReadWorkerClient(
        tokenProvider: () async => 'test-token',
        workerUrl: 'https://worker.example',
        httpClient: MockClient((request) async {
          captured = request;
          return Response(jsonEncode({'ok': true}), 200);
        }),
      );

      final result = await client.post('/core/discovery', {'section': 'groups'});

      expect(result, {'ok': true});
      expect(captured!.url.toString(), 'https://worker.example/core/discovery');
      expect(captured!.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(captured!.body), {'section': 'groups'});
    });

    test('maps backend failures to typed HTTP status failures', () async {
      final client = HttpCoreReadWorkerClient(
        tokenProvider: () async => 'test-token',
        httpClient: MockClient((_) async {
          return Response(jsonEncode({'error': 'Core read failed.'}), 503);
        }),
      );

      expect(
        () => client.post('/core/economy'),
        throwsA(
          isA<CoreReadWorkerException>()
              .having((error) => error.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('reports missing Firebase session as 401 without a request', () async {
      var called = false;
      final client = HttpCoreReadWorkerClient(
        tokenProvider: () async => null,
        httpClient: MockClient((_) async {
          called = true;
          return Response('{}', 200);
        }),
      );

      expect(
        () => client.post('/core/economy'),
        throwsA(
          isA<CoreReadWorkerException>()
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
      expect(called, isFalse);
    });
  });

  group('core read failure classification', () {
    test('backend outages are unavailable, not offline', () {
      expect(
        discoveryFailureFrom(const CoreReadWorkerException(503, 'Core read failed.')),
        isA<UnavailableError>(),
      );
    });

    test('expired Firebase sessions are permission failures', () {
      expect(
        discoveryFailureFrom(const CoreReadWorkerException(401, 'Sign in.')),
        isA<PermissionError>(),
      );
    });
  });
}
