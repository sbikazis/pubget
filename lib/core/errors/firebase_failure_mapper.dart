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
  // dart:io cannot be imported here (this mapper also compiles for web), so a
  // raw socket failure is recognised by type name. It is the only non-Firebase
  // error that genuinely proves lost connectivity.
  if (error.runtimeType.toString() == 'SocketException') {
    return NetworkError(message ?? 'Check your connection and try again.');
  }
  if (error is StateError) {
    return NotFoundError(message ?? 'The requested resource was not found.');
  }
  return UnknownError(message ?? _genericMessage);
}

Failure _mapFirebaseCode(String code, String? message) {
  switch (code) {
    case 'network-request-failed':
    case 'network-error':
      // The SDK itself reports a broken transport: this is a real connectivity
      // failure and the only case that may show an offline state.
      return NetworkError(message ?? 'Check your connection and try again.');
    // Firestore/Storage use `unavailable` and `deadline-exceeded` for backend
    // pressure, cold starts and write-stream conflicts. They are NOT evidence
    // that the device lost internet. Mapping them to NetworkError used to make
    // the whole app claim "no connection" while Firebase was still reachable.
    case 'unavailable':
    case 'deadline-exceeded':
    case 'internal':
    case 'unknown':
    case 'aborted':
    case 'data-loss':
      return UnavailableError(
        message ?? 'The service is temporarily unavailable. Please try again.',
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
