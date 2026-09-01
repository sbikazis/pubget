enum GroupType { public, animeRoleplay, openRoleplay }

enum JoinPolicy { open, approval, inviteOnly }

enum GroupRole { founder, shogun, commander, captain, sensei, senpai, member }

enum GroupPermission {
  manageMembers,
  manageMessages,
  deleteMessages,
  pin,
  manageEvents,
  manageGames,
  manageSettings,
  invite,
  manageRequests,
  manageRoles,
  manageBackground,
}

final class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.animeId,
    required this.founderId,
    required this.membersCount,
    required this.maxMembers,
    required this.joinPolicy,
    required this.isSearchable,
    required this.createdAt,
    required this.chatBackgroundUrl,
    required this.rules,
    required this.activityScore,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final GroupType type;
  final String? animeId;
  final String founderId;
  final int membersCount;
  final int maxMembers;
  final JoinPolicy joinPolicy;
  final bool isSearchable;
  final DateTime? createdAt;
  final String? chatBackgroundUrl;
  final String rules;
  final num activityScore;
  final String? imageUrl;

  bool get isFull => membersCount >= maxMembers;

  factory Group.fromMap(Map<String, dynamic> map, {required String id}) {
    final createdAt = map['createdAt'];
    return Group(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: GroupType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => GroupType.public,
      ),
      animeId: map['animeId'] as String?,
      founderId: map['founderId'] as String? ?? '',
      membersCount: (map['membersCount'] as num?)?.toInt() ?? 0,
      maxMembers: (map['maxMembers'] as num?)?.toInt() ?? 100,
      joinPolicy: JoinPolicy.values.firstWhere(
        (value) => value.name == map['joinPolicy'],
        orElse: () => JoinPolicy.open,
      ),
      isSearchable: map['isSearchable'] as bool? ?? true,
      createdAt: _date(createdAt),
      chatBackgroundUrl: map['chatBackgroundUrl'] as String?,
      rules: map['rules'] as String? ?? '',
      activityScore: (map['activityScore'] as num?) ?? 0,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

final class GroupMember {
  const GroupMember({
    required this.uid,
    required this.role,
    this.customRoleId,
    this.roleplayCharacter,
    this.joinedAt,
    this.inviteCount = 0,
    this.lastActiveAt,
  });

  final String uid;
  final GroupRole role;
  final String? customRoleId;
  final Map<String, dynamic>? roleplayCharacter;
  final DateTime? joinedAt;
  final int inviteCount;
  final DateTime? lastActiveAt;

  factory GroupMember.fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupMember(
      uid: uid,
      role: GroupRole.values.firstWhere(
        (value) => value.name == map['role'],
        orElse: () => GroupRole.member,
      ),
      customRoleId: map['customRoleId'] as String?,
      roleplayCharacter: map['roleplayCharacter'] is Map
          ? Map<String, dynamic>.from(map['roleplayCharacter'] as Map)
          : null,
      joinedAt: _date(map['joinedAt']),
      inviteCount: (map['inviteCount'] as num?)?.toInt() ?? 0,
      lastActiveAt: _date(map['lastActiveAt']),
    );
  }
}

final class GroupRoleDefinition {
  const GroupRoleDefinition({
    required this.id,
    required this.name,
    required this.permissions,
    required this.position,
  });

  final String id;
  final GroupRole name;
  final Set<GroupPermission> permissions;
  final int position;

  factory GroupRoleDefinition.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return GroupRoleDefinition(
      id: id,
      name: GroupRole.values.firstWhere(
        (value) => value.name == map['name'],
        orElse: () => GroupRole.member,
      ),
      permissions:
          (map['permissions'] is List
                  ? (map['permissions'] as List)
                  : const <dynamic>[])
              .whereType<String>()
              .map(
                (value) => GroupPermission.values.firstWhere(
                  (permission) => permission.name == value,
                  orElse: () => GroupPermission.invite,
                ),
              )
              .toSet(),
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }
}

final class JoinRequest {
  const JoinRequest({
    required this.uid,
    required this.status,
    required this.requestedAt,
  });

  final String uid;
  final String status;
  final DateTime? requestedAt;

  factory JoinRequest.fromMap(
    Map<String, dynamic> map, {
    required String uid,
  }) => JoinRequest(
    uid: uid,
    status: map['status'] as String? ?? 'pending',
    requestedAt: _date(map['requestedAt']),
  );
}

final class RoleplayCharacter {
  const RoleplayCharacter({
    required this.key,
    required this.name,
    required this.avatarUrl,
  });

  final String key;
  final String name;
  final String avatarUrl;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

String groupRoleLabel(GroupRole role) => switch (role) {
  GroupRole.founder => 'Founder',
  GroupRole.shogun => 'Shogun',
  GroupRole.commander => 'Commander',
  GroupRole.captain => 'Captain',
  GroupRole.sensei => 'Sensei',
  GroupRole.senpai => 'Senpai',
  GroupRole.member => 'Member',
};
