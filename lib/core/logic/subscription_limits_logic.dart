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

  factory SubscriptionLimitsResult.denied(String message,
      {bool showUpgrade = true}) {
    return SubscriptionLimitsResult(
      isAllowed: false,
      message: message,
      shouldShowUpgrade: showUpgrade,
    );
  }
}

class SubscriptionLimitsLogic {
  SubscriptionLimitsLogic._();

  /// التحقق من إنشاء مجموعة
  static SubscriptionLimitsResult canCreateGroup(
      UserModel user, int currentOwnedCount) {
    final bool hasPurchasedExpansion =
        user.customMaxCreatedGroupsLimit > 0;

    final int limit = hasPurchasedExpansion
        ? user.customMaxCreatedGroupsLimit
        : Limits.maxGroupsFree;

    if (currentOwnedCount >= limit) {
      // ✅ لم يشترِ بعد → وجّهه للمتجر
      if (!hasPurchasedExpansion) {
        return SubscriptionLimitsResult.denied(
          'وصلت للحد الأقصى ($limit مجموعة).'
          ' اشترِ توسعة إنشاء المجموعات من المتجر لفتح 3 مجموعات.',
          showUpgrade: true,
        );
      }

      // ✅ اشترى ووصل للحد الأقصى النهائي → لا يوجد ما يُشترى
      return SubscriptionLimitsResult.denied(
        'وصلت للحد الأقصى المتاح ($limit مجموعة).'
        ' هذا هو الحد النهائي لإنشاء المجموعات.',
        showUpgrade: false,
      );
    }

    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من الانضمام
  static SubscriptionLimitsResult canJoinGroup(
      UserModel user, int currentJoinedCount) {
    final bool hasPurchasedExpansion =
        user.customMaxJoinedGroupsLimit > 0;

    final int limit = hasPurchasedExpansion
        ? user.customMaxJoinedGroupsLimit
        : Limits.maxJoinedFree;

    if (currentJoinedCount >= limit) {
      // ✅ لم يشترِ بعد → وجّهه للمتجر
      if (!hasPurchasedExpansion) {
        return SubscriptionLimitsResult.denied(
          'لا يمكنك الانضمام لأكثر من $limit مجموعات.'
          ' اشترِ توسعة الانضمام من المتجر لفتح 7 مجموعات.',
          showUpgrade: true,
        );
      }

      // ✅ اشترى ووصل للحد الأقصى النهائي
      return SubscriptionLimitsResult.denied(
        'وصلت للحد الأقصى المتاح ($limit مجموعة).'
        ' هذا هو الحد النهائي للانضمام إلى المجموعات.',
        showUpgrade: false,
      );
    }

    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من سعة الأعضاء
  static SubscriptionLimitsResult canAcceptNewMember(
      UserModel adminUser, int currentMembersCount) {
    final bool hasPurchasedExpansion =
        adminUser.customMaxMembersLimit > 0;

    final int limit = hasPurchasedExpansion
        ? adminUser.customMaxMembersLimit
        : Limits.maxMembersFree;

    if (currentMembersCount >= limit) {
      // ✅ لم يشترِ بعد → وجّهه للمتجر
      if (!hasPurchasedExpansion) {
        return SubscriptionLimitsResult.denied(
          'وصلت المجموعة للحد الأقصى ($limit عضو).'
          ' اشترِ توسعة الأعضاء من المتجر لفتح 350 عضو.',
          showUpgrade: true,
        );
      }

      // ✅ اشترى ووصل للحد الأقصى النهائي
      return SubscriptionLimitsResult.denied(
        'وصلت المجموعة للحد الأقصى المتاح ($limit عضو).'
        ' هذا هو الحد النهائي لسعة الأعضاء.',
        showUpgrade: false,
      );
    }

    return SubscriptionLimitsResult.allowed();
  }
}