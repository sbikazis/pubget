class Limits {

  // Subscription Limits


  static const int maxGroupsFree = 1;
  static const int maxGroupsPremium = 3; // ✅ تم التعديل من 2 إلى 3

  static const int maxJoinedFree = 2;
  static const int maxJoinedPremium = 7; // ✅ تم التعديل من 5 إلى 7

  static const int maxMembersFree = 100;
  static const int maxMembersPremium = 350; // ✅ تم التعديل من 200 إلى 350


  // Premium System Features (New)


  static const String premiumBadge = "💎";
  static const String premiumPrice = "10\$";
  static const double premiumPriceNumeric = 10.0;


  // Respect System


  static const int respectMin = 0;
  static const int respectMax = 7;

  /// When respect > fanThreshold → user becomes fan
  static const int fanThreshold = 5;


  // Role System (Fixed Globally)


  static const int maxSensei = 2;
  static const int maxHakusho = 3;
  static const int maxSenpai = 4;


  // Group Creation Limits


  static const int maxGroupNameLength = 30;
  static const int maxGroupDescriptionLength = 300;
  static const int maxGroupSloganLength = 16; // 3–4 words


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


  // Game Limits


  static const int maxGameNameLength = 30;
  static const Duration maxGameDuration =
      Duration(minutes: 20);


  // Ads System


  /// Minimum duration between ads
  static const Duration adCooldown =
      Duration(minutes: 5);


  // Promotion


  static const Duration promotionDuration =
      Duration(days: 3);
}