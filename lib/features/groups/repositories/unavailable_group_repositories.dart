import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/group_models.dart';
import 'group_members_repository.dart';
import 'group_repository.dart';
import 'roleplay_repository.dart';

final class UnavailableGroupRepository implements GroupRepository {
  UnavailableGroupRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(NetworkError(message));

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => _fail();
  @override
  Future<Result<Group>> getGroup(String groupId) async => _fail();
  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => _fail();
  @override
  Future<Result<List<Group>>> searchGroups(String query) async => _fail();
  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async => _fail();
  @override
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
  }) async => _fail();
  @override
  Future<Result<void>> requestToJoin({required String groupId}) async =>
      _fail();
  @override
  Future<Result<void>> leaveGroup(String groupId) async => _fail();
  @override
  Future<Result<void>> disbandGroup(String groupId) async => _fail();
}

final class UnavailableGroupMembersRepository
    implements GroupMembersRepository {
  UnavailableGroupMembersRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(NetworkError(message));

  @override
  Future<Result<List<GroupMember>>> getMembers(
    String groupId, {
    int limit = 25,
    String? afterUid,
  }) async => _fail();
  @override
  Future<Result<List<JoinRequest>>> getJoinRequests(String groupId) async =>
      _fail();
  @override
  Future<Result<List<GroupRoleDefinition>>> getRoles(String groupId) async =>
      _fail();
  @override
  Future<Result<String>> createInvite({
    required String groupId,
    required String toUid,
  }) async => _fail();
  @override
  Future<Result<void>> updateRolePermissions({
    required String groupId,
    required GroupRole role,
    required Set<GroupPermission> permissions,
  }) async => _fail();
  @override
  Future<Result<void>> changeRole({
    required String groupId,
    required String uid,
    required GroupRole role,
  }) async => _fail();
  @override
  Future<Result<void>> kickMember({
    required String groupId,
    required String uid,
  }) async => _fail();
  @override
  Future<Result<void>> banMember({
    required String groupId,
    required String uid,
  }) async => _fail();
  @override
  Future<Result<String>> prepareOwnershipTransfer({
    required String groupId,
    required String uid,
  }) async => _fail();
  @override
  Future<Result<void>> transferOwnership({
    required String groupId,
    required String uid,
    required String confirmationToken,
  }) async => _fail();
  @override
  Future<Result<void>> acceptJoinRequest({
    required String groupId,
    required String uid,
  }) async => _fail();
  @override
  Future<Result<void>> rejectJoinRequest({
    required String groupId,
    required String uid,
  }) async => _fail();
}

final class UnavailableRoleplayRepository implements RoleplayRepository {
  UnavailableRoleplayRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(NetworkError(message));

  @override
  Future<Result<void>> reserveCharacter({
    required String groupId,
    required String characterKey,
    required RoleplayCharacter character,
  }) async => _fail();
  @override
  Future<Result<void>> releaseCharacter({
    required String groupId,
    required String characterKey,
  }) async => _fail();
  @override
  Future<Result<List<RoleplayCharacter>>> getAvailableCharacters(
    String groupId,
  ) async => _fail();
}
