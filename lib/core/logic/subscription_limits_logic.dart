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
    // ✅ التصحيح: تم التأكد من استخدام النقطتين الرأسيتين (:) لتمرير القيم للمعاملات المسماة
    return SubscriptionLimitsResult(
      isAllowed: false,
      message: message,
      shouldShowUpgrade: showUpgrade, 
    );
  }
}

class SubscriptionLimitsLogic {
  SubscriptionLimitsLogic._();

  /// التحقق من صلاحية إنشاء مجموعة جديدة
  static SubscriptionLimitsResult canCreateGroup(UserModel user, int currentOwnedCount) {
    final bool isPremium = user.isPremium;
    final int limit = isPremium ? Limits.maxGroupsPremium : Limits.maxGroupsFree;

    if (currentOwnedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        isPremium 
          ? "لقد استنفدت الحد الأقصى لإنشاء المجموعات (الحد: $limit)." 
          : "وصلت للحد الأقصى للنسخة المجانية. يمكنك إنشاء مجموعة واحدة فقط.",
        showUpgrade: !isPremium,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من صلاحية الانضمام لمجموعة جديدة
  static SubscriptionLimitsResult canJoinGroup(UserModel user, int currentJoinedCount) {
    final bool isPremium = user.isPremium;
    final int limit = isPremium ? Limits.maxJoinedPremium : Limits.maxJoinedFree;

    if (currentJoinedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        isPremium
          ? "لقد وصلت للحد الأقصى للانضمامات ($limit مجموعات)."
          : "لا يمكنك الانضمام لأكثر من مجموعتين في النسخة المجانية.",
        showUpgrade: !isPremium,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من سعة المجموعة عند قبول عضو جديد (منطق الشوغو)
  static SubscriptionLimitsResult canAcceptNewMember(UserModel adminUser, int currentMembersCount) {
    final bool isPremium = adminUser.isPremium;
    final int limit = isPremium ? Limits.maxMembersPremium : Limits.maxMembersFree;

    if (currentMembersCount >= limit) {
      return SubscriptionLimitsResult.denied(
        isPremium
          ? "وصلت المجموعة لأقصى سعة مسموحة ($limit عضو)."
          : "وصلت المجموعة للحد الأقصى (100 عضو). قم بالترقية لفتح السعة إلى 350 عضو.",
        showUpgrade: !isPremium,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }
}