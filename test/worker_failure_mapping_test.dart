import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/firebase_failure_mapper.dart';
import 'package:pubget/core/errors/http_status_failure.dart';

final class _WorkerFailure implements HttpStatusFailure {
  const _WorkerFailure(this.statusCode, this.message);

  @override
  final int statusCode;

  @override
  final String message;
}

void main() {
  test('a Worker 503 is a backend outage, never a lost connection', () {
    final failure = mapFirebaseFailure(
      const _WorkerFailure(503, 'Group service is not configured.'),
    );
    expect(failure, isA<UnavailableError>());
    expect(failure.message, isNot(contains('connection')));
  });

  test('Worker status codes keep their honest failure types', () {
    expect(mapFirebaseFailure(const _WorkerFailure(401, 'Sign in again')),
        isA<PermissionError>());
    expect(mapFirebaseFailure(const _WorkerFailure(429, 'Slow down')),
        isA<RateLimitedError>());
    expect(mapFirebaseFailure(const _WorkerFailure(404, 'Gone')),
        isA<NotFoundError>());
    expect(mapFirebaseFailure(const _WorkerFailure(400, 'Invalid')),
        isA<ValidationError>());
  });
}
