import 'package:flutter/material.dart';

import '../../../core/constants/rank_colors.dart';

/// Pubget MIKADO-edition group ranks (ordinal 0‥6).
/// Compare with [index] only — never by display name.
enum PubgetRank {
  ronin, // 🌙 RŌNIN
  gokenin, // 🔥 GOKENIN
  samurai, // ⚔️ SAMURAI
  hatamoto, // 🛡️ HATAMOTO
  daimyo, // 🏯 DAIMYŌ
  shogun, // 🪖 SHŌGUN (kabuto — never reuse SAMURAI swords)
  mikado, // 👑 MIKADO
}

/// Permissions from the MIKADO edition matrix (source of truth).
enum GroupPermission {
  invite,
  pinOwnMessages,
  promoteContent,
  manageRequests,
  manageEvents,
  moderateChat,
  deleteMessages,
  manageGames,
  kickBan,
  unban,
  manageBackground,
  manageSettings,
  manageRoles,
}

/// Seat caps per rank (manual + auto). RŌNIN is unlimited.
final class RankSeatConfig {
  const RankSeatConfig({
    required this.total,
    required this.manual,
    required this.auto,
  });

  final int total;
  final int manual;
  final int auto;
}

const Map<PubgetRank, RankSeatConfig> rankSeatConfig =
    <PubgetRank, RankSeatConfig>{
      PubgetRank.mikado: RankSeatConfig(total: 1, manual: 1, auto: 0),
      PubgetRank.shogun: RankSeatConfig(total: 1, manual: 1, auto: 0),
      PubgetRank.daimyo: RankSeatConfig(total: 3, manual: 2, auto: 1),
      PubgetRank.hatamoto: RankSeatConfig(total: 4, manual: 3, auto: 1),
      PubgetRank.samurai: RankSeatConfig(total: 5, manual: 4, auto: 1),
      PubgetRank.gokenin: RankSeatConfig(total: 6, manual: 5, auto: 1),
      PubgetRank.ronin: RankSeatConfig(total: -1, manual: -1, auto: 0),
    };

/// Auto-seat ranks, highest first (DAIMYŌ → GOKENIN).
const List<PubgetRank> autoSeatRanks = <PubgetRank>[
  PubgetRank.daimyo,
  PubgetRank.hatamoto,
  PubgetRank.samurai,
  PubgetRank.gokenin,
];

final Map<PubgetRank, Set<GroupPermission>> defaultRankPermissions =
    <PubgetRank, Set<GroupPermission>>{
      PubgetRank.ronin: const <GroupPermission>{},
      PubgetRank.gokenin: <GroupPermission>{GroupPermission.invite},
      PubgetRank.samurai: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
      },
      PubgetRank.hatamoto: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
      },
      PubgetRank.daimyo: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
        GroupPermission.manageGames,
        GroupPermission.kickBan,
        GroupPermission.manageBackground,
      },
      PubgetRank.shogun: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
        GroupPermission.manageGames,
        GroupPermission.kickBan,
        GroupPermission.unban,
        GroupPermission.manageBackground,
        GroupPermission.manageSettings,
        GroupPermission.manageRoles,
      },
      PubgetRank.mikado: GroupPermission.values.toSet(),
    };

/// Highest rank [actor] may assign. Null = cannot manage roles.
PubgetRank? roleAssignmentCeiling(PubgetRank actor) {
  return switch (actor) {
    PubgetRank.mikado => PubgetRank.shogun,
    PubgetRank.shogun => PubgetRank.daimyo,
    _ => null,
  };
}

bool canAssignRank({
  required PubgetRank actor,
  required PubgetRank targetCurrent,
  required PubgetRank desired,
}) {
  final ceiling = roleAssignmentCeiling(actor);
  if (ceiling == null) return false;
  if (desired == PubgetRank.mikado) return false;
  if (desired.index > ceiling.index) return false;
  if (targetCurrent.index >= actor.index) return false;
  if (desired.index >= actor.index) return false;
  return true;
}

/// Legacy role string → [PubgetRank]. Corrupt/unknown → RŌNIN (fail-safe).
PubgetRank parsePubgetRank(String? raw) {
  final key = (raw ?? '').trim().toLowerCase();
  if (key.isEmpty) return PubgetRank.ronin;
  switch (key) {
    case 'ronin':
    case 'member':
      return PubgetRank.ronin;
    case 'gokenin':
    case 'senpai':
      return PubgetRank.gokenin;
    case 'samurai':
    case 'sensei':
      return PubgetRank.samurai;
    case 'hatamoto':
    case 'captain':
      return PubgetRank.hatamoto;
    case 'daimyo':
    case 'daimyō':
    case 'commander':
      return PubgetRank.daimyo;
    case 'shogun':
    case 'shōgun':
      return PubgetRank.shogun;
    case 'mikado':
    case 'founder':
      return PubgetRank.mikado;
    default:
      for (final rank in PubgetRank.values) {
        if (rank.name == key) return rank;
      }
      return PubgetRank.ronin;
  }
}

String pubgetRankStorageId(PubgetRank rank) => rank.name;

String pubgetRankDisplayName(PubgetRank rank) => switch (rank) {
  PubgetRank.ronin => 'RŌNIN',
  PubgetRank.gokenin => 'GOKENIN',
  PubgetRank.samurai => 'SAMURAI',
  PubgetRank.hatamoto => 'HATAMOTO',
  PubgetRank.daimyo => 'DAIMYŌ',
  PubgetRank.shogun => 'SHŌGUN',
  PubgetRank.mikado => 'MIKADO',
};

String pubgetRankEmoji(PubgetRank rank) => switch (rank) {
  PubgetRank.ronin => '🌙',
  PubgetRank.gokenin => '🔥',
  PubgetRank.samurai => '⚔️',
  PubgetRank.hatamoto => '🛡️',
  PubgetRank.daimyo => '🏯',
  PubgetRank.shogun => '🪖',
  PubgetRank.mikado => '👑',
};

String? pubgetRankBadgeAsset(PubgetRank rank) =>
    RankColors.assetForKey(rank.name);

/// Core badge color (aligned with [RankColors.nameColor]).
Color pubgetRankCoreColor(PubgetRank rank) =>
    RankColors.colorForKey(rank.name);

/// Central resolver — never persist these colors.
/// Uses the fixed MIKADO-edition palette (not theme purple).
Color rankColorResolver(PubgetRank rank, {required bool isDarkMode}) {
  return RankColors.colorForKey(rank.name);
}

Color rankColorForRoleString(String? role, {required bool isDarkMode}) =>
    rankColorResolver(parsePubgetRank(role), isDarkMode: isDarkMode);

/// Chat bubbles always show the rank badge (own = badge only; others = name + badge).
bool rankShowsBubbleBadge(PubgetRank rank) => true;

/// Soft glow strength for rank badges in chat (0.12‥0.90 by ladder progress).
double rankBadgeGlowStrength(PubgetRank rank) {
  final t = rank.index / PubgetRank.mikado.index; // 0‥1
  return 0.12 + (t * 0.78);
}

/// Glow / highlight color for the badge.
Color rankBadgeGlowColor(PubgetRank rank) => switch (rank) {
  PubgetRank.shogun => RankColors.shogunGold,
  PubgetRank.mikado => const Color(0xFF7A1FFF),
  _ => RankColors.colorForKey(rank.name),
};

/// Username style (MIKADO glow included).
TextStyle pubgetRankNameTextStyle(
  PubgetRank rank, {
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w700,
  double height = 1.15,
}) =>
    RankColors.nameTextStyleForKey(
      rank.name,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );

bool rankHasAdminEntryHub(PubgetRank rank) =>
    rank.index >= PubgetRank.gokenin.index;

bool rankUsesFullDashboard(PubgetRank rank) =>
    rank.index >= PubgetRank.hatamoto.index;

Set<GroupPermission> permissionsForRank(PubgetRank rank) =>
    defaultRankPermissions[rank] ?? const <GroupPermission>{};

bool rankHasPermission(PubgetRank rank, GroupPermission permission) =>
    permissionsForRank(rank).contains(permission);

/// Normalize legacy permission keys from Firestore role docs.
GroupPermission? parseGroupPermission(String raw) {
  switch (raw.trim()) {
    case 'invite':
      return GroupPermission.invite;
    case 'pinOwnMessages':
    case 'pin':
      return GroupPermission.pinOwnMessages;
    case 'promoteContent':
      return GroupPermission.promoteContent;
    case 'manageRequests':
      return GroupPermission.manageRequests;
    case 'manageEvents':
      return GroupPermission.manageEvents;
    case 'moderateChat':
    case 'manageMessages':
      return GroupPermission.moderateChat;
    case 'deleteMessages':
      return GroupPermission.deleteMessages;
    case 'manageGames':
      return GroupPermission.manageGames;
    case 'kickBan':
    case 'manageMembers':
      return GroupPermission.kickBan;
    case 'unban':
      return GroupPermission.unban;
    case 'manageBackground':
      return GroupPermission.manageBackground;
    case 'manageSettings':
      return GroupPermission.manageSettings;
    case 'manageRoles':
      return GroupPermission.manageRoles;
    default:
      return null;
  }
}

/// Dashboard tabs derived from live permissions (no empty shells).
enum RankDashboardTab {
  invite,
  pinnedContent,
  members,
  requests,
  events,
  games,
  bans,
  background,
  settings,
  roles,
  audit,
  chat,
}

List<RankDashboardTab> dashboardTabsFor(Set<GroupPermission> permissions) {
  final tabs = <RankDashboardTab>[];
  if (permissions.contains(GroupPermission.invite)) {
    tabs.add(RankDashboardTab.invite);
  }
  if (permissions.contains(GroupPermission.promoteContent) ||
      permissions.contains(GroupPermission.pinOwnMessages)) {
    tabs.add(RankDashboardTab.pinnedContent);
  }
  if (permissions.contains(GroupPermission.kickBan) ||
      permissions.contains(GroupPermission.manageRoles)) {
    tabs.add(RankDashboardTab.members);
  }
  if (permissions.contains(GroupPermission.manageRequests)) {
    tabs.add(RankDashboardTab.requests);
  }
  if (permissions.contains(GroupPermission.manageEvents)) {
    tabs.add(RankDashboardTab.events);
  }
  if (permissions.contains(GroupPermission.manageGames)) {
    tabs.add(RankDashboardTab.games);
  }
  if (permissions.contains(GroupPermission.unban) ||
      permissions.contains(GroupPermission.kickBan)) {
    tabs.add(RankDashboardTab.bans);
  }
  if (permissions.contains(GroupPermission.manageBackground)) {
    tabs.add(RankDashboardTab.background);
  }
  if (permissions.contains(GroupPermission.manageSettings)) {
    tabs.add(RankDashboardTab.settings);
  }
  if (permissions.contains(GroupPermission.manageRoles)) {
    tabs.add(RankDashboardTab.roles);
    tabs.add(RankDashboardTab.audit);
  }
  tabs.add(RankDashboardTab.chat);
  return tabs;
}
