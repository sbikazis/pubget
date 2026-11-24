import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/legacy_media_resolver.dart';
import 'package:pubget/core/media/media_url_cache.dart';

void main() {
  test('resolver sends the bare object path to the callable', () async {
    final calls = <String>[];
    final resolver = LegacyMediaResolver(
      cache: MediaUrlCache(),
      call: (data) async {
        calls.add(data['path'] as String);
        return <dynamic, dynamic>{
          'url': 'https://storage.example/signed.jpg',
          'expiresAt': 1_700_000_600,
        };
      },
    );

    final resolved = await resolver.resolve(
      'https://firebasestorage.googleapis.com/v0/b/pubget-aaf27.firebasestorage.app/o/'
      'images%2Falice%2Favatar.jpg?alt=media&token=permanent',
    );

    expect(resolved, isNull,
        reason: 'a full URL is not a valid object path; callers strip it first');
    expect(calls, isEmpty);
  });

  test('resolver caches short-lived URLs and refreshes near expiry', () async {
    var now = DateTime(2026, 1, 1, 12);
    var calls = 0;
    final cache = MediaUrlCache(
      safetyMargin: const Duration(seconds: 30),
      clock: () => now,
    );
    final resolver = LegacyMediaResolver(
      cache: cache,
      call: (data) async {
        calls++;
        return <dynamic, dynamic>{
          'url': 'https://storage.example/signed-$calls.jpg',
          'expiresAt': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
        };
      },
    );

    final first = await resolver.resolve('images/alice/avatar.jpg');
    final second = await resolver.resolve('images/alice/avatar.jpg');
    expect(first?.url, 'https://storage.example/signed-1.jpg');
    expect(second?.url, first?.url);
    expect(calls, 1);

    now = now.add(const Duration(minutes: 5, seconds: 1));
    final refreshed = await resolver.resolve('images/alice/avatar.jpg');
    expect(refreshed?.url, 'https://storage.example/signed-2.jpg');
    expect(calls, 2);
  });

  test('resolver fails closed on errors and malformed payloads', () async {
    final failing = LegacyMediaResolver(
      cache: MediaUrlCache(),
      call: (data) async => throw StateError('permission denied'),
    );
    expect(await failing.resolve('images/alice/avatar.jpg'), isNull);

    final malformed = LegacyMediaResolver(
      cache: MediaUrlCache(),
      call: (data) async => <dynamic, dynamic>{
        'url': 'http://insecure.example/image.jpg',
        'expiresAt': 'not-a-number',
      },
    );
    expect(await malformed.resolve('images/alice/avatar.jpg'), isNull);

    var called = false;
    final guarded = LegacyMediaResolver(
      cache: MediaUrlCache(),
      call: (data) async {
        called = true;
        return <dynamic, dynamic>{};
      },
    );
    expect(await guarded.resolve('   '), isNull);
    expect(await guarded.resolve('a' * 1025), isNull);
    expect(called, isFalse);
  });
}
