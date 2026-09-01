import 'game_errors.dart';
import 'game_models.dart';

/// Client-side mirror of the server game lifecycle. Server state is
/// authoritative; this only validates UI input and keeps tests aligned.
abstract final class GameLifecycle {
  static const allowed = <GameStatus, Set<GameStatus>>{
    GameStatus.draft: {GameStatus.waiting, GameStatus.cancelled},
    GameStatus.waiting: {GameStatus.active, GameStatus.cancelled},
    GameStatus.active: {
      GameStatus.paused,
      GameStatus.completed,
      GameStatus.cancelled,
    },
    GameStatus.paused: {GameStatus.active, GameStatus.cancelled},
    GameStatus.completed: <GameStatus>{},
    GameStatus.cancelled: <GameStatus>{},
  };

  static const terminal = <GameStatus>{
    GameStatus.completed,
    GameStatus.cancelled,
  };

  static bool canTransition(GameStatus from, GameStatus to) =>
      allowed[from]?.contains(to) ?? false;

  static bool isTerminal(GameStatus status) => terminal.contains(status);

  static void assertTransition(GameStatus from, GameStatus to) {
    if (!canTransition(from, to)) {
      throw GameException(
        isTerminal(from) && from == GameStatus.completed
            ? GameErrorCode.alreadyCompleted
            : GameErrorCode.invalidTransition,
        'Cannot move a game from ${from.name} to ${to.name}.',
      );
    }
  }
}

abstract final class GameValidation {
  static String? draft(GameDraft draft) {
    if (draft.title.trim().isEmpty) return 'A title is required.';
    if (draft.groupId == null || draft.groupId!.trim().isEmpty) {
      return 'Games must belong to a group.';
    }
    if (draft.configuration.minPlayers < 1) {
      return 'A game needs at least one player.';
    }
    if (draft.configuration.maxPlayers < draft.configuration.minPlayers) {
      return 'maxPlayers must be greater than or equal to minPlayers.';
    }
    if (draft.type == GameType.mafia && draft.configuration.minPlayers < 4) {
      return 'Mafia requires at least 4 players.';
    }
    return null;
  }

  static String? action({
    required String gameId,
    required String playerId,
    required String actionType,
    required Map<String, dynamic> payload,
    String? clientActionId,
  }) {
    if (gameId.trim().isEmpty) return 'gameId is required.';
    if (playerId.trim().isEmpty) return 'playerId is required.';
    if (actionType.trim().isEmpty || actionType.trim().length > 64) {
      return 'actionType is invalid.';
    }
    if (clientActionId != null &&
        (clientActionId.trim().isEmpty || clientActionId.length > 128)) {
      return 'clientActionId is invalid.';
    }
    // Payload is intentionally opaque at this layer.
    return null;
  }
}
