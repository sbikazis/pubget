import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/data/anime_http_client.dart';

import 'anime_test_support.dart';

void main() {
  test('retries timeout then returns the successful response', () async {
    final inner = FakeAnimeHttpClient(
      responses: <String, AnimeHttpResponse>{
        '/v4/anime': const AnimeHttpResponse(
          statusCode: 200,
          body: '{"ok":true}',
        ),
      },
    )
      ..throwError = TimeoutException('timeout')
      ..failuresBeforeSuccess = 1;

    final client = ResilientAnimeHttpClient(
      inner: inner,
      minInterval: Duration.zero,
      delay: (_) async {},
      backoff: (_) => Duration.zero,
    );

    final response = await client.get(Uri.parse('https://example.test/v4/anime'));
    expect(response.statusCode, 200);
    expect(inner.calls.length, 2);
  });

  test('maps HTTP 429 to a rate-limit failure', () {
    final failure = mapAnimeHttpFailure(
      '429',
      statusCode: 429,
      retryAfter: const Duration(seconds: 2),
    );
    expect(failure, isA<Object>());
    expect(failure.message, contains('Too many requests'));
  });

  test('does not retry 404', () async {
    final inner = FakeAnimeHttpClient(
      responses: <String, AnimeHttpResponse>{
        '/missing': const AnimeHttpResponse(statusCode: 404, body: '{}'),
      },
    );
    final client = ResilientAnimeHttpClient(
      inner: inner,
      minInterval: Duration.zero,
      delay: (_) async {},
    );
    final response = await client.get(Uri.parse('https://example.test/missing'));
    expect(response.statusCode, 404);
    expect(inner.calls, hasLength(1));
  });

  test('retries 429 then succeeds and respects retry-after', () async {
    var attempt = 0;
    final delays = <Duration>[];
    final inner = _SequenceHttpClient();
    final client = ResilientAnimeHttpClient(
      inner: inner,
      minInterval: Duration.zero,
      delay: (duration) async => delays.add(duration),
      backoff: (_) => Duration.zero,
    );
    final response = await client.get(Uri.parse('https://example.test/v4/top'));
    expect(response.statusCode, 200);
    expect(delays, isNotEmpty);
    expect(attempt, 0);
  });

  test('interactive requests jump ahead of queued catalog fetches', () async {
    final inner = _HoldHttpClient();
    final client = ResilientAnimeHttpClient(
      inner: inner,
      minInterval: Duration.zero,
      delay: (_) async {},
    );
    final catalogA = client.get(
      Uri.parse('https://example.test/v4/seasons/now'),
    );
    await Future<void>.delayed(Duration.zero);
    final catalogB = client.get(
      Uri.parse('https://example.test/v4/top/anime'),
    );
    final search = client.get(
      Uri.parse('https://example.test/v4/anime'),
      priority: AnimeRequestPriority.interactive,
    );
    inner.releaseAll();
    await Future.wait(<Future<AnimeHttpResponse>>[catalogA, catalogB, search]);
    expect(inner.started, <String>[
      '/v4/seasons/now',
      '/v4/anime',
      '/v4/top/anime',
    ]);
  });
}

final class _SequenceHttpClient implements AnimeHttpClient {
  int _calls = 0;

  @override
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
    AnimeRequestPriority priority = AnimeRequestPriority.catalog,
  }) async {
    _calls++;
    if (_calls == 1) {
      return const AnimeHttpResponse(
        statusCode: 429,
        body: '{}',
        headers: <String, String>{'retry-after': '1'},
      );
    }
    return const AnimeHttpResponse(statusCode: 200, body: '{"ok":true}');
  }
}

final class _HoldHttpClient implements AnimeHttpClient {
  final started = <String>[];
  final Completer<void> _ready = Completer<void>();

  @override
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
    AnimeRequestPriority priority = AnimeRequestPriority.catalog,
  }) async {
    started.add(uri.path);
    await _ready.future;
    return const AnimeHttpResponse(statusCode: 200, body: '{}');
  }

  void releaseAll() {
    if (!_ready.isCompleted) _ready.complete();
  }
}
