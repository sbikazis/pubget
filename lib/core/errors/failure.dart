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

final class InsufficientFundsError extends Failure {
  const InsufficientFundsError([
    super.message = 'You do not have enough coins.',
  ]);
}

final class AlreadyOwnedError extends Failure {
  const AlreadyOwnedError([super.message = 'You already own this item.']);
}

final class NotEligibleError extends Failure {
  const NotEligibleError([
    super.message = 'You are not eligible for this action.',
  ]);
}

final class CooldownActiveError extends Failure {
  const CooldownActiveError([
    super.message = 'Please wait before trying that again.',
  ]);
}

final class PremiumRequiredError extends Failure {
  const PremiumRequiredError([
    super.message = 'Premium is required for this item.',
  ]);
}

final class ItemUnavailableError extends Failure {
  const ItemUnavailableError([
    super.message = 'This item is not available.',
  ]);
}

final class TransactionConflictError extends Failure {
  const TransactionConflictError([
    super.message = 'That request conflicted with another one. Try again.',
  ]);
}
