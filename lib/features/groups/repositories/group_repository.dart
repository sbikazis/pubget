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
  });

  final String name;
  final String description;
  final GroupType type;
  final String? animeId;
  final JoinPolicy joinPolicy;
  final bool isSearchable;
  final String rules;
  final int maxMembers;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name.trim(),
    'description': description.trim(),
    'type': type.name,
    'animeId': animeId,
    'joinPolicy': joinPolicy.name,
    'isSearchable': isSearchable,
    'rules': rules.trim(),
    'maxMembers': maxMembers,
  };
}

abstract interface class GroupRepository {
  Future<Result<Group>> createGroup(GroupDraft draft);
  Future<Result<Group>> getGroup(String groupId);
  Future<Result<GroupMember?>> getMembership(String groupId, String userId);
  Future<Result<List<Group>>> searchGroups(String query);
  Future<Result<List<Group>>> listJoinedGroups(String userId);
  Future<Result<void>> joinGroup({required String groupId, String? inviteId});
  Future<Result<void>> requestToJoin({required String groupId});
  Future<Result<void>> leaveGroup(String groupId);
  Future<Result<void>> disbandGroup(String groupId);
}
