import 'game_errors.dart';
import 'games_schema_v2.dart';

abstract final class GamesStateMachineV2 {
  static const transitions =
      <GameLifecycleStatusV2, Set<GameLifecycleStatusV2>>{
        GameLifecycleStatusV2.created: {
          GameLifecycleStatusV2.waiting,
          GameLifecycleStatusV2.cancelled,
        },
        GameLifecycleStatusV2.waiting: {
          GameLifecycleStatusV2.starting,
          GameLifecycleStatusV2.cancelled,
        },
        GameLifecycleStatusV2.starting: {
          GameLifecycleStatusV2.inProgress,
          GameLifecycleStatusV2.cancelled,
        },
        GameLifecycleStatusV2.inProgress: {
          GameLifecycleStatusV2.completed,
          GameLifecycleStatusV2.cancelled,
        },
        GameLifecycleStatusV2.completed: {},
        GameLifecycleStatusV2.cancelled: {},
      };

  static bool canTransition(
    GameLifecycleStatusV2 from,
    GameLifecycleStatusV2 to,
  ) => transitions[from]?.contains(to) ?? false;

  static void assertTransition(
    GameLifecycleStatusV2 from,
    GameLifecycleStatusV2 to,
  ) {
    if (!canTransition(from, to)) {
      throw const GameException(
        GameErrorCode.invalidTransition,
        'Invalid game lifecycle transition.',
      );
    }
  }

  static void assertCommand(GameSessionV2 session, GameCommandRequest request) {
    if (request.gameId != session.id) {
      throw const GameException(
        GameErrorCode.invalidAction,
        'Command game does not match session.',
      );
    }
    if (request.expectedVersion != session.version) {
      throw const GameException(
        GameErrorCode.invalidAction,
        'Game state is stale; refresh and retry.',
      );
    }
    if (request.requestId.trim().isEmpty) {
      throw const GameException(
        GameErrorCode.invalidAction,
        'requestId is required.',
      );
    }
  }
}
