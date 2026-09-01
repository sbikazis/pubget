import '../../../core/errors/result.dart';
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
    required GroupRole role,
    required Set<GroupPermission> permissions,
  });
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required GroupRole role,
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
}
