// lib/core/constants/limits.dart
class Limits {

  // Subscription Limits - Premium مفصول تماماً
  static const int maxGroupsFree = 1;
  static const int maxGroupsPremium = 1; // ✅ أصبح = Free

  static const int maxJoinedFree = 2;
  static const int maxJoinedPremium = 2; // ✅ أصبح = Free

  static const int maxMembersFree = 100;
  static const int maxMembersPremium = 100; // ✅ أصبح = Free

  // Premium System Features
  static const String premiumBadge = "💎";
  static const String premiumPrice = "900 coins";
  static const double premiumPriceNumeric = 900.0;

  // Respect System
  static const int respectMin = 0;
  static const int respectMax = 7;
  static const int fanThreshold = 5;

  // Role System
  static const int maxSensei = 2;
  static const int maxHakusho = 3;
  static const int maxSenpai = 4;

  // Group Creation Limits
  static const int maxGroupNameLength = 30;
  static const int maxGroupDescriptionLength = 300;
  static const int maxGroupSloganLength = 16;

  // User Profile Limits
  static const int maxUsernameLength = 20;
  static const int maxNicknameLength = 20;
  static const int maxBioLength = 200;
  static const int maxFavoriteAnime = 10;

  // Roleplay Limits
  static const int maxCharacterNameLength = 25;
  static const int maxCharacterReasonLength = 150;

  // Chat Limits
  static const int maxMessageLength = 1000;
  static const int maxMediaSizeMB = 20;

  // ✅ Edit Message Limits
  static const int editMessageWindowMinutes = 10;

  // Game Limits
  static const int maxGameNameLength = 30;
  static const Duration maxGameDuration = Duration(minutes: 20);

  // Ads System
  static const Duration adCooldown = Duration(minutes: 5);

  // Promotion
  static const Duration promotionDuration = Duration(days: 3);
}