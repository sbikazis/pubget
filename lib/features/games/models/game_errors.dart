import '../../../core/errors/failure.dart';

/// Named game-domain errors. Mapped onto the existing [Failure] hierarchy
/// so repositories stay compatible with Result/Error handling.
enum GameErrorCode {
  notFound,
  alreadyStarted,
  notJoinable,
  notParticipant,
  invalidAction,
  invalidTransition,
  alreadyCompleted,
  duplicateAction,
  unimplementedType,
}

final class GameException implements Exception {
  const GameException(this.code, [this.message = '']);

  final GameErrorCode code;
  final String message;

  Failure toFailure() {
    final text = message.isEmpty ? code.name : message;
    return switch (code) {
      GameErrorCode.notFound => NotFoundError(text),
      GameErrorCode.notParticipant => PermissionError(text),
      _ => ValidationError(text),
    };
  }

  @override
  String toString() => 'GameException($code, $message)';
}
