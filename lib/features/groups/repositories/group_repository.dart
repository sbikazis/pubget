import '../../../core/errors/result.dart';
import '../models/group_models.dart';

final class GroupDraft {
  const GroupDraft({
    required this.name,
    required this.description,
    required this.type,
    required this.animeId,
    required this.joinPolicy,
    required this.isSearchable,
    required this.rules,
    required this.maxMembers,
    this.imageUrl,
    this.coverUrl,
    this.character,
    this.idempotencyKey,
  });

  final String name;
  final String description;
  final GroupType type;
  final String? animeId;
  final JoinPolicy joinPolicy;
  final bool isSearchable;
  final String rules;
  final int maxMembers;
  final String? imageUrl;
  final String? coverUrl;
  final RoleplayCharacter? character;
  final String? idempotencyKey;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name.trim(),
    'description': description.trim(),
    'type': type.name,
    'animeId': animeId,
    'joinPolicy': joinPolicy.name,
    'isSearchable': isSearchable,
    'rules': rules.trim(),
    'maxMembers': maxMembers,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    if (character != null) ...<String, dynamic>{
      'characterKey': character!.key,
      'character': character!.toMap(),
    },
  };
}

/// Fields accepted by the `updateGroupSettings` callable. No extras.
final class GroupSettingsUpdate {
  const GroupSettingsUpdate({
    required this.name,
    required this.description,
    required this.rules,
    required this.joinPolicy,
    required this.isSearchable,
  });

  final String name;
  final String description;
  final String rules;
  final JoinPolicy joinPolicy;
  final bool isSearchable;

  Map<String, dynamic> toMap({required String groupId}) => <String, dynamic>{
    'groupId': groupId,
    'name': name.trim(),
    'description': description.trim(),
    'rules': rules.trim(),
    'joinPolicy': joinPolicy.name,
    'isSearchable': isSearchable,
  };
}

abstract interface class GroupRepository {
  Future<Result<Group>> createGroup(GroupDraft draft);
  Future<Result<Group>> getGroup(String groupId);
  Future<Result<GroupMember?>> getMembership(String groupId, String userId);
  Future<Result<List<Group>>> searchGroups(String query);
  Future<Result<List<Group>>> listJoinedGroups(String userId);
  Stream<Result<List<Group>>> watchJoinedGroups(String userId);
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
    GroupJoinPayload? join,
  });
  Future<Result<void>> requestToJoin({
    required String groupId,
    GroupJoinPayload? join,
  });
  Future<Result<bool>> isBanned({
    required String groupId,
    required String userId,
  });
  Future<Result<bool>> hasPendingRequest({
    required String groupId,
    required String userId,
  });
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(String groupId);
  Future<Result<void>> leaveGroup(String groupId);
  Future<Result<void>> disbandGroup(String groupId);
  Future<Result<void>> updateGroupSettings({
    required String groupId,
    required GroupSettingsUpdate settings,
  });
  Future<Result<void>> promoteGroup(String groupId);
}
