import '../../../core/errors/failure.dart';

/// Stable failure codes stored on [ChatMessage.failureMessage] for localization.
abstract final class ChatFailureCodes {
  static const network = 'chat_network';
  static const permission = 'chat_permission';
  static const notFound = 'chat_not_found';
  static const validation = 'chat_validation';
  static const unknown = 'chat_unknown';
}

/// Transient transport/backend failures that must auto-retry.
bool isTransientChatFailure(Failure failure) {
  return failure is NetworkError ||
      failure is TimeoutError ||
      failure is UnavailableError ||
      failure is RateLimitedError ||
      failure is TransactionConflictError;
}

String chatFailureCode(Failure failure) {
  if (failure is PermissionError) return ChatFailureCodes.permission;
  if (failure is NotFoundError) return ChatFailureCodes.notFound;
  if (failure is ValidationError) return ChatFailureCodes.validation;
  if (isTransientChatFailure(failure)) return ChatFailureCodes.network;
  return ChatFailureCodes.unknown;
}

/// Bounded exponential backoff with light jitter for automatic send retries.
Duration chatSendBackoffDelay(int attempt) {
  const steps = <int>[800, 2000, 4000, 8000, 15000, 30000, 60000];
  final index = attempt.clamp(0, steps.length - 1);
  final baseMs = steps[index];
  final jitter = (baseMs * 0.15 * ((attempt % 5) / 5)).round();
  return Duration(milliseconds: baseMs + jitter);
}

const int kChatSendMaxAggressiveRetries = 8;
