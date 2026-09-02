sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class NetworkError extends Failure {
  const NetworkError([super.message = 'A network error occurred.']);
}

final class PermissionError extends Failure {
  const PermissionError([super.message = 'Permission was denied.']);
}

final class NotFoundError extends Failure {
  const NotFoundError([
    super.message = 'The requested resource was not found.',
  ]);
}

final class ValidationError extends Failure {
  const ValidationError([super.message = 'The supplied data is invalid.']);
}

final class CancelledError extends Failure {
  const CancelledError([super.message = 'That action was cancelled.']);
}

final class UnknownError extends Failure {
  const UnknownError([super.message = 'An unexpected error occurred.']);
}

final class TimeoutError extends Failure {
  const TimeoutError([
    super.message = 'The request timed out. Please try again.',
  ]);
}

final class RateLimitedError extends Failure {
  const RateLimitedError([
    super.message = 'Too many requests. Please wait a moment and try again.',
    this.retryAfter,
  ]);

  final Duration? retryAfter;
}

final class UnavailableError extends Failure {
  const UnavailableError([
    super.message = 'The catalog is temporarily unavailable. Please try again.',
  ]);
}

final class MalformedDataError extends Failure {
  const MalformedDataError([
    super.message = 'Anime data could not be read. Please try again.',
  ]);
}
