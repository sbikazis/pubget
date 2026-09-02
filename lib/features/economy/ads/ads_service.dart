import '../models/economy_models.dart';
import '../models/economy_types.dart';

final class AdsService {
  AdsService({
    Map<AdPlacement, AdPlacementConfig>? configs,
  }) : configs = configs ??
            const <AdPlacement, AdPlacementConfig>{
              AdPlacement.homeFeed: AdPlacementConfig(
                placement: AdPlacement.homeFeed,
              ),
              AdPlacement.groupEntry: AdPlacementConfig(
                placement: AdPlacement.groupEntry,
              ),
              AdPlacement.storeFooter: AdPlacementConfig(
                placement: AdPlacement.storeFooter,
                frequencyPerDay: 1,
                cooldown: Duration(minutes: 10),
              ),
            };

  final Map<AdPlacement, AdPlacementConfig> configs;

  bool shouldShow({
    required AdPlacement placement,
    required bool isAdFree,
    required DateTime now,
    required AdImpressionLog log,
  }) {
    final config = configs[placement];
    if (config == null || !config.enabled) return false;
    if (config.premiumExcluded && isAdFree) return false;
    final history = log.shownAt[placement] ?? const <DateTime>[];
    final dayStart = DateTime(now.year, now.month, now.day);
    final today = history.where((time) => !time.isBefore(dayStart)).length;
    if (today >= config.frequencyPerDay) return false;
    if (history.isNotEmpty) {
      final last = history.last;
      if (now.difference(last) < config.cooldown) return false;
    }
    return true;
  }
}
