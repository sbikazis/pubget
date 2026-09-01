/// Mafia-specific phase. Distinct from generic [GameStatus].
enum MafiaPhase {
  setup,
  night,
  day,
  discussion,
  voting,
  resolution,
  finished;

  static MafiaPhase parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'setup':
        return MafiaPhase.setup;
      case 'night':
        return MafiaPhase.night;
      case 'day':
        return MafiaPhase.day;
      case 'discussion':
        return MafiaPhase.discussion;
      case 'voting':
        return MafiaPhase.voting;
      case 'resolution':
        return MafiaPhase.resolution;
      case 'finished':
        return MafiaPhase.finished;
      default:
        throw FormatException('Unknown Mafia phase: $raw');
    }
  }

  bool get isNightActionPhase => this == MafiaPhase.night;

  bool get isVotingPhase => this == MafiaPhase.voting;

  bool get isTerminal => this == MafiaPhase.finished;
}

/// Valid Mafia phase edges. `resolution` is an internal hop resolved
/// server-side in the same transaction as night/vote resolution.
const Map<MafiaPhase, Set<MafiaPhase>> kMafiaPhaseTransitions =
    <MafiaPhase, Set<MafiaPhase>>{
  MafiaPhase.setup: {MafiaPhase.night},
  MafiaPhase.night: {MafiaPhase.day, MafiaPhase.finished, MafiaPhase.resolution},
  MafiaPhase.day: {MafiaPhase.discussion},
  MafiaPhase.discussion: {MafiaPhase.voting},
  MafiaPhase.voting: {
    MafiaPhase.night,
    MafiaPhase.finished,
    MafiaPhase.resolution,
  },
  MafiaPhase.resolution: {MafiaPhase.night, MafiaPhase.finished},
  MafiaPhase.finished: {},
};

bool canTransitionMafiaPhase(MafiaPhase from, MafiaPhase to) {
  return kMafiaPhaseTransitions[from]?.contains(to) ?? false;
}
