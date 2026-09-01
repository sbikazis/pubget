import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

final class AnimeHttpResponse {
  const AnimeHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  Duration? get retryAfter {
    final raw = headers['retry-after'] ?? headers['Retry-After'];
    if (raw == null || raw.isEmpty) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}

abstract interface class AnimeHttpClient {
  Future<AnimeHttpResponse> get(Uri uri, {Duration? timeout});
}

final class PackageAnimeHttpClient implements AnimeHttpClient {
  PackageAnimeHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
  }) async {
    final response = await _client
        .get(uri, headers: const <String, String>{'Accept': 'application/json'})
        .timeout(timeout ?? const Duration(seconds: 10));
    return AnimeHttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }
}

/// Serializes outbound requests, respects Retry-After, and retries
/// transient failures with a short bounded backoff.
final class ResilientAnimeHttpClient implements AnimeHttpClient {
  ResilientAnimeHttpClient({
    required AnimeHttpClient inner,
    this.minInterval = const Duration(milliseconds: 350),
    this.maxRetries = 2,
    this.requestTimeout = const Duration(seconds: 10),
    Duration Function(int attempt)? backoff,
    Future<void> Function(Duration delay)? delay,
  }) : _inner = inner,
       _backoff = backoff ?? _defaultBackoff,
       _delay = delay ?? Future<void>.delayed;

  final AnimeHttpClient _inner;
  final Duration minInterval;
  final int maxRetries;
  final Duration requestTimeout;
  final Duration Function(int attempt) _backoff;
  final Future<void> Function(Duration delay) _delay;

  Future<void> _queue = Future<void>.value();
  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  static Duration _defaultBackoff(int attempt) =>
      Duration(milliseconds: 400 * (1 << (attempt - 1)));

  @override
  Future<AnimeHttpResponse> get(Uri uri, {Duration? timeout}) {
    final completer = Completer<AnimeHttpResponse>();
    _queue = _queue
        .catchError((_) {})
        .then(
          (_) => _gated(
            () => _send(uri, timeout ?? requestTimeout, completer),
          ),
        )
        .catchError((Object error, StackTrace stack) {
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
        });
    return completer.future;
  }

  Future<void> _gated(Future<void> Function() send) async {
    final wait = _nextSlot.difference(DateTime.now());
    if (wait > Duration.zero && minInterval > Duration.zero) {
      await _delay(wait);
    }
    _nextSlot = DateTime.now().add(minInterval);
    await send();
  }

  Future<void> _send(
    Uri uri,
    Duration timeout,
    Completer<AnimeHttpResponse> completer,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _inner.get(uri, timeout: timeout);
        if (_shouldRetryStatus(response.statusCode) && attempt < maxRetries) {
          await _delay(_retryDelay(attempt + 1, response.retryAfter));
          continue;
        }
        completer.complete(response);
        return;
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt >= maxRetries) break;
        await _delay(_backoff(attempt + 1));
      } on http.ClientException catch (error) {
        lastError = error;
        if (attempt >= maxRetries) break;
        await _delay(_backoff(attempt + 1));
      } catch (error) {
        lastError = error;
        if (attempt >= maxRetries) break;
        await _delay(_backoff(attempt + 1));
      }
    }
    if (!completer.isCompleted) {
      completer.completeError(
        lastError ?? TimeoutException('Anime request timed out', timeout),
      );
    }
  }

  bool _shouldRetryStatus(int status) =>
      status == 408 ||
      status == 429 ||
      status == 500 ||
      status == 502 ||
      status == 503 ||
      status == 504;

  Duration _retryDelay(int attempt, Duration? retryAfter) {
    final backoff = _backoff(attempt);
    if (retryAfter == null) return backoff;
    final capped = retryAfter > const Duration(seconds: 5)
        ? const Duration(seconds: 5)
        : retryAfter;
    return capped > backoff ? capped : backoff;
  }
}

Failure mapAnimeHttpFailure(Object error, {int? statusCode, Duration? retryAfter}) {
  if (statusCode == 429) {
    return RateLimitedError(
      'Too many requests. Please wait a moment and try again.',
      retryAfter,
    );
  }
  if (statusCode == 401 || statusCode == 403) {
    return const PermissionError('Anime catalog access was denied.');
  }
  if (statusCode == 404) {
    return const NotFoundError('This anime could not be found.');
  }
  if (statusCode == 400 || statusCode == 422) {
    return const ValidationError('That anime request was not valid.');
  }
  if (statusCode != null && statusCode >= 500) {
    return const UnavailableError();
  }
  if (error is TimeoutException) {
    return const TimeoutError();
  }
  if (error is http.ClientException) {
    return const NetworkError(AnimeNetworkMessages.offline);
  }
  if (error is FormatException || error is TypeError) {
    return const MalformedDataError();
  }
  return const UnknownError('Unable to load anime right now.');
}

abstract final class AnimeNetworkMessages {
  static const offline =
      'Unable to load anime right now. Please check your connection and try again.';
}

Result<T> animeHttpFailure<T>(Object error, {int? statusCode, Duration? retryAfter}) {
  return FailureResult<T>(
    mapAnimeHttpFailure(error, statusCode: statusCode, retryAfter: retryAfter),
  );
}

Map<String, dynamic> decodeAnimeJsonObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Expected a JSON object.');
}
