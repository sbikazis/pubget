import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/legacy_media_resolver.dart';
import 'package:pubget/core/media/media_reference.dart';
import 'package:pubget/core/media/media_url_cache.dart';

void main() {
  LegacyMediaResolver fakeResolver(List<String> calls) => LegacyMediaResolver(
        cache: MediaUrlCache(),
        call: (data) async {
          calls.add(data['path'] as String);
          return <dynamic, dynamic>{
            'url': 'https://signed.example/legacy.jpg',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 10))
                .millisecondsSinceEpoch ~/ 1000,
          };
        },
      );

  test('unrelated HTTPS links are returned untouched', () async {
    final calls = <String>[];
    final url = await resolveMediaDownloadUrl(
      'https://cdn.example/posters/a.jpg',
      cache: MediaUrlCache(),
      legacyResolver: fakeResolver(calls),
    );
    expect(url, 'https://cdn.example/posters/a.jpg');
    expect(calls, isEmpty);
  });

  test('a legacy Firebase link never reuses its permanent token', () async {
    final calls = <String>[];
    const legacy =
        'https://firebasestorage.googleapis.com/v0/b/pubget-aaf27.firebasestorage.app/o/'
        'users%2Falice%2Favatar.jpg?alt=media&token=permanent';

    final url = await resolveMediaDownloadUrl(
      legacy,
      cache: MediaUrlCache(),
      legacyResolver: fakeResolver(calls),
    );

    expect(url, 'https://signed.example/legacy.jpg');
    expect(url, isNot(contains('token=')));
    expect(calls, <String>['users/alice/avatar.jpg']);
  });

  test('an unauthorized legacy object fails closed', () async {
    final resolver = LegacyMediaResolver(
      cache: MediaUrlCache(),
      call: (data) async => throw StateError('permission-denied'),
    );
    expect(
      await resolveMediaDownloadUrl(
        'users/bob/avatar.jpg',
        cache: MediaUrlCache(),
        legacyResolver: resolver,
      ),
      isNull,
    );
  });
}
