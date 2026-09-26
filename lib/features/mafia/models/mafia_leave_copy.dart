import '../../../core/l10n/app_strings.dart';
import 'mafia_models.dart';

/// Confirmation copy that matches `leaveMafiaGame` / `leaveTransition`.
///
/// Whether the button appears is decided by [MafiaGame.canLeaveViaServer],
/// which mirrors the server's supported phases. This class only supplies the
/// wording, in the app's two official locales.
extension MafiaLeaveCopy on AppStrings {
  String get mafiaLeaveTitle => pick('Leave Mafia?', 'مغادرة المافيا؟');
  String get mafiaLeaveConfirm => pick('Leave', 'مغادرة');
  String get mafiaLeaveStay => pick('Stay', 'البقاء');

  /// The waiting room is not a survival phase: leaving it is free, and if the
  /// lobby then falls below the minimum it is cancelled rather than started
  /// short. Saying so up front is the difference between a warning and a
  /// promise.
  String get mafiaLeaveWaitingBody => pick(
    'Leaving the waiting room is free. If the lobby then has fewer than '
        'the minimum players, it is cancelled. Roles are not assigned yet.',
    'المغادرة من غرفة الانتظار مجانية. إذا انخفض عدد اللاعبين عن الحد '
        'الأدنى، ستُلغى اللعبة. لم تُوزَّع الأدوار بعد.',
  );

  String get mafiaLeaveStartingBody => pick(
    'If the lobby then has fewer than the minimum players, it is '
        'cancelled. Otherwise you leave and the start continues. Roles are '
        'not assigned yet.',
    'إذا انخفض عدد اللاعبين عن الحد الأدنى، ستُلغى اللعبة. وإلا فأنت '
        'تغادر ويستمر البدء. لم تُوزَّع الأدوار بعد.',
  );

  /// During play a leave is the same elimination as any other, so it has to be
  /// described as one: the player keeps their seat in the record, the role is
  /// revealed, and the town can win immediately.
  String get mafiaLeaveActiveBody => pick(
    'You will be marked eliminated: you lose your vote, speech, and '
        'ability. Your role is revealed and is not given to anyone else. The '
        'match continues, and if the remaining teams are unbalanced it can '
        'end immediately.',
    'سيُسجَّل إقصاؤك: تفقد التصويت والكلام والقدرة. يُكشف دورك ولا يُنقل '
        'إلى أحد غيرك. تستمر المباراة، وقد تنتهي فوراً إذا اختل توازن الفرق.',
  );

  String get mafiaLeaveUnsupportedBody =>
      pick('This phase cannot be left.', 'لا يمكن المغادرة في هذه المرحلة.');

  String mafiaLeaveBodyFor(String status) {
    if (status == 'WAITING') return mafiaLeaveWaitingBody;
    if (status == 'STARTING') return mafiaLeaveStartingBody;
    const active = <String>{
      'ROLE_REVEAL',
      'NIGHT',
      'DAY',
      'DISCUSSION',
      'VOTING',
      'VOTE_RESULT',
      'RESOLUTION',
    };
    if (active.contains(status)) return mafiaLeaveActiveBody;
    return mafiaLeaveUnsupportedBody;
  }
}
