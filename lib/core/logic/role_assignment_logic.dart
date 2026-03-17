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


  // Assign Founder (on group creation)

  static MemberModel createFounder({
    required MemberModel member,
  }) {
    return member.copyWith(role: Roles.founder);
  }


  // Check if actor can modify target

  static bool canModify({
    required Roles actorRole,
    required Roles targetRole,
  }) {
    // Founder can modify anyone except another founder
    if (actorRole == Roles.founder &&
        targetRole != Roles.founder) {
      return true;
    }

    // Cannot modify someone equal or higher
    if (!actorRole.isHigherThan(targetRole)) {
      return false;
    }

    return true;
  }


  // Promote Member

  static RoleAssignmentResult promote({
    required MemberModel actor,
    required MemberModel target,
    required Roles newRole,
    required List<MemberModel> allMembers,
  }) {
    //  Cannot change founder
    if (target.role == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تعديل رتبة المؤسس.",
      );
    }

    //  Permission check
    if (!canModify(
      actorRole: actor.role,
      targetRole: target.role,
    )) {
      return RoleAssignmentResult.denied(
        "لا تملك صلاحية تعديل هذه الرتبة.",
      );
    }

    //  Cannot assign founder manually
    if (newRole == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تعيين مؤسس جديد.",
      );
    }

    //  Check limited role capacity
    if (newRole.isLimited) {
      final currentCount = allMembers
          .where((m) => m.role == newRole)
          .length;

      if (currentCount >= (newRole.maxCount ?? 0)) {
        return RoleAssignmentResult.denied(
          "تم الوصول إلى الحد الأقصى لهذه الرتبة.",
        );
      }
    }

    final updated = target.copyWith(role: newRole);

    return RoleAssignmentResult.allowed(updated);
  }


  // Demote Member

  static RoleAssignmentResult demote({
    required MemberModel actor,
    required MemberModel target,
  }) {
    if (target.role == Roles.founder) {
      return RoleAssignmentResult.denied(
        "لا يمكن تخفيض رتبة المؤسس.",
      );
    }

    if (!canModify(
      actorRole: actor.role,
      targetRole: target.role,
    )) {
      return RoleAssignmentResult.denied(
        "لا تملك صلاحية تخفيض هذه الرتبة.",
      );
    }

    final updated = target.copyWith(
      role: Roles.member,
    );

    return RoleAssignmentResult.allowed(updated);
  }


  // Get Members by Hierarchy

  static List<MemberModel> sortByHierarchy(
      List<MemberModel> members) {
    final sorted = [...members];

    sorted.sort((a, b) {
      return b.role.rankLevel
          .compareTo(a.role.rankLevel);
    });

    return sorted;
  }
}