enum UsernameStatusCause { empty, invalid, taken, serverError }

/// Result of a server-side availability + short-reservation check
/// (spec §3.2 instant check while typing).
final class UsernameStatus {
  const UsernameStatus({
    required this.available,
    required this.normalized,
    this.cause,
  });

  const UsernameStatus.available(String normalized) : this(available: true, normalized: normalized);

  const UsernameStatus.unavailable(this.cause)
    : available = false,
      normalized = '';

  const UsernameStatus.checking()
    : available = false,
      normalized = '',
      cause = null;

  /// `true` when the username is free and can be claimed server-side.
  final bool available;

  /// Lowercased canonical form, echoed back by the server.
  final String normalized;

  /// Why the username is not available (null while available/checking).
  final UsernameStatusCause? cause;

  bool get isChecking => available == false && cause == null;
}