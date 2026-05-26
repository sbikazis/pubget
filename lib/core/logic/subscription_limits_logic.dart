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

  /// التحقق من صلاحية إنشاء مجموعة جديدة (توسعة المجال 3)
  static SubscriptionLimitsResult canCreateGroup(UserModel user, int currentOwnedCount) {
    // 🛡️ فحص أولاً: هل يمتلك المستخدم توسعة مجال مشتراة من المتجر لإنشاء مجموعات أكثر؟
    int limit = user.customMaxCreatedGroupsLimit;

    // إذا لم يشتري توسعة مخصصة بعد، نعود للمنطق الافتراضي (بريميوم أو مجاني)
    if (limit <= 0) {
      limit = user.isPremium ? Limits.maxGroupsPremium : Limits.maxGroupsFree;
    }

    if (currentOwnedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        user.isPremium 
          ? "لقد استنفدت الحد الأقصى لإنشاء المجموعات (الحد الحالي: $limit)." 
          : "وصلت للحد الأقصى للنسخة المجانية. يمكنك امتلاك مجموعة واحدة فقط أو شراء توسعة المجال من المتجر.",
        showUpgrade: true, // تفعيل التوجيه للمتجر لشراء التوسعة التقنية
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من صلاحية الانضمام لمجموعة جديدة (توسعة المجال 2)
  static SubscriptionLimitsResult canJoinGroup(UserModel user, int currentJoinedCount) {
    // 🛡️ فحص أولاً: هل يمتلك المستخدم توسعة مجال مشتراة لانضمامات أكثر؟
    int limit = user.customMaxJoinedGroupsLimit;

    if (limit <= 0) {
      limit = user.isPremium ? Limits.maxJoinedPremium : Limits.maxJoinedFree;
    }

    if (currentJoinedCount >= limit) {
      return SubscriptionLimitsResult.denied(
        user.isPremium
          ? "لقد وصلت للحد الأقصى للانضمامات ($limit مجموعات)."
          : "لا يمكنك الانضمام لأكثر من مجموعتين في النسخة المجانية. احصل على التوسعة التقنية لفتح المجال لـ 7 مجموعات!",
        showUpgrade: true,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }

  /// التحقق من سعة المجموعة عند قبول عضو جديد (توسعة المجال 1 - منطق الشوغو)
  static SubscriptionLimitsResult canAcceptNewMember(UserModel adminUser, int currentMembersCount) {
    // 🛡️ فحص أولاً: هل يمتلك منشئ المجموعة (الآدمين) توسعة مخصصة لعدد الأعضاء؟
    int limit = adminUser.customMaxMembersLimit;

    if (limit <= 0) {
      limit = adminUser.isPremium ? Limits.maxMembersPremium : Limits.maxMembersFree;
    }

    if (currentMembersCount >= limit) {
      return SubscriptionLimitsResult.denied(
        adminUser.isPremium
          ? "وصلت المجموعة لأقصى سعة مسموحة حالياً ($limit عضو)."
          : "وصلت المجموعة للحد الأقصى للنسخة المجانية (100 عضو). قم بزيارة المتجر لفتح السعة إلى 350 عضو.",
        showUpgrade: true,
      );
    }
    return SubscriptionLimitsResult.allowed();
  }
}