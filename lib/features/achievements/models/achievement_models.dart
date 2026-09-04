final class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    this.unlockedAt,
    this.rewardCoins = 0,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int rewardCoins;
}
