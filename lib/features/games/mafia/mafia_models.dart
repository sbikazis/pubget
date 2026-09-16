import 'package:cloud_firestore/cloud_firestore.dart';

import 'mafia_phase.dart';
import 'mafia_roles.dart';

/// Public Mafia slice stored on `games/{id}.mafia`. Safe for participants.
class MafiaPublicState {
  const MafiaPublicState({
    required this.phase,
    this.phaseStartedAt,
    this.phaseEndsAt,
    this.roundNumber = 1,
    this.deadUserIds = const <String>[],
    this.lastNight,
    this.lastVote,
    this.winner,
  });

  final MafiaPhase phase;
  final DateTime? phaseStartedAt;
  final DateTime? phaseEndsAt;
  final int roundNumber;
  final List<String> deadUserIds;
  final Map<String, Object?>? lastNight;
  final Map<String, Object?>? lastVote;
  final String? winner;

  factory MafiaPublicState.fromMap(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) {
      return const MafiaPublicState(phase: MafiaPhase.setup);
    }
    return MafiaPublicState(
      phase: MafiaPhase.parse('${raw['phase'] ?? 'setup'}'),
      phaseStartedAt: _asDate(raw['phaseStartedAt']),
      phaseEndsAt: _asDate(raw['phaseEndsAt']),
      roundNumber: (raw['roundNumber'] as num?)?.toInt() ?? 1,
      deadUserIds: ((raw['deadUserIds'] as List<dynamic>?) ?? const [])
          .map((e) => '$e')
          .toList(growable: false),
      lastNight: raw['lastNight'] is Map
          ? Map<String, Object?>.from(raw['lastNight'] as Map)
          : null,
      lastVote: raw['lastVote'] is Map
          ? Map<String, Object?>.from(raw['lastVote'] as Map)
          : null,
      winner: raw['winner']?.toString(),
    );
  }

  Duration? remaining(DateTime now) {
    final ends = phaseEndsAt;
    if (ends == null) return null;
    final left = ends.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Player-private document `games/{id}/private/{uid}`.
class MafiaPrivateState {
  const MafiaPrivateState({
    required this.role,
    this.teammates = const <String>[],
    this.investigation,
    this.submittedNightAction = false,
    this.nightActionRound,
    this.voteTargetId,
    this.voteRound,
  });

  final MafiaRole role;
  final List<String> teammates;
  final Map<String, Object?>? investigation;
  final bool submittedNightAction;
  final int? nightActionRound;
  final String? voteTargetId;
  final int? voteRound;

  bool get isMafia => role == MafiaRole.mafia;

  String? get investigationTargetId => investigation?['targetId']?.toString();

  bool? get investigationIsMafia {
    final value = investigation?['isMafia'];
    if (value is bool) return value;
    return null;
  }

  factory MafiaPrivateState.fromMap(Map<String, Object?> raw) {
    return MafiaPrivateState(
      role: MafiaRole.parse('${raw['role'] ?? 'civilian'}'),
      teammates: ((raw['teammates'] as List<dynamic>?) ?? const [])
          .map((e) => '$e')
          .toList(growable: false),
      investigation: raw['investigation'] is Map
          ? Map<String, Object?>.from(raw['investigation'] as Map)
          : null,
      submittedNightAction: raw['submittedNightAction'] == true,
      nightActionRound: (raw['nightActionRound'] as num?)?.toInt(),
      voteTargetId: raw['voteTargetId']?.toString(),
      voteRound: (raw['voteRound'] as num?)?.toInt(),
    );
  }
}

class MafiaResult {
  const MafiaResult({
    this.winner,
    this.roles = const <String, String>{},
    this.roundNumber = 1,
  });

  final String? winner;
  final Map<String, String> roles;
  final int roundNumber;

  factory MafiaResult.fromSummary(Map<String, Object?>? summary) {
    if (summary == null) return const MafiaResult();
    final rolesRaw = summary['roles'];
    return MafiaResult(
      winner: summary['winner']?.toString(),
      roundNumber: (summary['roundNumber'] as num?)?.toInt() ?? 1,
      roles: rolesRaw is Map
          ? rolesRaw.map((k, v) => MapEntry('$k', '$v'))
          : const <String, String>{},
    );
  }
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic)?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
