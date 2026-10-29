import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';

/// Render a Mafia server log event into localized copy.
///
/// The server writes structured events (`{type, payload, …}`) alongside an
/// English `message`. The UI must never fall back to that message nor to the
/// raw `type` token (Master Spec 13.12 "عربي كامل"), so every known event type
/// is mapped here and an unrecognized one is dropped rather than shown as an
/// English code. [nameOf] resolves a player id to a display name.
String mafiaLogLine(
  AppStrings copy,
  Map<String, dynamic> event,
  String Function(String id) nameOf,
) {
  final payload = event['payload'] is Map
      ? Map<String, dynamic>.from(event['payload'] as Map)
      : const <String, dynamic>{};
  switch (event['type']) {
    case 'GameCreated':
      return copy.mafiaLogCreated;
    case 'GameStarting':
      return copy.mafiaLogStarting;
    case 'RolesAssigned':
      return copy.mafiaLogRolesAssigned;
    case 'MafiaStarted':
      return copy.mafiaLogStarted;
    case 'PhaseChanged':
      return copy.mafiaLogPhaseChanged(
        copy.mafiaPhaseLabel(_str(payload['to'])),
      );
    case 'PlayerKilled':
      return copy.mafiaLogNightKilled(
        nameOf(_str(payload['playerId'])),
        copy.mafiaRoleLabel(_str(payload['role'])),
      );
    case 'NightResolved':
      return copy.mafiaLogNight(
        _int(payload['nightNumber']),
        payload['deathOccurred'] == true,
      );
    case 'PlayerEliminated':
      return copy.mafiaLogEliminated(
        nameOf(_str(payload['playerId'])),
        copy.mafiaRoleLabel(_str(payload['role'])),
      );
    case 'VoteResolved':
      return copy.mafiaLogVoteResolved(_int(payload['dayNumber']));
    case 'VoteTie':
      final names = (payload['tiedIds'] as List<Object?>? ?? const <Object?>[])
          .map((id) => nameOf('$id'))
          .join(copy.listSeparator);
      return copy.mafiaLogVoteTie(names);
    case 'PlayerExecuted':
      return copy.mafiaLogExecuted(
        nameOf(_str(payload['playerId'])),
        copy.mafiaRoleLabel(_str(payload['role'])),
      );
    case 'GameFinished':
      return copy.mafiaLogFinished(_outcome(copy, _str(payload['winner'])));
    case 'Rewards':
      return copy.mafiaLogRewards;
    default:
      return '';
  }
}

String _outcome(AppStrings copy, String winner) => switch (winner) {
  'mafias' => copy.mafiaMafiaWon,
  'citizens' => copy.mafiaTownWon,
  _ => copy.mafiaGameEnded,
};

String _str(Object? value) => value is String ? value : '';

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

/// Resolve a Mafia [Failure] into user-facing copy for the active locale.
///
/// Mirrors the home/discovery mapping: the failure stays locale-neutral and the
/// screen never prints its English `message` (spec §1.4, §13.12).
String mafiaFailureMessage(AppStrings copy, Failure failure) {
  if (failure is NetworkError) return copy.mafiaOffline;
  if (failure is PermissionError) return copy.mafiaNotPermitted;
  if (failure is NotFoundError) return copy.mafiaGameGone;
  if (failure is RateLimitedError) return copy.mafiaRetryLater;
  if (failure is ValidationError) return copy.mafiaActionRejected;
  return copy.mafiaErrorGeneric;
}
