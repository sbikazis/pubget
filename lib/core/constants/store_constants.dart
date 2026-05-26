// lib/core/constants/store_constants.dart

class StoreConstants {
  // أسعار الخدمات بالعملات الرقمية
  static const int premiumSubscriptionPrice = 900; // تم التعديل من 500 إلى 900
  static const int premiumDurationDays = 30; // مدة الاشتراك الشهري
  static const int groupPromotionPrice = 150;
  static const int domainExpansionPrice = 200;

  // مكافآت تحصيل العملات المجانية
  static const int rewardEventWin = 10;
  static const int rewardWatchAd = 20;
  static const int rewardInviter = 70;
  static const int rewardInvited = 30;
  static const int rewardPublishEdit = 10;
  // تم حذف rewardFollowAccount - مخالف لسياسة Google Play

  // حدود التوسعات التقنية
  static const int expandedGroupMembersLimit = 350;
  static const int expandedJoinedGroupsLimit = 7;
  static const int expandedCreatedGroupsLimit = 3;
  
  // حدود مرات الحصول على المكافآت
  static const int maxEditRewardsPerDay = 1;
  static const int maxEventWinsPerDay = 3;
}
