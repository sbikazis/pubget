import '../models/game_models.dart';

/// Identifiers for scoring strategies. Specific games register their own
/// implementation later; the generic engine only selects a strategy.
enum ScoringStrategyId { noop }

abstract interface class ScoringStrategy {
  ScoringStrategyId get id;

  /// Returns points for [action]. The generic engine does not decide how
  /// points are awarded — implementations own that.
  int scoreFor({
    required GameAction action,
    required PubgetGame game,
    Map<String, dynamic> context = const <String, dynamic>{},
  });
}

final class NoOpScoringStrategy implements ScoringStrategy {
  const NoOpScoringStrategy();

  @override
  ScoringStrategyId get id => ScoringStrategyId.noop;

  @override
  int scoreFor({
    required GameAction action,
    required PubgetGame game,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) => 0;
}

abstract final class ScoringStrategyRegistry {
  static const _strategies = <ScoringStrategyId, ScoringStrategy>{
    ScoringStrategyId.noop: NoOpScoringStrategy(),
  };

  static ScoringStrategy of(ScoringStrategyId id) =>
      _strategies[id] ?? const NoOpScoringStrategy();

  static ScoringStrategy forType(GameType type) {
    // Future games register a non-noop id on their GameTypeSpec.
    return of(ScoringStrategyId.noop);
  }
}
