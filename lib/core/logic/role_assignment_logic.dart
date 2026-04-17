// lib/core/logic/role_assignment_logic.dart
import '../../models/member_model.dart';
import '../constants/roles.dart';

class RoleAssignmentResult {
  final bool isAllowed;
  final String? message;
  final MemberModel? updatedMember;

  const RoleAssignmentResult({
    required this.isAllowed,
    this.message,
    this.updatedMember,
  });

  factory RoleAssignmentResult.denied(String message) {
    return RoleAssignmentResult(
      isAllowed: false,
      message: message,
    );
  }

  factory RoleAssignmentResult.allowed(MemberModel member) {
    return RoleAssignmentResult(
      isAllowed: true,
      updatedMember: member,
    );
  }
}

class RoleAssignmentLogic {
  RoleAssignmentLogic._();

  // =========================================================
  // Assign Founder (on group creation)
  // =========================================================
  static MemberModel createFounder({
    required MemberModel member,
  }) {
    return member.copyWith(role: Roles.founder);
  }

  // =========================================================
  // Check if actor can modify target (UI & Logic Helper)
  // =========================================================
  static bool canModify({
    required Roles actorRole,
    required Roles targetRole,
    String? actorId,
    String? targetId,
  }) {
    // 1. لا يمكن لأي شخص تعديل رتبته بنفسه (حتى المؤسس)
    if (actorId != null && targetId != null && actorId == targetId) {
      return false;
    }

    // 2. المؤسس (الشوغون) يمكنه تعديل الجميع ما عدا مؤسس آخر (إن وجد)
    if (actorRole == Roles.founder && targetRole != Roles.founder) {
      return true;
    }

    // 3. الرتب الأخرى: لا يمكن تعديل شخص يمتلك رتبة مساوية أو أعلى
    // يجب أن يكون المستوى (rankLevel) للـ actor أعلى من الـ target
    if (actorRole.rankLevel <= targetRole.rankLevel) {
      return false;
    }

    // 4. قاعدة إضافية: الرتب العادية (Member) لا تملك صلاحية التعديل أبداً
    if (actorRole == Roles.member) {
      return false;
    }

    return true;
  }

  // =========================================================
  // Promote/Assign Member (Updated to support Demotion to Member)
  // =========================================================
  static RoleAssignmentResult promote({
    required MemberModel actor,
    required MemberModel target,
    required Roles newRole,
    required List<MemberModel> allMembers,
  }) {
    // منع تعديل المؤسس
    if (target.role == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تعديل رتبة الشوغون (المؤسس).",
      );
    }

    // التحقق من صلاحية القائم بالفعل (Actor)
    // نمرر الـ IDs لضمان عدم قيام الشخص بتعديل نفسه
    if (!canModify(
      actorRole: actor.role,
      targetRole: target.role,
      actorId: actor.userId,
      targetId: target.userId,
    )) {
      return RoleAssignmentResult.denied(
        "لا تملك الصلاحية الكافية لتعديل هذا العضو.",
      );
    }

    // لا يمكن تعيين مؤسس جديد يدوياً
    if (newRole == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تعيين شوغون إضافي للمجموعة.",
      );
    }

    // التحقق من السعة القصوى للرتبة الجديدة (Limited Roles)
    // ✅ التعديل: نتحقق من السعة فقط إذا كانت الرتبة الجديدة محدودة (ليست Member)
    if (newRole.isLimited) {
      // ✅ التعديل: عند حساب العدد الحالي، نستثني العضو المستهدف (target) 
      // لأنه إذا كان يمتلك الرتبة بالفعل أو سينتقل منها، فلا يجب أن يحسب كعائق
      final currentCount = allMembers
          .where((m) => m.role == newRole && m.userId != target.userId)
          .length;

      if (currentCount >= (newRole.maxCount ?? 0)) {
        return RoleAssignmentResult.denied(
          "تم الوصول للحد الأقصى لعدد أعضاء رتبة ${newRole.label}.",
        );
      }
    }

    // ✅ التعديل: الآن الدالة ستسمح بتعيين Roles.member دون قيود
    final updated = target.copyWith(role: newRole);
    return RoleAssignmentResult.allowed(updated);
  }

  // =========================================================
  // Demote Member
  // =========================================================
  static RoleAssignmentResult demote({
    required MemberModel actor,
    required MemberModel target,
  }) {
    if (target.role == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تخفيض رتبة الشوغون.",
      );
    }

    if (!canModify(
      actorRole: actor.role,
      targetRole: target.role,
      actorId: actor.userId,
      targetId: target.userId,
    )) {
      return RoleAssignmentResult.denied(
        "لا تملك صلاحية تخفيض رتبة هذا العضو.",
      );
    }

    // إرجاع الرتبة إلى عضو عادي
    final updated = target.copyWith(
      role: Roles.member,
    );

    return RoleAssignmentResult.allowed(updated);
  }

  // =========================================================
  // Get Members by Hierarchy (Sorting)
  // =========================================================
  static List<MemberModel> sortByHierarchy(List<MemberModel> members) {
    final sorted = [...members];

    sorted.sort((a, b) {
      // ترتيب تنازلي بناءً على قوة الرتبة
      return b.role.rankLevel.compareTo(a.role.rankLevel);
    });

    return sorted;
  }
}