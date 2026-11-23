import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/media/media_upload_service.dart';

FirebaseException _storageException(String code) => FirebaseException(
  plugin: 'firebase_storage',
  code: code,
  message: 'server responded with $code',
);

void main() {
  group('mapMediaException transient classification', () {
    test('unknown, internal and deadline-exceeded are service outages', () {
      for (final code in <String>['unknown', 'internal', 'deadline-exceeded']) {
        final failure = mapMediaException(_storageException(code));
        expect(
          failure,
          isA<UnavailableError>(),
          reason: '$code must not masquerade as an offline device',
        );
        expect(failure.message, isNot(contains('connection')));
      }
    });

    test('a true transport failure stays a NetworkError', () {
      expect(
        mapMediaException(_storageException('network-request-failed')),
        isA<NetworkError>(),
      );
      expect(
        mapMediaException(http.ClientException('Connection closed')),
        isA<NetworkError>(),
      );
    });

    test('timeouts, quota and permissions keep their own types', () {
      expect(
        mapMediaException(const TimeoutException('late')),
        isA<TimeoutError>(),
      );
      expect(
        mapMediaException(_storageException('quota-exceeded')),
        isA<RateLimitedError>(),
      );
      expect(
        mapMediaException(_storageException('unauthenticated')),
        isA<PermissionError>(),
      );
    });
  });
}
