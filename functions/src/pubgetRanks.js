"use strict";

/** Pubget MIKADO-edition ranks — ordinal index 0‥6 (compare by index only). */
const ROLES = Object.freeze([
  "ronin",
  "gokenin",
  "samurai",
  "hatamoto",
  "daimyo",
  "shogun",
  "mikado",
]);

const ROLE_POSITIONS = Object.freeze(
  Object.fromEntries(ROLES.map((role, index) => [role, index])),
);

const ROLE_PERMISSIONS = Object.freeze({
  ronin: [],
  gokenin: ["invite"],
  samurai: ["invite", "pinOwnMessages", "promoteContent"],
  hatamoto: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
  ],
  daimyo: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "manageBackground",
  ],
  shogun: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "unban", "manageBackground",
    "manageSettings", "manageRoles",
  ],
  mikado: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "unban", "manageBackground",
    "manageSettings", "manageRoles",
  ],
});

const SEAT_CONFIG = Object.freeze({
  mikado: { total: 1, manual: 1, auto: 0 },
  shogun: { total: 1, manual: 1, auto: 0 },
  daimyo: { total: 3, manual: 2, auto: 1 },
  hatamoto: { total: 4, manual: 3, auto: 1 },
  samurai: { total: 5, manual: 4, auto: 1 },
  gokenin: { total: 6, manual: 5, auto: 1 },
  ronin: { total: Infinity, manual: Infinity, auto: 0 },
});

/** Auto seats checked highest-first. */
const AUTO_SEAT_RANKS = Object.freeze([
  "daimyo", "hatamoto", "samurai", "gokenin",
]);

const LEGACY_ROLE_MAP = Object.freeze({
  founder: "mikado",
  shogun: "shogun",
  commander: "daimyo",
  captain: "hatamoto",
  sensei: "samurai",
  senpai: "gokenin",
  member: "ronin",
  mikado: "mikado",
  daimyo: "daimyo",
  hatamoto: "hatamoto",
  samurai: "samurai",
  gokenin: "gokenin",
  ronin: "ronin",
});

/** Permission aliases: legacy role-doc keys → canonical. */
const PERMISSION_ALIASES = Object.freeze({
  manageMembers: "kickBan",
  manageMessages: "moderateChat",
  pin: "pinOwnMessages",
  kickBan: "kickBan",
  moderateChat: "moderateChat",
  pinOwnMessages: "pinOwnMessages",
  invite: "invite",
  promoteContent: "promoteContent",
  manageRequests: "manageRequests",
  manageEvents: "manageEvents",
  deleteMessages: "deleteMessages",
  manageGames: "manageGames",
  unban: "unban",
  manageBackground: "manageBackground",
  manageSettings: "manageSettings",
  manageRoles: "manageRoles",
});

const EFFECTIVE_INVITE_MIN_MS = 24 * 60 * 60 * 1000;

function normalizeRole(raw) {
  if (typeof raw !== "string" || !raw.trim()) return "ronin";
  const key = raw.trim().toLowerCase();
  return LEGACY_ROLE_MAP[key] || (ROLES.includes(key) ? key : "ronin");
}

function normalizePermission(raw) {
  if (typeof raw !== "string") return null;
  return PERMISSION_ALIASES[raw] || null;
}

function roleDefinition(role) {
  const id = normalizeRole(role);
  return {
    name: id,
    permissions: ROLE_PERMISSIONS[id] || [],
    position: ROLE_POSITIONS[id] || 0,
    isDefault: true,
  };
}

function isApexOwner(member, group) {
  if (!member) return false;
  const role = normalizeRole(member.role || member.rankV2);
  if (role === "mikado") return true;
  if (group && group.founderId && member.uid && group.founderId === member.uid) {
    return true;
  }
  return false;
}

function permissionSet(roleDoc) {
  const raw = roleDoc && Array.isArray(roleDoc.permissions)
    ? roleDoc.permissions
    : [];
  const set = new Set();
  for (const item of raw) {
    const normalized = normalizePermission(item);
    if (normalized) set.add(normalized);
  }
  return set;
}

function hasPermission(member, roleDoc, permission, group) {
  if (!member) return false;
  if (isApexOwner(member, group)) return true;
  const wanted = normalizePermission(permission) || permission;
  const fromDoc = permissionSet(roleDoc);
  if (fromDoc.has(wanted)) return true;
  // Fallback to default matrix when role doc missing/stale.
  const role = normalizeRole(member.rankV2 || member.role);
  return (ROLE_PERMISSIONS[role] || []).includes(wanted);
}

/** Ceiling: mikado → shogun; shogun → daimyo; else null. */
function assignmentCeiling(actorRole) {
  const role = normalizeRole(actorRole);
  if (role === "mikado") return "shogun";
  if (role === "shogun") return "daimyo";
  return null;
}

function canAssignRole(actorRole, targetRole, desiredRole) {
  const actor = normalizeRole(actorRole);
  const target = normalizeRole(targetRole);
  const desired = normalizeRole(desiredRole);
  const ceiling = assignmentCeiling(actor);
  if (!ceiling) return false;
  if (desired === "mikado") return false;
  if (ROLE_POSITIONS[desired] > ROLE_POSITIONS[ceiling]) return false;
  if (ROLE_POSITIONS[target] >= ROLE_POSITIONS[actor]) return false;
  if (ROLE_POSITIONS[desired] >= ROLE_POSITIONS[actor]) return false;
  return true;
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return 0;
}

/**
 * Pure seat algorithm (§4.2).
 * @param {Array<{uid:string,role:string,rankV2?:string,invitedBy?:string|null,
 *   joinedAt?:*,isManualRole?:boolean,seatSource?:string}>} members
 * @param {Set<string>} [bannedUids]
 * @param {number} [nowMs]
 * @returns {{assignments: Record<string,string>, vacantAuto: Record<string,boolean>,
 *   effectiveInvites: Record<string,number>}}
 */
function computeAutoSeatAssignments(members, bannedUids, nowMs) {
  const banned = bannedUids || new Set();
  const now = typeof nowMs === "number" ? nowMs : Date.now();
  const active = members.filter((m) => m && m.uid && !banned.has(m.uid));

  const effectiveInvites = Object.create(null);
  for (const member of active) {
    effectiveInvites[member.uid] = 0;
  }
  for (const member of active) {
    const inviter = member.invitedBy;
    if (!inviter || !(inviter in effectiveInvites)) continue;
    const joinedMs = toMillis(member.joinedAt);
    if (!joinedMs || now - joinedMs < EFFECTIVE_INVITE_MIN_MS) continue;
    effectiveInvites[inviter] += 1;
  }

  // Manual holders occupy manual seats; exclude from auto competition if
  // they already hold mikado/shogun or any manual assignment.
  const manualByRank = Object.create(null);
  for (const rank of ROLES) manualByRank[rank] = [];
  const locked = new Set();
  for (const member of active) {
    const role = normalizeRole(member.rankV2 || member.role);
    if (role === "mikado" || role === "shogun" || member.isManualRole === true) {
      locked.add(member.uid);
      manualByRank[role].push(member.uid);
    }
  }

  const candidates = active
    .filter((m) => !locked.has(m.uid))
    .map((m) => ({
      uid: m.uid,
      invites: effectiveInvites[m.uid] || 0,
      joinedAt: toMillis(m.joinedAt),
    }))
    .sort((a, b) => {
      if (b.invites !== a.invites) return b.invites - a.invites;
      if (a.joinedAt !== b.joinedAt) return a.joinedAt - b.joinedAt;
      return a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0;
    });

  const assignments = Object.create(null);
  const vacantAuto = Object.create(null);
  const used = new Set();

  for (const rank of AUTO_SEAT_RANKS) {
    vacantAuto[rank] = true;
    const winner = candidates.find(
      (c) => !used.has(c.uid) && c.invites > 0,
    );
    if (!winner) continue;
    used.add(winner.uid);
    assignments[winner.uid] = rank;
    vacantAuto[rank] = false;
  }

  return { assignments, vacantAuto, effectiveInvites, manualByRank };
}

function manualSeatsRemaining(rank, manualHoldersCount) {
  const config = SEAT_CONFIG[normalizeRole(rank)];
  if (!config || !Number.isFinite(config.manual)) return Infinity;
  return Math.max(0, config.manual - manualHoldersCount);
}

function manualSeatFullMessage(rank) {
  const id = normalizeRole(rank);
  const config = SEAT_CONFIG[id];
  const label = id.toUpperCase().replace("DAIMYO", "DAIMYŌ").replace("SHOGUN", "SHŌGUN")
    .replace("RONIN", "RŌNIN");
  return `المقاعد اليدوية لرتبة ${label} ممتلئة (${config.manual}/${config.manual}). `
    + "المقعد الإضافي مخصص تلقائيًا لأكثر الأعضاء دعوةً لغيرهم، ولا يمكن تعيينه يدويًا.";
}

module.exports = {
  ROLES,
  ROLE_POSITIONS,
  ROLE_PERMISSIONS,
  SEAT_CONFIG,
  AUTO_SEAT_RANKS,
  LEGACY_ROLE_MAP,
  PERMISSION_ALIASES,
  EFFECTIVE_INVITE_MIN_MS,
  normalizeRole,
  normalizePermission,
  roleDefinition,
  isApexOwner,
  hasPermission,
  assignmentCeiling,
  canAssignRole,
  computeAutoSeatAssignments,
  manualSeatsRemaining,
  manualSeatFullMessage,
  toMillis,
};
