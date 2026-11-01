import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import 'failure.dart';

/// A locale-neutral sentence used when no domain-specific copy is supplied.
const String _genericMessage = 'Something went wrong. Please try again.';

/// Maps any platform error into the shared [Failure] taxonomy.
///
/// This is the single place that knows how to translate raw Firebase/Firestore
/// codes — including the ones that used to leak to users as `internal`,
/// `unavailable`, `aborted`, or a raw `[cloud_firestore/...]` string.
///
/// [message] lets a domain supply its own user-facing sentence (for example the
/// daily-upload quota copy). When it is omitted a safe generic sentence is used;
/// raw backend text is never surfaced.
Failure mapFirebaseFailure(Object error, {String? message}) {
  if (error is Failure) return error;
  if (error is FirebaseException) {
    return _mapFirebaseCode(error.code, message);
  }
  if (error is FormatException) {
    return MalformedDataError(message ?? 'We could not read that response.');
  }
  if (error is TimeoutException) {
    return TimeoutError(message ?? 'The request timed out. Please try again.');
  }
  if (error is StateError) {
    return NotFoundError(message ?? 'The requested resource was not found.');
  }
  return UnknownError(message ?? _genericMessage);
}

Failure _mapFirebaseCode(String code, String? message) {
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
    case 'network-error':
      return NetworkError(message ?? 'Check your connection and try again.');
    // Backend hiccups and write-stream conflicts. These are transient, so they
    // map to a retryable failure instead of a dead end.
    case 'internal':
    case 'unknown':
    case 'aborted':
    case 'data-loss':
      return UnavailableError(
        message ?? 'Something went wrong on our side. Please try again.',
      );
    case 'cancelled':
    case 'canceled':
      return CancelledError(message ?? 'That action was cancelled.');
    case 'resource-exhausted':
    case 'quota-exceeded':
    case 'too-many-requests':
      return RateLimitedError(
        message ?? 'Too many requests. Please wait a moment and try again.',
      );
    case 'unauthenticated':
      return PermissionError(message ?? 'Please sign in again to continue.');
    case 'permission-denied':
    case 'unauthorized':
    case 'operation-not-allowed':
      return PermissionError(message ?? 'You are not allowed to do that.');
    case 'not-found':
      return NotFoundError(message ?? 'The requested resource was not found.');
    case 'already-exists':
    case 'email-already-in-use':
      return ValidationError(message ?? 'That already exists.');
    case 'failed-precondition':
    case 'invalid-argument':
    case 'out-of-range':
      return ValidationError(message ?? 'That request could not be completed.');
    default:
      return UnknownError(message ?? _genericMessage);
  }
}
