import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../models/achievement_models.dart';

final class AchievementCopy {
  const AchievementCopy(this._s);

  final AppStrings _s;

  static AchievementCopy of(BuildContext context) =>
      AchievementCopy(AppStrings.of(context));

  bool get isArabic => _s.isArabic;

  String get title => _s.achievements;
  String get myAchievements => _s.pick('My Achievements', 'إنجازاتي');
  String achievementsOf(String name) =>
      _s.pick('Achievements of $name', 'إنجازات $name');

  String entryLabel({required bool isOwner, required String displayName}) {
    final name = displayName.trim();
    if (isOwner) return myAchievements;
    if (name.isEmpty) return title;
    return achievementsOf(name);
  }

  String get progressRatio => _s.pick('Progress', 'نسبة التقدم');
  String get showUnlockedOnly =>
      _s.pick('Show unlocked', 'عرض المحقَّقة');
  String get unlockedEmptyTitle =>
      _s.pick('No achievements yet', 'لا إنجازات بعد');
  String get unlockedEmptyBody => _s.pick(
        'Join a group, send a message, or publish an Edit to cross The Threshold.',
        'انضم لمجموعة أو أرسل رسالة أو انشر Edit لعبور العتبة.',
      );
  String get loadFailed =>
      _s.pick('Achievements could not load.', 'تعذّر تحميل الإنجازات.');
  String get retry => _s.pick('Try again', 'إعادة المحاولة');
  String get unlockedOn => _s.pick('Unlocked', 'تاريخ الحصول');
  String get rarity => _s.pick('Rarity', 'الندرة');
  String get conditions => _s.pick('Requirements', 'الشروط');

  String rarityLabel(AchievementRarity rarity) => switch (rarity) {
        AchievementRarity.common => _s.pick('Common', 'شائع'),
        AchievementRarity.uncommon => _s.pick('Uncommon', 'غير شائع'),
        AchievementRarity.rare => _s.pick('Rare', 'نادر'),
        AchievementRarity.epic => _s.pick('Epic', 'ملحمي'),
        AchievementRarity.legendary => _s.pick('Legendary', 'أسطوري'),
        AchievementRarity.mythic => _s.pick('Mythic', 'ميثي'),
      };
}
