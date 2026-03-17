import '../../models/member_model.dart';
import '../../models/invite_model.dart';
import '../constants/roles.dart';

class InviteRankingLogic {
  InviteRankingLogic._();

  /// Returns updated members list with correct Senpai assignment
  static List<MemberModel> applyInviteRanking({
    required List<MemberModel> members,
    required List<InviteModel> invites,
  }) {
    //  Map invite count per user
    final Map<String, int> inviteCount = {};

    for (final invite in invites) {
      inviteCount.update(
        invite.invitedByUserId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    //  Filter eligible members (only normal members)
    final eligibleMembers = members.where((member) {
      return member.role == Roles.member;
    }).toList();

    //  Sort by:
    // - Highest invite count
    // - Oldest join date (if tie)
    eligibleMembers.sort((a, b) {
      final aInvites = inviteCount[a.userId] ?? 0;
      final bInvites = inviteCount[b.userId] ?? 0;

      if (aInvites != bInvites) {
        return bInvites.compareTo(aInvites); // Descending
      }

      return a.joinedAt.compareTo(b.joinedAt); // Oldest first
    });

    //  Assign Senpai to top N
    final int maxSenpai = Roles.senpai.maxCount ?? 0;

    final Set<String> newSenpaiIds = eligibleMembers
        .take(maxSenpai)
        .map((e) => e.userId)
        .toSet();

    //  Update roles
    final List<MemberModel> updatedMembers = members.map((member) {
      if (member.role == Roles.founder ||
          member.role == Roles.sensei ||
          member.role == Roles.hakusho) {
        return member;
      }

      if (newSenpaiIds.contains(member.userId)) {
        return member.copyWith(role: Roles.senpai);
      }

      return member.copyWith(role: Roles.member);
    }).toList();

    return updatedMembers;
  }

  /// Get invite count for a specific user
  static int getUserInviteCount({
    required String userId,
    required List<InviteModel> invites,
  }) {
    return invites
        .where((invite) => invite.invitedByUserId == userId)
        .length;
  }

  /// Sort members by invite count (read-only)
  static List<MemberModel> sortByInvites({
    required List<MemberModel> members,
    required List<InviteModel> invites,
  }) {
    final Map<String, int> inviteCount = {};

    for (final invite in invites) {
      inviteCount.update(
        invite.invitedByUserId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final sorted = [...members];

    sorted.sort((a, b) {
      final aInvites = inviteCount[a.userId] ?? 0;
      final bInvites = inviteCount[b.userId] ?? 0;

      if (aInvites != bInvites) {
        return bInvites.compareTo(aInvites);
      }

      return a.joinedAt.compareTo(b.joinedAt);
    });

    return sorted;
  }
}