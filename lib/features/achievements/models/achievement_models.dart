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
    this.seasonId,
    this.seasonStartAt,
    this.seasonEndAt,
    this.seasonState = 'evergreen',
    this.trigger,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int rewardCoins;
  final String? seasonId;
  final DateTime? seasonStartAt;
  final DateTime? seasonEndAt;
  final String seasonState;
  final String? trigger;

  bool get isSeasonal => seasonId != null && seasonId!.isNotEmpty;

  String get statusLabel {
    if (unlocked) return 'Unlocked';
    if (seasonState == 'upcoming') return 'Upcoming';
    if (seasonState == 'ended') return 'Ended';
    if (seasonState == 'active') return 'In season';
    return 'Locked';
  }
}
