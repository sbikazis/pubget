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

enum AnimeRequestPriority { interactive, catalog }

abstract interface class AnimeHttpClient {
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
    AnimeRequestPriority priority = AnimeRequestPriority.catalog,
  });
}

final class PackageAnimeHttpClient implements AnimeHttpClient {
  PackageAnimeHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
    AnimeRequestPriority priority = AnimeRequestPriority.catalog,
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
    this.minInterval = const Duration(milliseconds: 450),
    this.maxRetries = 3,
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

  final List<_QueuedAnimeRequest> _pending = <_QueuedAnimeRequest>[];
  var _running = false;
  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  static Duration _defaultBackoff(int attempt) =>
      Duration(milliseconds: 400 * (1 << (attempt - 1)));

  @override
  Future<AnimeHttpResponse> get(
    Uri uri, {
    Duration? timeout,
    AnimeRequestPriority priority = AnimeRequestPriority.catalog,
  }) {
    final completer = Completer<AnimeHttpResponse>();
    final job = _QueuedAnimeRequest(
      uri: uri,
      timeout: timeout ?? requestTimeout,
      priority: priority,
      completer: completer,
    );
    if (priority == AnimeRequestPriority.interactive) {
      final catalogIndex = _pending.indexWhere(
        (pending) => pending.priority == AnimeRequestPriority.catalog,
      );
      if (catalogIndex == -1) {
        _pending.add(job);
      } else {
        _pending.insert(catalogIndex, job);
      }
    } else {
      _pending.add(job);
    }
    unawaited(_drain());
    return completer.future;
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      try {
        await _gated(
          () => _send(job.uri, job.timeout, job.completer),
        );
      } catch (error, stack) {
        if (!job.completer.isCompleted) {
          job.completer.completeError(error, stack);
        }
      }
    }
    _running = false;
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
    final capped = retryAfter > const Duration(seconds: 8)
        ? const Duration(seconds: 8)
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

final class _QueuedAnimeRequest {
  const _QueuedAnimeRequest({
    required this.uri,
    required this.timeout,
    required this.priority,
    required this.completer,
  });

  final Uri uri;
  final Duration timeout;
  final AnimeRequestPriority priority;
  final Completer<AnimeHttpResponse> completer;
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
