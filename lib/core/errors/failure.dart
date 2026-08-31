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

final class UnknownError extends Failure {
  const UnknownError([super.message = 'An unexpected error occurred.']);
}
