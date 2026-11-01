import 'failure.dart';

/// Classifies a thrown error into a [Failure]. It must be pure, because
/// [runWithRetry] calls it on every attempt to decide whether to retry.
typedef FailureMapper = Failure Function(Object error);

/// Default number of total attempts (initial try plus retries).
const int kDefaultMaxRetryAttempts = 3;

/// Bounded, jittered backoff steps in milliseconds (attempt 1, 2, 3, ...).
const List<int> _retryBackoffMs = <int>[300, 900, 2200];

/// Transient failures that are safe to retry automatically: connectivity,
/// backend hiccups, rate limiting, and transaction conflicts.
bool isTransientFailure(Failure failure) =>
    failure is NetworkError ||
    failure is TimeoutError ||
    failure is UnavailableError ||
    failure is RateLimitedError ||
    failure is TransactionConflictError;

/// Runs [action] and retries transient failures with bounded exponential
/// backoff and jitter. Non-transient failures surface immediately.
///
/// This is what turns a one-off `unavailable`/`internal` Firestore or callable
/// error into a successful action instead of an error banner, without ever
/// retrying a genuine validation or permission problem.
Future<T> runWithRetry<T>(
  Future<T> Function() action, {
  required FailureMapper mapError,
  int maxAttempts = kDefaultMaxRetryAttempts,
  Future<void> Function(Duration delay)? delay,
}) async {
  final wait = delay ?? Future<void>.delayed;
  var attempt = 0;
  while (true) {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      attempt += 1;
      if (attempt >= maxAttempts || !isTransientFailure(mapError(error))) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final base =
          _retryBackoffMs[(attempt - 1).clamp(0, _retryBackoffMs.length - 1)];
      final jitter = (base * 0.2 * ((attempt * 47) % 100) / 100).round();
      await wait(Duration(milliseconds: base + jitter));
    }
  }
}
