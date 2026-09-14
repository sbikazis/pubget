/// Confirmation copy that matches `leaveMafiaGame` / `leaveTransition`.
///
/// WAITING, GAME_OVER, and CANCELLED are `unsupported` on the server.
/// Do not invent lobby-leave or role-reassignment behavior.
abstract final class MafiaLeaveCopy {
  static const leave = 'Leave game';
  static const confirm = 'Leave';
  static const stay = 'Stay';
  static const title = 'Leave Mafia?';

  static const _active = <String>{
    'ROLE_REVEAL', 'NIGHT', 'DAY', 'DISCUSSION', 'VOTING', 'VOTE_RESULT',
    'RESOLUTION',
  };

  static bool canLeave(String status) {
    return status == 'STARTING' || _active.contains(status);
  }

  static String bodyFor(String status) {
    if (status == 'STARTING') {
      return 'If the lobby then has fewer than the minimum players, it is '
          'cancelled. Otherwise you leave and the start continues. Roles '
          'are not assigned yet.';
    }
    if (_active.contains(status)) {
      return 'You will be marked eliminated: you lose your vote, speech, and '
          'ability. Your role is not given to anyone else. The match '
          'continues, and if the remaining teams are unbalanced it can end '
          'immediately.';
    }
    return 'This phase cannot be left.';
  }
}