// lib/core/logic/subscription_limits_logic.dart
import '../constants/limits.dart';
import '../../models/user_model.dart';

class SubscriptionLimitsResult {
  final bool isAllowed;
  final String? message;
  final bool shouldShowUpgrade;

  const SubscriptionLimitsResult({
    required this.isAllowed,
    this.message,
    this.shouldShowUpgrade = false,
  });

  factory SubscriptionLimitsResult.allowed() {
    return const SubscriptionLimitsResult(isAllowed: true);
  }

  factory SubscriptionLimitsResult.denied(String message, {bool showUpgrade = true}) {
    return SubscriptionLimitsResult(
      isAllowed: false,
      message: message,
      shouldShowUpgrade: showUpgrade,
    );
  }
}

class SubscriptionLimitsLogic {
  SubscriptionLimitsLogic._();

  /// التحقق من إنشاء مجموعة - Premium لا يعطي شيء
  static SubscriptionLimitsResult canCreateGroup(UserModel user, int currentOwnedCount) {
    // ✅ Premium مفصول تماماً - فقط التوسعة المشتراة
    int limit = user.customMaxCreatedGroupsLimit > 0 
        ? user.customMaxCreatedGroupsLimit 
        : Limits.maxGroupsFree; // دائماً 1

    if (currentOwnedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        "وصلت للحد الأقصى ($limit مجموعة). اشترِ توسعة إنشاء المجموعات من المتجر لفتح 3 مجموعات.",
        showUpgrade: true,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من الانضمام - Premium لا يعطي شيء
  static SubscriptionLimitsResult canJoinGroup(UserModel user, int currentJoinedCount) {
    int limit = user.customMaxJoinedGroupsLimit > 0
        ? user.customMaxJoinedGroupsLimit
        : Limits.maxJoinedFree; // دائماً 2

    if (currentJoinedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        "لا يمكنك الانضمام لأكثر من $limit مجموعات. اشترِ توسعة الانضمام من المتجر لفتح 7 مجموعات.",
        showUpgrade: true,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من سعة الأعضاء - Premium لا يعطي شيء
  static SubscriptionLimitsResult canAcceptNewMember(UserModel adminUser, int currentMembersCount) {
    int limit = adminUser.customMaxMembersLimit > 0
        ? adminUser.customMaxMembersLimit
        : Limits.maxMembersFree; // دائماً 100

    if (currentMembersCount >= limit) {
      return SubscriptionLimitsResult.denied(
        "وصلت المجموعة للحد الأقصى ($limit عضو). اشترِ توسعة الأعضاء من المتجر لفتح 350 عضو.",
        showUpgrade: true,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }
}