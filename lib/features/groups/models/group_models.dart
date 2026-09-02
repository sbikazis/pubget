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

final Map<GroupRole, Set<GroupPermission>> defaultRolePermissions =
    <GroupRole, Set<GroupPermission>>{
      GroupRole.founder: GroupPermission.values.toSet(),
      GroupRole.shogun: GroupPermission.values.toSet(),
      GroupRole.commander: <GroupPermission>{
        GroupPermission.manageMembers,
        GroupPermission.manageMessages,
        GroupPermission.deleteMessages,
        GroupPermission.pin,
        GroupPermission.manageEvents,
        GroupPermission.manageGames,
        GroupPermission.invite,
        GroupPermission.manageRequests,
      },
      GroupRole.captain: <GroupPermission>{
        GroupPermission.manageMessages,
        GroupPermission.deleteMessages,
        GroupPermission.pin,
        GroupPermission.manageEvents,
        GroupPermission.invite,
      },
      GroupRole.sensei: <GroupPermission>{
        GroupPermission.manageMessages,
        GroupPermission.deleteMessages,
        GroupPermission.pin,
        GroupPermission.invite,
      },
      GroupRole.senpai: <GroupPermission>{
        GroupPermission.pin,
        GroupPermission.invite,
      },
      GroupRole.member: <GroupPermission>{},
    };

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
    this.lastActivityAt,
    this.promotionExpiresAt,
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
  final DateTime? lastActivityAt;
  final DateTime? promotionExpiresAt;

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
      lastActivityAt: _date(map['lastMessageAt']),
      promotionExpiresAt: _date(map['promotionExpiresAt']),
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
    this.effectivePermissions,
  });

  final String uid;
  final GroupRole role;
  final String? customRoleId;
  final Map<String, dynamic>? roleplayCharacter;
  final DateTime? joinedAt;
  final int inviteCount;
  final DateTime? lastActiveAt;

  /// Permissions from the group role document, when loaded.
  /// `null` means fall back to [defaultRolePermissions] for [role].
  final Set<GroupPermission>? effectivePermissions;

  String get roleDocumentId =>
      (customRoleId != null && customRoleId!.trim().isNotEmpty)
      ? customRoleId!.trim()
      : role.name;

  /// Matches Cloud Functions `loadPermissions`: founder always manages
  /// events; otherwise the role document (or default role set) is used.
  bool get canManageEvents =>
      memberCanManageEvents(this, roleDocument: null);

  bool get canManageGames =>
      defaultRolePermissions[role]?.contains(GroupPermission.manageGames) ??
      false;

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

  GroupMember withEffectivePermissions(Set<GroupPermission> permissions) =>
      GroupMember(
        uid: uid,
        role: role,
        customRoleId: customRoleId,
        roleplayCharacter: roleplayCharacter,
        joinedAt: joinedAt,
        inviteCount: inviteCount,
        lastActiveAt: lastActiveAt,
        effectivePermissions: permissions,
      );
}

/// Client mirror of server event-management authorization. Server remains
/// authoritative; this is UX gating only.
bool memberCanManageEvents(
  GroupMember? member, {
  GroupRoleDefinition? roleDocument,
}) {
  if (member == null) return false;
  if (member.role == GroupRole.founder) return true;
  final granted =
      roleDocument?.permissions ??
      member.effectivePermissions ??
      defaultRolePermissions[member.role] ??
      const <GroupPermission>{};
  return granted.contains(GroupPermission.manageEvents);
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
