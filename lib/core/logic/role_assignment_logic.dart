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
  // Promote/Assign Member
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

    // ✅ [إصلاح المشكلة 2] من ترقى بالدعوات (isManualRole == false) لا يُخفَّض لـ member
    // يمكن فقط رفعه لرتبة أعلى فيصبح يدوياً — التخفيض لـ member ممنوع
    if (target.isManualRole == false &&
        target.role != Roles.member &&
        newRole == Roles.member) {
      return RoleAssignmentResult.denied(
        "لا يمكن تخفيض ${target.effectiveName} لعضو عادي لأن رتبته مكتسبة عبر نظام الدعوات.\n"
        "يمكنك فقط رفعه لرتبة أعلى.",
      );
    }

    // ✅ [إصلاح المشكلة 2] إذا كان من ترقى بالدعوات والرتبة الجديدة أدنى من رتبته الحالية
    // (ليس member لكن رتبة وسطى أدنى) — هذا مسموح لكنه يصبح يدوياً
    // لا نحتاج منع هذا لأن الشوغو يستطيع رفعه فقط بالتعريف

    // التحقق من حد الشوغو اليدوي المنفصل
    // الشوغو يملك فقط: 1 سينسي + 2 هاكوشو + 2 سنباي يدوياً
    if (newRole.isLimited && newRole != Roles.member) {
      final manualLimit = newRole.manualMaxCount ?? 0;

      final currentManualCount = allMembers
          .where((m) =>
              m.role == newRole &&
              m.isManualRole == true &&
              m.userId != target.userId)
          .length;

      if (currentManualCount >= manualLimit) {
        return RoleAssignmentResult.denied(
          "وصلت للحد الأقصى لتعيين ${newRole.label} يدوياً ($manualLimit مقاعد).\n"
          "المقاعد الأخرى محجوزة لنظام الدعوات التلقائي.",
        );
      }
    }

    // التحقق من السعة الإجمالية للرتبة (يدوي + تلقائي معاً)
    if (newRole.isLimited && newRole != Roles.member) {
      final currentCount = allMembers
          .where((m) => m.role == newRole && m.userId != target.userId)
          .length;

      if (currentCount >= (newRole.maxCount ?? 0)) {
        return RoleAssignmentResult.denied(
          "تم الوصول للحد الأقصى الإجمالي لعدد أعضاء رتبة ${newRole.label}.",
        );
      }
    }

    // ✅ وضع isManualRole: true عند التعيين اليدوي من الشوغو
    // إذا كانت الرتبة الجديدة هي member، فلا داعي لـ isManualRole
    final bool isManual = newRole != Roles.member;
    final updated = target.copyWith(
      role: newRole,
      isManualRole: isManual,
    );

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

    // ✅ [إصلاح المشكلة 2] منع تخفيض من ترقى بالدعوات لـ member
    // هذه الدالة تُخفِّض مباشرة لـ member — ممنوعة إذا كان isManualRole == false
    if (target.isManualRole == false && target.role != Roles.member) {
      return RoleAssignmentResult.denied(
        "لا يمكن تخفيض ${target.effectiveName} لعضو عادي لأن رتبته مكتسبة عبر نظام الدعوات.\n"
        "يمكنك فقط رفعه لرتبة أعلى من خلال التعيين اليدوي.",
      );
    }

    // عند التخفيض لعضو عادي، نُعيد isManualRole: false
    // حتى يصبح مؤهلاً للترقية التلقائية عبر نظام الدعوات مجدداً
    final updated = target.copyWith(
      role: Roles.member,
      isManualRole: false,
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