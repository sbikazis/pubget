import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/identity/identity_worker_client.dart';
import 'package:pubget/features/social/repositories/firebase_profile_repository.dart';
import 'package:pubget/features/social/repositories/profile_repository.dart';

void main() {
  test('avatar key is sent in the profile patch', () {
    const update = ProfileUpdate(
      avatarUrl: 'images/user-1/avatar.jpg',
      bio: 'Updated',
    );

    expect(update.toMap(), <String, dynamic>{
      'bio': 'Updated',
      'avatarUrl': 'images/user-1/avatar.jpg',
    });
  });

  test('worker 5xx is unavailable, never a false offline state', () {
    for (final status in <int>[500, 503]) {
      final failure = mapIdentityWorkerFailure(
        IdentityWorkerException(status, 'backend failed'),
        'Could not save your profile photo.',
      );
      expect(failure, isA<UnavailableError>(), reason: 'status $status');
      expect(failure.message, 'Could not save your profile photo.');
    }
  });

  test('worker status mapping keeps precise domain failures', () {
    expect(
      mapIdentityWorkerFailure(
        const IdentityWorkerException(400, 'invalid profile'),
        'message',
      ),
      isA<ValidationError>(),
    );
    expect(
      mapIdentityWorkerFailure(
        const IdentityWorkerException(403, 'forbidden'),
        'message',
      ),
      isA<PermissionError>(),
    );
    expect(
      mapIdentityWorkerFailure(
        const IdentityWorkerException(404, 'missing'),
        'message',
      ),
      isA<NotFoundError>(),
    );
    expect(
      mapIdentityWorkerFailure(
        const IdentityWorkerException(429, 'slow down'),
        'message',
      ),
      isA<RateLimitedError>(),
    );
  });

  test('only a real transport failure becomes NetworkError', () {
    final failure = mapIdentityWorkerFailure(
      const SocketException('connection lost'),
      'Could not save your profile photo.',
    );
    expect(failure, isA<NetworkError>());
  });
}
