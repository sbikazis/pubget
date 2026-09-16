import '../../../core/errors/result.dart';
import '../models/group_authority.dart';
import '../models/group_models.dart';

abstract interface class GroupMembersRepository {
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  });

  Future<Result<List<JoinRequest>>> getJoinRequests(String groupId);
  Future<Result<List<GroupRoleDefinition>>> getRoles(String groupId);
  Future<Result<String>> createInvite({
    required String groupId,
    required String toUid,
  });
  Future<Result<void>> updateRolePermissions({
    required String groupId,
    required PubgetRank role,
    required Set<GroupPermission> permissions,
  });
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required PubgetRank role,
  });
  Future<Result<void>> kickMember({
    required String groupId,
    required String uid,
  });
  Future<Result<void>> banMember({
    required String groupId,
    required String uid,
  });
  Future<Result<String>> prepareOwnershipTransfer({
    required String groupId,
    required String uid,
  });
  Future<Result<void>> transferOwnership({
    required String groupId,
    required String uid,
    required String confirmationToken,
  });
  Future<Result<void>> acceptJoinRequest({
    required String groupId,
    required String uid,
  });
  Future<Result<void>> rejectJoinRequest({
    required String groupId,
    required String uid,
  });
  Future<Result<List<GroupBan>>> getBans(String groupId);
  Future<Result<void>> unbanMember({
    required String groupId,
    required String uid,
  });
  Future<Result<void>> warnMember({
    required String groupId,
    required String uid,
    required String type,
    required String details,
  });
  Future<Result<List<RankAuditEvent>>> getRankAudit(
    String groupId, {
    String? targetUid,
    int limit = 40,
  });
  Future<Result<List<MemberWarningRecord>>> getWarnings(
    String groupId, {
    required String targetUid,
    int limit = 40,
  });
  Future<Result<List<GroupMember>>> lookupInviteCandidates({
    required String query,
    int limit = 12,
  });
}
