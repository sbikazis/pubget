/// Achievements domain models — display only; unlock/progress are server-owned.
library;

enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic,
}

enum AchievementAnimationType {
  none,
  shimmer,
  orbitLights,
  pathGlow,
  brushTrail,
  starPulse,
  bannerSway,
  crownGlow,
  lightSweep,
  mythicLiving,
}

final class AchievementConditionProgress {
  const AchievementConditionProgress({
    required this.id,
    required this.labelEn,
    required this.labelAr,
    required this.current,
    required this.target,
    required this.met,
  });

  final String id;
  final String labelEn;
  final String labelAr;
  final num current;
  final num target;
  final bool met;

  String label(bool arabic) => arabic ? labelAr : labelEn;
}

final class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.rarity,
    required this.nameEn,
    required this.nameAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.meaningEn,
    required this.meaningAr,
    required this.assetPath,
    required this.animationType,
    required this.conditions,
    this.rewardCoins = 0,
  });

  final String id;
  final AchievementRarity rarity;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final String meaningEn;
  final String meaningAr;
  final String assetPath;
  final AchievementAnimationType animationType;
  final List<AchievementConditionProgress> conditions;
  final int rewardCoins;

  String name(bool arabic) => arabic ? nameAr : nameEn;
  String description(bool arabic) => arabic ? descriptionAr : descriptionEn;
  String meaning(bool arabic) => arabic ? meaningAr : meaningEn;
}

final class AchievementItem {
  const AchievementItem({
    required this.definition,
    required this.unlocked,
    this.unlockedAt,
    this.currentValue = 0,
    this.targetValue = 0,
    this.conditions = const <AchievementConditionProgress>[],
  });

  final AchievementDefinition definition;
  final bool unlocked;
  final DateTime? unlockedAt;
  final num currentValue;
  final num targetValue;
  final List<AchievementConditionProgress> conditions;

  String get id => definition.id;
  AchievementRarity get rarity => definition.rarity;
  String get assetPath => definition.assetPath;
  AchievementAnimationType get animationType => definition.animationType;

  /// Backward-compatible fields used by older callers/tests.
  String get type => rarity.name;
  String get title => definition.nameEn;
  String get description => definition.descriptionEn;
  String get icon => definition.id;
  int get rewardCoins => definition.rewardCoins;
  String? get seasonId => null;
  DateTime? get seasonStartAt => null;
  DateTime? get seasonEndAt => null;
  String get seasonState => 'evergreen';
  String? get trigger => null;
  bool get isSeasonal => false;

  String get statusLabel {
    if (unlocked) return 'Unlocked';
    return 'Locked';
  }

  List<AchievementConditionProgress> get effectiveConditions =>
      conditions.isNotEmpty ? conditions : definition.conditions;

  AchievementItem copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    num? currentValue,
    num? targetValue,
    List<AchievementConditionProgress>? conditions,
  }) {
    return AchievementItem(
      definition: definition,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      conditions: conditions ?? this.conditions,
    );
  }
}

AchievementRarity parseRarity(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'uncommon':
      return AchievementRarity.uncommon;
    case 'rare':
      return AchievementRarity.rare;
    case 'epic':
      return AchievementRarity.epic;
    case 'legendary':
      return AchievementRarity.legendary;
    case 'mythic':
      return AchievementRarity.mythic;
    default:
      return AchievementRarity.common;
  }
}

AchievementAnimationType parseAnimationType(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'shimmer':
      return AchievementAnimationType.shimmer;
    case 'orbit_lights':
      return AchievementAnimationType.orbitLights;
    case 'path_glow':
      return AchievementAnimationType.pathGlow;
    case 'brush_trail':
      return AchievementAnimationType.brushTrail;
    case 'star_pulse':
      return AchievementAnimationType.starPulse;
    case 'banner_sway':
      return AchievementAnimationType.bannerSway;
    case 'crown_glow':
      return AchievementAnimationType.crownGlow;
    case 'light_sweep':
      return AchievementAnimationType.lightSweep;
    case 'mythic_living':
      return AchievementAnimationType.mythicLiving;
    default:
      return AchievementAnimationType.none;
  }
}
