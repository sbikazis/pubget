import 'group_models.dart';
import 'pubget_rank.dart';

/// Centralized group authority — UI asks these helpers; Cloud Functions remain
/// the enforcement boundary. Never scatter `if (role == shogun)` in widgets.
abstract final class GroupAuthority {
  static bool has(
    GroupMember? actor,
    GroupPermission permission,
  ) {
    if (actor == null) return false;
    if (actor.role == PubgetRank.mikado) return true;
    return memberPermissions(actor).contains(permission);
  }

  static bool canInvite(GroupMember? actor) =>
      has(actor, GroupPermission.invite);

  static bool canManageRoles(GroupMember? actor) =>
      has(actor, GroupPermission.manageRoles);

  static bool canKickBan(GroupMember? actor) =>
      has(actor, GroupPermission.kickBan);

  static bool canUnban(GroupMember? actor) =>
      has(actor, GroupPermission.unban);

  static bool canModerateChat(GroupMember? actor) =>
      has(actor, GroupPermission.moderateChat);

  static bool canManageSettings(GroupMember? actor) =>
      has(actor, GroupPermission.manageSettings);

  static bool canManageEvents(GroupMember? actor) =>
      memberCanManageEvents(actor);

  static bool canManageGames(GroupMember? actor) =>
      has(actor, GroupPermission.manageGames);

  static bool canChangeChatBackground(GroupMember? actor) =>
      has(actor, GroupPermission.manageBackground);

  static bool canManageJoinRequests(GroupMember? actor) =>
      has(actor, GroupPermission.manageRequests);

  /// Warnings use chat-moderation authority (HATAMOTO+).
  static bool canWarn(GroupMember? actor) =>
      has(actor, GroupPermission.moderateChat);

  static bool canTransferOwnership({
    required GroupMember? actor,
    required String? founderId,
  }) {
    if (actor == null || founderId == null) return false;
    return actor.uid == founderId && actor.role == PubgetRank.mikado;
  }

  /// Actor may open the rank council for [target].
  static bool canManageTargetRank({
    required GroupMember? actor,
    required GroupMember target,
  }) {
    if (actor == null) return false;
    if (actor.uid == target.uid) return false;
    if (target.role == PubgetRank.mikado) return false;
    if (!canManageRoles(actor)) return false;
    if (target.role.index >= actor.role.index) return false;
    return assignableRanksUnderCeiling(
      actor: actor.role,
      targetCurrent: target.role,
    ).isNotEmpty;
  }

  static bool canKickOrBanTarget({
    required GroupMember? actor,
    required GroupMember target,
  }) {
    if (actor == null) return false;
    if (actor.uid == target.uid) return false;
    if (target.role == PubgetRank.mikado) return false;
    if (!canKickBan(actor)) return false;
    return actor.role.index > target.role.index;
  }

  static bool canWarnTarget({
    required GroupMember? actor,
    required GroupMember target,
  }) {
    if (actor == null) return false;
    if (actor.uid == target.uid) return false;
    if (target.role == PubgetRank.mikado) return false;
    if (!canWarn(actor)) return false;
    return actor.role.index > target.role.index;
  }

  static bool canViewBannedMembers(GroupMember? actor) =>
      canKickBan(actor) || canUnban(actor);

  static bool showsManagementChrome(GroupMember? actor) =>
      canInvite(actor) ||
      canManageRoles(actor) ||
      canKickBan(actor) ||
      canUnban(actor) ||
      canWarn(actor) ||
      canManageSettings(actor);

  /// Ranks strictly above [current] (never includes MIKADO).
  static List<PubgetRank> promotionDestinations(PubgetRank current) {
    if (current == PubgetRank.mikado || current == PubgetRank.shogun) {
      return const <PubgetRank>[];
    }
    return PubgetRank.values
        .where(
          (rank) =>
              rank.index > current.index && rank != PubgetRank.mikado,
        )
        .toList(growable: false);
  }

  /// Ranks strictly below [current].
  static List<PubgetRank> demotionDestinations(PubgetRank current) {
    if (current == PubgetRank.mikado || current == PubgetRank.ronin) {
      return const <PubgetRank>[];
    }
    return PubgetRank.values
        .where((rank) => rank.index < current.index)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  /// Destinations the [actor] may actually assign for [target].
  static List<PubgetRank> authorizedDestinations({
    required GroupMember actor,
    required GroupMember target,
    required bool promote,
  }) {
    final pool = promote
        ? promotionDestinations(target.role)
        : demotionDestinations(target.role);
    return pool
        .where(
          (desired) => canAssignRank(
            actor: actor.role,
            targetCurrent: target.role,
            desired: desired,
          ),
        )
        .toList(growable: false);
  }
}

/// Seat occupancy snapshot for the Rank Overview strip.
final class RankOccupancy {
  const RankOccupancy({
    required this.rank,
    required this.count,
    required this.capacity,
  });

  final PubgetRank rank;
  final int count;

  /// `null` = unlimited (RŌNIN).
  final int? capacity;

  bool get isUnlimited => capacity == null || capacity! < 0;

  bool get isFull => !isUnlimited && count >= capacity!;

  int? get remaining =>
      isUnlimited ? null : (capacity! - count).clamp(0, capacity!);

  String capacityLabel({required bool arabic}) {
    if (rank == PubgetRank.mikado) {
      return arabic ? 'مالك المجموعة — غير قابلة للتعيين' : 'Owner — not assignable';
    }
    if (isUnlimited) return arabic ? 'مفتوحة' : 'Open';
    if (isFull) return arabic ? 'ممتلئة' : 'Full';
    final left = remaining ?? 0;
    return arabic ? '$left مقاعد شاغرة' : '$left seats open';
  }

  String countLabel() {
    if (isUnlimited) return '$count';
    return '$count / $capacity';
  }
}

List<RankOccupancy> computeRankOccupancy(Iterable<GroupMember> members) {
  final counts = <PubgetRank, int>{
    for (final rank in PubgetRank.values) rank: 0,
  };
  for (final member in members) {
    counts[member.role] = (counts[member.role] ?? 0) + 1;
  }
  return PubgetRank.values
      .map((rank) {
        final config = rankSeatConfig[rank];
        final capacity = config == null || config.total < 0 ? null : config.total;
        return RankOccupancy(
          rank: rank,
          count: counts[rank] ?? 0,
          capacity: capacity,
        );
      })
      .toList(growable: false);
}

/// Short elegant subtitle for rank rows.
String pubgetRankSubtitle(PubgetRank rank, {required bool arabic}) {
  if (arabic) {
    return switch (rank) {
      PubgetRank.ronin => 'المسار والبداية',
      PubgetRank.gokenin => 'الختم واللهب',
      PubgetRank.samurai => 'السيف والزهر',
      PubgetRank.hatamoto => 'حملة الراية',
      PubgetRank.daimyo => 'القلاع والولاية',
      PubgetRank.shogun => 'القيادة العليا',
      PubgetRank.mikado => 'مالك المجموعة',
    };
  }
  return switch (rank) {
    PubgetRank.ronin => 'Path & beginning',
    PubgetRank.gokenin => 'Seal & flame',
    PubgetRank.samurai => 'Blade & sakura',
    PubgetRank.hatamoto => 'Banner bearers',
    PubgetRank.daimyo => 'Castle & domain',
    PubgetRank.shogun => 'High command',
    PubgetRank.mikado => 'Group owner',
  };
}

enum MemberWarningType {
  harassment,
  abuse,
  groupRules,
  inappropriateContent,
  chatMisuse,
  toxicBehavior,
  other,
}

String memberWarningTypeLabel(MemberWarningType type, {required bool arabic}) {
  if (arabic) {
    return switch (type) {
      MemberWarningType.harassment => 'إزعاج',
      MemberWarningType.abuse => 'إساءة',
      MemberWarningType.groupRules => 'مخالفة قوانين المجموعة',
      MemberWarningType.inappropriateContent => 'محتوى غير مناسب',
      MemberWarningType.chatMisuse => 'إساءة استخدام الدردشة',
      MemberWarningType.toxicBehavior => 'سلوك سام',
      MemberWarningType.other => 'أخرى',
    };
  }
  return switch (type) {
    MemberWarningType.harassment => 'Harassment',
    MemberWarningType.abuse => 'Abuse',
    MemberWarningType.groupRules => 'Group rules violation',
    MemberWarningType.inappropriateContent => 'Inappropriate content',
    MemberWarningType.chatMisuse => 'Chat misuse',
    MemberWarningType.toxicBehavior => 'Toxic behavior',
    MemberWarningType.other => 'Other',
  };
}

final class RankAuditEvent {
  const RankAuditEvent({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.targetUid,
    required this.byUid,
    this.at,
    this.reason,
  });

  final String id;
  final String type;
  final PubgetRank? from;
  final PubgetRank? to;
  final String targetUid;
  final String byUid;
  final DateTime? at;
  final String? reason;

  factory RankAuditEvent.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return RankAuditEvent(
      id: id,
      type: map['type'] as String? ?? 'manual_assign',
      from: map['from'] == null ? null : parsePubgetRank(map['from'] as String?),
      to: map['to'] == null ? null : parsePubgetRank(map['to'] as String?),
      targetUid: map['targetUid'] as String? ?? '',
      byUid: map['byUid'] as String? ?? '',
      at: _auditDate(map['at']),
      reason: map['reason'] as String?,
    );
  }
}

final class MemberWarningRecord {
  const MemberWarningRecord({
    required this.id,
    required this.targetUid,
    required this.byUid,
    required this.type,
    required this.details,
    this.createdAt,
  });

  final String id;
  final String targetUid;
  final String byUid;
  final String type;
  final String details;
  final DateTime? createdAt;

  factory MemberWarningRecord.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return MemberWarningRecord(
      id: id,
      targetUid: map['targetUid'] as String? ?? '',
      byUid: map['byUid'] as String? ?? '',
      type: map['type'] as String? ?? MemberWarningType.other.name,
      details: map['details'] as String? ?? '',
      createdAt: _auditDate(map['createdAt']),
    );
  }
}

DateTime? _auditDate(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
