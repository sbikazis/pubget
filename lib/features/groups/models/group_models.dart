export 'pubget_rank.dart';

import 'pubget_rank.dart';

enum GroupType { public, animeRoleplay, openRoleplay }

enum JoinPolicy { open, approval, inviteOnly }

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
    this.risingScore = 0,
    this.risingEligible = false,
    this.isPromoted = false,
    this.imageUrl,
    this.coverUrl,
    this.lastActivityAt,
    this.viewerLastReadAt,
    this.promotionExpiresAt,
    this.activityMetrics,
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
  final num risingScore;
  final bool risingEligible;
  final bool isPromoted;
  final String? imageUrl;
  final String? coverUrl;
  final DateTime? lastActivityAt;
  final DateTime? viewerLastReadAt;
  final DateTime? promotionExpiresAt;
  final GroupActivityMetrics? activityMetrics;

  bool get isFull => membersCount >= maxMembers;

  bool get hasCompleteProfile {
    final image = imageUrl?.trim() ?? '';
    return image.isNotEmpty &&
        description.trim().isNotEmpty &&
        rules.trim().isNotEmpty;
  }

  List<GroupRisingGap> get risingGaps {
    final gaps = <GroupRisingGap>[];
    if (membersCount < 2) gaps.add(GroupRisingGap.members);
    if ((imageUrl ?? '').trim().isEmpty) gaps.add(GroupRisingGap.image);
    if (description.trim().isEmpty) gaps.add(GroupRisingGap.description);
    if (rules.trim().isEmpty) gaps.add(GroupRisingGap.rules);
    if (activityScore <= 0 && risingScore <= 0) {
      gaps.add(GroupRisingGap.activity);
    }
    return gaps;
  }

  List<String> get ruleItems => rules
      .split(RegExp(r'\r?\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  /// Unread from existing group `lastMessageAt` vs member `lastReadAt`.
  bool get hasUnread {
    final last = lastActivityAt;
    if (last == null) return false;
    final readAt = viewerLastReadAt;
    if (readAt == null) return true;
    return last.isAfter(readAt);
  }

  Group copyWith({
    String? name,
    String? description,
    String? rules,
    JoinPolicy? joinPolicy,
    bool? isSearchable,
    int? membersCount,
    bool? risingEligible,
    bool? isPromoted,
    DateTime? promotionExpiresAt,
    GroupActivityMetrics? activityMetrics,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type,
      animeId: animeId,
      founderId: founderId,
      membersCount: membersCount ?? this.membersCount,
      maxMembers: maxMembers,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      isSearchable: isSearchable ?? this.isSearchable,
      createdAt: createdAt,
      chatBackgroundUrl: chatBackgroundUrl,
      rules: rules ?? this.rules,
      activityScore: activityScore,
      risingScore: risingScore,
      risingEligible: risingEligible ?? this.risingEligible,
      isPromoted: isPromoted ?? this.isPromoted,
      imageUrl: imageUrl,
      coverUrl: coverUrl,
      lastActivityAt: lastActivityAt,
      viewerLastReadAt: viewerLastReadAt,
      promotionExpiresAt: promotionExpiresAt ?? this.promotionExpiresAt,
      activityMetrics: activityMetrics ?? this.activityMetrics,
    );
  }

  factory Group.fromMap(
    Map<String, dynamic> map, {
    required String id,
    DateTime? viewerLastReadAt,
  }) {
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
      risingScore: (map['risingScore'] as num?) ?? 0,
      risingEligible: map['risingEligible'] == true,
      isPromoted: map['isPromoted'] == true,
      imageUrl: map['imageUrl'] as String?,
      coverUrl: map['coverUrl'] as String?,
      lastActivityAt: _date(map['lastMessageAt']),
      viewerLastReadAt: viewerLastReadAt,
      promotionExpiresAt: _date(map['promotionExpiresAt']),
      activityMetrics: GroupActivityMetrics.fromMap(map['activityMetrics']),
    );
  }
}

enum GroupRisingGap { members, image, description, rules, activity }

final class GroupActivityMetrics {
  const GroupActivityMetrics({
    this.recentMessageCount = 0,
    this.activeMemberCount = 0,
    this.joinsInWindow = 0,
    this.scoreWindowDays = 7,
  });

  final int recentMessageCount;
  final int activeMemberCount;
  final int joinsInWindow;
  final int scoreWindowDays;

  static GroupActivityMetrics? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);
    int read(Object key) => (map[key] as num?)?.toInt() ?? 0;
    return GroupActivityMetrics(
      recentMessageCount: read('recentMessageCount'),
      activeMemberCount: read('activeMemberCount'),
      joinsInWindow: read('joinsInWindow'),
      scoreWindowDays: read('scoreWindowDays') == 0 ? 7 : read('scoreWindowDays'),
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
    this.rankChangedAt,
    this.inviteCount = 0,
    this.effectiveInviteCount = 0,
    this.warningsCount = 0,
    this.isManualRole = false,
    this.seatSource,
    this.invitedBy,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.lastActiveAt,
    this.lastReadAt,
    this.effectivePermissions,
  });

  final String uid;
  final PubgetRank role;
  final String? customRoleId;
  final Map<String, dynamic>? roleplayCharacter;
  final DateTime? joinedAt;

  /// When the member obtained their **current** rank (server: `rankChangedAt`).
  final DateTime? rankChangedAt;
  final int inviteCount;
  final int effectiveInviteCount;
  final int warningsCount;
  final bool isManualRole;
  final String? seatSource;
  final String? invitedBy;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime? lastActiveAt;
  final DateTime? lastReadAt;

  /// Permissions from the group role document, when loaded.
  /// `null` means fall back to [defaultRankPermissions] for [role].
  final Set<GroupPermission>? effectivePermissions;

  /// Seniority key for current rank — prefer rank assignment time.
  DateTime? get rankSeniorityAt => rankChangedAt ?? joinedAt;

  String? get roleplayName {
    final raw = roleplayCharacter?['name'] ?? roleplayCharacter?['characterName'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String get primaryIdentity {
    final rp = roleplayName;
    if (rp != null) return rp;
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return uid;
  }

  String? get secondaryIdentity {
    if (roleplayName == null) {
      final user = username?.trim();
      final display = displayName?.trim();
      if (user == null || user.isEmpty) return null;
      if (display == null || display.isEmpty) return null;
      if (display.toLowerCase() == user.toLowerCase()) return null;
      return '@$user';
    }
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return '@$user';
    return null;
  }

  String get roleDocumentId =>
      (customRoleId != null && customRoleId!.trim().isNotEmpty)
      ? customRoleId!.trim()
      : pubgetRankStorageId(role);

  /// Matches Cloud Functions `loadPermissions`: mikado always manages
  /// events; otherwise the role document (or default rank set) is used.
  bool get canManageEvents =>
      memberCanManageEvents(this, roleDocument: null);

  bool get canManageGames =>
      memberPermissions(this).contains(GroupPermission.manageGames);

  /// Client UX gate. Server `kickMember` / `banMember` remain authoritative.
  bool get canManageMembers => memberCanManageMembers(this);

  /// Client UX gate. Server `updateGroupSettings` remains authoritative.
  bool get canManageSettings => memberCanManageSettings(this);

  factory GroupMember.fromMap(Map<String, dynamic> map, {required String uid}) {
    final rankRaw = map['rankV2'] as String? ?? map['role'] as String?;
    return GroupMember(
      uid: uid,
      role: parsePubgetRank(rankRaw),
      customRoleId: map['customRoleId'] as String?,
      roleplayCharacter: map['roleplayCharacter'] is Map
          ? Map<String, dynamic>.from(map['roleplayCharacter'] as Map)
          : null,
      joinedAt: _date(map['joinedAt']),
      rankChangedAt: _date(map['rankChangedAt'] ?? map['rankAssignedAt']),
      inviteCount: (map['inviteCount'] as num?)?.toInt() ?? 0,
      effectiveInviteCount:
          (map['effectiveInviteCount'] as num?)?.toInt() ??
          (map['inviteCount'] as num?)?.toInt() ??
          0,
      warningsCount: (map['warningsCount'] as num?)?.toInt() ?? 0,
      isManualRole: map['isManualRole'] as bool? ?? false,
      seatSource: map['seatSource'] as String?,
      invitedBy: map['invitedBy'] as String? ?? map['invitedByUid'] as String?,
      displayName: map['displayName'] as String? ?? map['realUserName'] as String?,
      username: map['username'] as String?,
      avatarUrl:
          map['avatarUrl'] as String? ?? map['realUserImageUrl'] as String?,
      lastActiveAt: _date(map['lastActiveAt']),
      lastReadAt: _date(map['lastReadAt']),
    );
  }

  GroupMember copyWith({
    PubgetRank? role,
    String? customRoleId,
    Map<String, dynamic>? roleplayCharacter,
    DateTime? joinedAt,
    DateTime? rankChangedAt,
    int? inviteCount,
    int? effectiveInviteCount,
    int? warningsCount,
    bool? isManualRole,
    String? seatSource,
    String? invitedBy,
    String? displayName,
    String? username,
    String? avatarUrl,
    DateTime? lastActiveAt,
    DateTime? lastReadAt,
    Set<GroupPermission>? effectivePermissions,
  }) {
    return GroupMember(
      uid: uid,
      role: role ?? this.role,
      customRoleId: customRoleId ?? this.customRoleId,
      roleplayCharacter: roleplayCharacter ?? this.roleplayCharacter,
      joinedAt: joinedAt ?? this.joinedAt,
      rankChangedAt: rankChangedAt ?? this.rankChangedAt,
      inviteCount: inviteCount ?? this.inviteCount,
      effectiveInviteCount: effectiveInviteCount ?? this.effectiveInviteCount,
      warningsCount: warningsCount ?? this.warningsCount,
      isManualRole: isManualRole ?? this.isManualRole,
      seatSource: seatSource ?? this.seatSource,
      invitedBy: invitedBy ?? this.invitedBy,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      effectivePermissions: effectivePermissions ?? this.effectivePermissions,
    );
  }

  GroupMember withEffectivePermissions(Set<GroupPermission> permissions) =>
      copyWith(effectivePermissions: permissions);

  GroupMember withProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
  }) =>
      copyWith(
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

Set<GroupPermission> memberPermissions(
  GroupMember? member, {
  GroupRoleDefinition? roleDocument,
}) {
  if (member == null) return const <GroupPermission>{};
  return roleDocument?.permissions ??
      member.effectivePermissions ??
      permissionsForRank(member.role);
}

bool memberCanCreateEvents(GroupMember? member) => member != null;

/// Client mirror of server event-management authorization. Server remains
/// authoritative; this is UX gating only.
bool memberCanManageEvents(
  GroupMember? member, {
  GroupRoleDefinition? roleDocument,
}) {
  if (member == null) return false;
  if (member.role == PubgetRank.mikado) return true;
  return memberPermissions(
    member,
    roleDocument: roleDocument,
  ).contains(GroupPermission.manageEvents);
}

/// Client mirror of server member-management authorization. Server remains
/// authoritative; this is UX gating only.
bool memberCanManageMembers(GroupMember? member) {
  if (member == null) return false;
  if (member.role == PubgetRank.mikado) return true;
  return memberPermissions(member).contains(GroupPermission.kickBan);
}

/// Client mirror of server settings authorization. Server remains
/// authoritative; this is UX gating only. Mikado always manages settings.
bool memberCanManageSettings(GroupMember? member) {
  if (member == null) return false;
  if (member.role == PubgetRank.mikado) return true;
  return memberPermissions(member).contains(GroupPermission.manageSettings);
}

final class GroupRoleDefinition {
  const GroupRoleDefinition({
    required this.id,
    required this.name,
    required this.permissions,
    required this.position,
  });

  final String id;
  final PubgetRank name;
  final Set<GroupPermission> permissions;
  final int position;

  factory GroupRoleDefinition.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final permissions = <GroupPermission>{};
    final rawPermissions = map['permissions'] is List
        ? (map['permissions'] as List)
        : const <dynamic>[];
    for (final value in rawPermissions.whereType<String>()) {
      final parsed = parseGroupPermission(value);
      if (parsed != null) permissions.add(parsed);
    }
    return GroupRoleDefinition(
      id: id,
      name: parsePubgetRank(map['name'] as String? ?? id),
      permissions: permissions,
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }
}

final class GroupBan {
  const GroupBan({
    required this.uid,
    this.bannedByUid,
    this.createdAt,
    this.lastRole,
    this.reason,
  });

  final String uid;
  final String? bannedByUid;
  final DateTime? createdAt;
  final PubgetRank? lastRole;
  final String? reason;

  factory GroupBan.fromMap(Map<String, dynamic> map, {required String uid}) =>
      GroupBan(
        uid: uid,
        bannedByUid: map['bannedByUid'] as String?,
        createdAt: _date(map['createdAt']),
        lastRole: map['lastRole'] == null
            ? null
            : parsePubgetRank(map['lastRole'] as String?),
        reason: map['reason'] as String?,
      );
}

final class JoinRequest {
  const JoinRequest({
    required this.uid,
    required this.status,
    required this.requestedAt,
    this.invitedBy,
    this.characterReason = '',
    this.character,
  });

  final String uid;
  final String status;
  final DateTime? requestedAt;
  final String? invitedBy;
  final String characterReason;
  final RoleplayCharacter? character;

  factory JoinRequest.fromMap(
    Map<String, dynamic> map, {
    required String uid,
  }) {
    final raw = map['roleplayCharacter'];
    return JoinRequest(
      uid: uid,
      status: map['status'] as String? ?? 'pending',
      requestedAt: _date(map['requestedAt']),
      invitedBy: map['invitedBy'] as String?,
      characterReason: map['characterReason'] as String? ?? '',
      character: raw is Map
          ? RoleplayCharacter.fromMap(Map<String, dynamic>.from(raw))
          : null,
    );
  }
}

final class RoleplayCharacter {
  const RoleplayCharacter({
    required this.key,
    required this.name,
    required this.avatarUrl,
    this.reserved = false,
  });

  final String key;
  final String name;
  final String avatarUrl;
  final bool reserved;

  factory RoleplayCharacter.fromMap(Map<String, dynamic> map, {String? key}) {
    return RoleplayCharacter(
      key: key ?? map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      reserved: map['reserved'] as bool? ?? false,
    );
  }

  RoleplayCharacter asReserved() => RoleplayCharacter(
    key: key,
    name: name,
    avatarUrl: avatarUrl,
    reserved: true,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    'name': name,
    'avatarUrl': avatarUrl,
  };
}

final class GroupJoinPayload {
  const GroupJoinPayload({
    this.invitedBy,
    this.acceptedRules = false,
    this.character,
    this.characterReason,
  });

  final String? invitedBy;
  final bool acceptedRules;
  final RoleplayCharacter? character;
  final String? characterReason;

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (invitedBy != null && invitedBy!.trim().isNotEmpty)
      'invitedBy': invitedBy!.trim(),
    if (characterReason != null && characterReason!.trim().isNotEmpty)
      'characterReason': characterReason!.trim(),
    if (character != null) ...<String, dynamic>{
      'characterKey': character!.key,
      'character': character!.toMap(),
    },
  };
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

String groupJoinPolicyLabel(JoinPolicy policy) => switch (policy) {
  JoinPolicy.open => 'Open join',
  JoinPolicy.approval => 'Request to join',
  JoinPolicy.inviteOnly => 'Invite only',
};

String groupRoleLabel(PubgetRank role) => pubgetRankDisplayName(role);

List<PubgetRank> assignableRanksUnderCeiling({
  required PubgetRank actor,
  required PubgetRank targetCurrent,
}) {
  return PubgetRank.values
      .where(
        (desired) => canAssignRank(
          actor: actor,
          targetCurrent: targetCurrent,
          desired: desired,
        ),
      )
      .toList(growable: false);
}

int compareMembersByRankThenJoined(GroupMember a, GroupMember b) {
  final byRank = b.role.index.compareTo(a.role.index);
  if (byRank != 0) return byRank;
  // Within the same rank: seniority ascending (oldest current-rank first).
  final aSeniority = a.rankSeniorityAt;
  final bSeniority = b.rankSeniorityAt;
  if (aSeniority == null && bSeniority == null) return a.uid.compareTo(b.uid);
  if (aSeniority == null) return 1;
  if (bSeniority == null) return -1;
  final bySeniority = aSeniority.compareTo(bSeniority);
  if (bySeniority != 0) return bySeniority;
  return a.uid.compareTo(b.uid);
}
