import '../constants/limits.dart';
import '../constants/subscription_type.dart';

class SubscriptionLimitsResult {
  final bool isAllowed;
  final String? message;

  const SubscriptionLimitsResult({
    required this.isAllowed,
    this.message,
  });

  factory SubscriptionLimitsResult.allowed() {
    return const SubscriptionLimitsResult(
      isAllowed: true,
    );
  }

  factory SubscriptionLimitsResult.denied(String message) {
    return SubscriptionLimitsResult(
      isAllowed: false,
      message: message,
    );
  }
}

class SubscriptionLimitsLogic {
  SubscriptionLimitsLogic._();


  //  Check Create Group Limit

  static SubscriptionLimitsResult canCreateGroup({
    required SubscriptionType subscriptionType,
    required int currentCreatedGroups,
  }) {
    final maxGroups = subscriptionType.isPremium
        ? Limits.maxGroupsPremium
        : Limits.maxGroupsFree;

    if (currentCreatedGroups >= maxGroups) {
      return SubscriptionLimitsResult.denied(
        subscriptionType.isPremium
            ? "لقد وصلت إلى الحد الأقصى لإنشاء المجموعات."
            : "يمكنك إنشاء مجموعة واحدة فقط. قم بالترقية لإنشاء المزيد.",
      );
    }

    return SubscriptionLimitsResult.allowed();
  }


  //  Check Join Group Limit

  static SubscriptionLimitsResult canJoinGroup({
    required SubscriptionType subscriptionType,
    required int currentJoinedGroups,
  }) {
    final maxJoined = subscriptionType.isPremium
        ? Limits.maxJoinedPremium
        : Limits.maxJoinedFree;

    if (currentJoinedGroups >= maxJoined) {
      return SubscriptionLimitsResult.denied(
        subscriptionType.isPremium
            ? "لقد وصلت إلى الحد الأقصى للانضمام إلى المجموعات."
            : "يمكنك الانضمام إلى مجموعتين فقط. قم بالترقية للانضمام إلى المزيد.",
      );
    }

    return SubscriptionLimitsResult.allowed();
  }


  //  Check Group Member Capacity

  static SubscriptionLimitsResult canAddMemberToGroup({
    required SubscriptionType subscriptionType,
    required int currentMembersCount,
  }) {
    final maxMembers = subscriptionType.isPremium
        ? Limits.maxMembersPremium
        : Limits.maxMembersFree;

    if (currentMembersCount >= maxMembers) {
      return SubscriptionLimitsResult.denied(
        subscriptionType.isPremium
            ? "المجموعة وصلت إلى الحد الأقصى للأعضاء."
            : "المجموعة ممتلئة (100 عضو كحد أقصى للحساب المجاني).",
      );
    }

    return SubscriptionLimitsResult.allowed();
  }
}