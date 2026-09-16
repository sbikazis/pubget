import 'dart:math' show max;

import 'mafia_phase.dart';
import 'mafia_roles.dart';

/// Pure Mafia rules. The Functions engine is authoritative; this mirror
/// keeps Flutter unit tests and client validation aligned without leaking
/// hidden state or accepting client-provided outcomes.
///
/// Defaults (Pubget 1.0 does not specify exact counts):
/// - 4–16 players
/// - `mafiaCount = max(1, floor(n / 4))`
/// - Doctor at n ≥ 5, Detective at n ≥ 6
///
/// Tie-break (not specified by Pubget 1.0):
/// - Night kill: plurality of living Mafia; a tie means no kill.
/// - Day vote: plurality of living players; a tie means no elimination.
/// - Multiple Doctor protects: the lexicographically first target is used.
abstract final class MafiaLimits {
  static const minPlayers = 4;
  static const maxPlayers = 16;
  static const defaultNightSeconds = 45;
  static const defaultDaySeconds = 20;
  static const defaultDiscussionSeconds = 90;
  static const defaultVotingSeconds = 45;
}

final class MafiaRoleCounts {
  const MafiaRoleCounts({
    required this.mafiaCount,
    required this.detectiveCount,
    required this.doctorCount,
    required this.civilianCount,
  });

  final int mafiaCount;
  final int detectiveCount;
  final int doctorCount;
  final int civilianCount;

  int get total =>
      mafiaCount + detectiveCount + doctorCount + civilianCount;
}

final class MafiaNightResolution {
  const MafiaNightResolution({
    required this.tally,
    this.mafiaTargetId,
    this.protectedId,
    this.saved = false,
    this.eliminatedUserId,
  });

  final Map<String, int> tally;
  final String? mafiaTargetId;
  final String? protectedId;
  final bool saved;
  final String? eliminatedUserId;
}

final class MafiaVoteResolution {
  const MafiaVoteResolution({
    required this.tally,
    this.winnerId,
    this.tied = false,
  });

  final Map<String, int> tally;
  final String? winnerId;
  final bool tied;
}

abstract final class MafiaRules {
  static MafiaRoleCounts defaultRoleCounts(int playerCount) {
    final mafiaCount = max(1, playerCount ~/ 4);
    final doctorCount = playerCount >= 5 ? 1 : 0;
    final detectiveCount = playerCount >= 6 ? 1 : 0;
    final civilianCount =
        playerCount - mafiaCount - doctorCount - detectiveCount;
    return MafiaRoleCounts(
      mafiaCount: mafiaCount,
      detectiveCount: detectiveCount,
      doctorCount: doctorCount,
      civilianCount: civilianCount,
    );
  }

  static MafiaRoleCounts? resolveRoleCounts({
    required int playerCount,
    int? mafiaCount,
    int? detectiveCount,
    int? doctorCount,
  }) {
    if (playerCount < MafiaLimits.minPlayers ||
        playerCount > MafiaLimits.maxPlayers) {
      return null;
    }
    final auto = defaultRoleCounts(playerCount);
    final mafia = mafiaCount ?? auto.mafiaCount;
    final detective = detectiveCount ?? auto.detectiveCount;
    final doctor = doctorCount ?? auto.doctorCount;
    final civilian = playerCount - mafia - detective - doctor;
    if (mafia < 1 || civilian < 1 || detective < 0 || doctor < 0) {
      return null;
    }
    final counts = MafiaRoleCounts(
      mafiaCount: mafia,
      detectiveCount: detective,
      doctorCount: doctor,
      civilianCount: civilian,
    );
    if (counts.total != playerCount) return null;
    return counts;
  }

  /// [shuffle] receives the role deck. Production never uses this client-side
  /// for authoritative assignment; tests inject a deterministic shuffle.
  static Map<String, MafiaRole> assignRoles({
    required Iterable<String> userIds,
    required MafiaRoleCounts counts,
    List<MafiaRole> Function(List<MafiaRole> deck)? shuffle,
  }) {
    final ids = [...userIds]..sort();
    final deck = <MafiaRole>[
      ...List<MafiaRole>.filled(counts.mafiaCount, MafiaRole.mafia),
      ...List<MafiaRole>.filled(counts.detectiveCount, MafiaRole.detective),
      ...List<MafiaRole>.filled(counts.doctorCount, MafiaRole.doctor),
      ...List<MafiaRole>.filled(counts.civilianCount, MafiaRole.civilian),
    ];
    if (deck.length != ids.length) {
      throw StateError('Role deck does not match participant count.');
    }
    final shuffled = shuffle == null ? deck : shuffle(List<MafiaRole>.from(deck));
    return <String, MafiaRole>{
      for (var i = 0; i < ids.length; i++) ids[i]: shuffled[i],
    };
  }

  static List<String> livingIds({
    required Map<String, MafiaRole> roles,
    required Map<String, bool> alive,
  }) {
    return roles.keys.where((id) => alive[id] != false).toList(growable: false);
  }

  /// Town wins when no living Mafia remain. Mafia wins when living Mafia
  /// are no longer outnumbered (`mafiaCount >= townCount`).
  static String? checkWinner({
    required Map<String, MafiaRole> roles,
    required Map<String, bool> alive,
  }) {
    final living = livingIds(roles: roles, alive: alive);
    var mafiaCount = 0;
    var townCount = 0;
    for (final id in living) {
      if (roles[id] == MafiaRole.mafia) {
        mafiaCount += 1;
      } else {
        townCount += 1;
      }
    }
    if (mafiaCount == 0) return 'town';
    if (mafiaCount >= townCount) return 'mafia';
    return null;
  }

  static MafiaVoteResolution plurality({
    required Map<String, String> votesByActor,
    required Set<String> eligibleActors,
    required Set<String> eligibleTargets,
  }) {
    final tally = <String, int>{};
    for (final entry in votesByActor.entries) {
      if (!eligibleActors.contains(entry.key)) continue;
      if (!eligibleTargets.contains(entry.value)) continue;
      tally[entry.value] = (tally[entry.value] ?? 0) + 1;
    }
    var best = 0;
    final leaders = <String>[];
    for (final entry in tally.entries) {
      if (entry.value > best) {
        best = entry.value;
        leaders
          ..clear()
          ..add(entry.key);
      } else if (entry.value == best && best > 0) {
        leaders.add(entry.key);
      }
    }
    if (best == 0 || leaders.length != 1) {
      return MafiaVoteResolution(
        tally: tally,
        tied: leaders.length > 1,
      );
    }
    return MafiaVoteResolution(tally: tally, winnerId: leaders.first);
  }

  static MafiaNightResolution resolveNight({
    required Map<String, MafiaRole> roles,
    required Map<String, bool> alive,
    required Map<String, String> kills,
    String? protect,
  }) {
    final living = livingIds(roles: roles, alive: alive).toSet();
    final livingMafia = living
        .where((id) => roles[id] == MafiaRole.mafia)
        .toSet();
    final vote = plurality(
      votesByActor: kills,
      eligibleActors: livingMafia,
      eligibleTargets: living,
    );
    final protectedId = living.contains(protect) ? protect : null;
    final saved =
        vote.winnerId != null &&
        protectedId != null &&
        vote.winnerId == protectedId;
    return MafiaNightResolution(
      tally: vote.tally,
      mafiaTargetId: vote.winnerId,
      protectedId: protectedId,
      saved: saved,
      eliminatedUserId: saved ? null : vote.winnerId,
    );
  }

  static String? resolveProtectTarget(Iterable<String> protectIds) {
    final ids = protectIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return null;
    if (ids.length == 1) return ids.first;
    ids.sort();
    return ids.first;
  }

  static MafiaVoteResolution resolveVotes({
    required Map<String, MafiaRole> roles,
    required Map<String, bool> alive,
    required Map<String, String> votes,
  }) {
    final living = livingIds(roles: roles, alive: alive).toSet();
    return plurality(
      votesByActor: votes,
      eligibleActors: living,
      eligibleTargets: living,
    );
  }

  static bool canAct({
    required MafiaRole role,
    required MafiaPhase phase,
    required bool isAlive,
    required String actionType,
  }) {
    if (!isAlive || phase == MafiaPhase.finished) return false;
    if (actionType == 'mafia_vote') {
      return phase == MafiaPhase.voting;
    }
    if (phase != MafiaPhase.night) return false;
    return role.nightActionType == actionType && actionType.isNotEmpty;
  }
}
