import '../models/economy_types.dart';

typedef AdStrategyProvider = AdPlacementStrategy Function(AdPlacement placement);
typedef AdFreeCheck = bool Function();
typedef AdImpressionCallback = void Function(AdPlacement placement);

/// Runtime policy for one ad surface. This is deliberately separate from
/// placement frequency history so the native SDK can be added without changing
/// the economy provider's eligibility rules.
final class AdPlacementStrategy {
  const AdPlacementStrategy({
    required this.placement,
    required this.enabled,
    required this.format,
    required this.frequencyPerDay,
    required this.cooldown,
    required this.premiumExcluded,
  });

  final AdPlacement placement;
  final bool enabled;
  final AdMobFormat format;
  final int frequencyPerDay;
  final Duration cooldown;
  final bool premiumExcluded;
}

/// Ad surface coordinator.
///
/// The repository currently has no configured AdMob application/ad-unit IDs
/// and does not include the Google Mobile Ads SDK. Therefore [show] fails
/// closed and returns false rather than pretending an ad was displayed. The
/// strategy and impression callbacks are ready for a real SDK adapter once
/// valid platform IDs and consent handling are configured.
final class AdManager {
  const AdManager({
    required AdStrategyProvider strategyProvider,
    required AdFreeCheck isAdFree,
    required AdImpressionCallback onImpressionLogged,
  }) : _strategyProvider = strategyProvider,
       _isAdFree = isAdFree,
       _onImpressionLogged = onImpressionLogged;

  final AdStrategyProvider _strategyProvider;
  final AdFreeCheck _isAdFree;
  final AdImpressionCallback _onImpressionLogged;

  AdPlacementStrategy strategyFor(AdPlacement placement) =>
      _strategyProvider(placement);

  bool isEligible(AdPlacement placement) {
    final strategy = _strategyProvider(placement);
    if (!strategy.enabled) return false;
    if (strategy.premiumExcluded && _isAdFree()) return false;
    return true;
  }

  Future<bool> show(AdPlacement placement) async {
    // No SDK is configured: do not fabricate an impression.
    return false;
  }

  /// Call only from a native SDK's confirmed on-impression callback.
  void reportImpression(AdPlacement placement) {
    if (isEligible(placement)) _onImpressionLogged(placement);
  }
}
