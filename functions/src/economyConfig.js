"use strict";

// Server-owned economy configuration. Flutter must not duplicate these
// amounts as an authority — callables read this module (or the catalog
// snapshot it publishes) and ignore client-supplied prices/balances.

const SCHEMA_VERSION = 1;
const MAX_BALANCE = 1000000000;
const MAX_GRANT = 1000;
const MAX_ID = 128;
const MAX_METADATA_KEYS = 8;
const MAX_METADATA_STRING = 128;
const HISTORY_LIMIT = 50;

// Spec §19.3: rarity ladder is Common ← Rare ← Epic ← Legendary ← Mythic.
const STORE_RARITIES = Object.freeze([
  "common",
  "rare",
  "epic",
  "legendary",
  "mythic",
]);

// Spec §19.3: the store has two live sections — technical expansions and
// cosmetics. "expansion" items raise a server-owned account capability and
// are not equippable; "cosmetic" items are the collectible cosmetics.
const STORE_SECTIONS = Object.freeze({
  COSMETIC: "cosmetic",
  EXPANSION: "expansion",
});

// The only account capabilities the store may raise. Each is applied by the
// economy domain inside the purchase transaction; domains that read them
// (currently groupsDomain for customMaxMembersLimit) treat this as the
// single source of truth for the granted value.
const EXPANSION_EFFECTS = Object.freeze({
  customMaxMembersLimit: Object.freeze({
    field: "customMaxMembersLimit",
    min: 0,
    max: 500,
    base: 100,
  }),
});

// Spec §19.4: Premium is activated with owner-generated codes because Google
// Billing is not available in the target market. The value limits are
// server-owned so a client cannot mint or extend entitlement.
const PREMIUM_CODE = Object.freeze({
  TIER: "premium",
  CODE_LENGTH: 16,
  DEFAULT_DURATION_DAYS: 30,
  MAX_DURATION_DAYS: 3650,
  MAX_REDEMPTIONS: 1000000,
  ALPHABET: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
});

const REWARD_TYPES = Object.freeze([
  "earn_event",
  "earn_game",
  "earn_game_win_easy",
  "earn_game_win_normal",
  "earn_game_win_hard",
  "earn_game_draw",
  "earn_game_loss",
  "earn_publish",
  "earn_achievement",
  "earn_referral_inviter",
  "earn_referral_invited",
  "purchase_cosmetic",
  "refund",
  "admin_adjustment",
]);

const REWARD_AMOUNTS = Object.freeze({
  earn_event: 10,
  earn_game: 10,
  earn_game_win_easy: 7,
  earn_game_win_normal: 8,
  earn_game_win_hard: 10,
  earn_game_draw: 5,
  earn_game_loss: 2,
  earn_mafia_win: 10,
  earn_mafia_loss: 2,
  earn_publish: 10,
  earn_achievement: 5,
  earn_referral_inviter: 70,
  earn_referral_invited: 30,
});

const DAILY_CAPS = Object.freeze({
  earn_event: 3,
  earn_game: 3,
  earn_game_win_easy: 3,
  earn_game_win_normal: 3,
  earn_game_win_hard: 3,
  earn_game_draw: 3,
  earn_game_loss: 3,
  earn_mafia_win: 3,
  earn_mafia_loss: 3,
  earn_publish: 1,
  earn_achievement: 9,
});

const DAILY_BUCKET = Object.freeze({
  earn_event: "event",
  earn_game: "event",
  earn_game_win_easy: "game",
  earn_game_win_normal: "game",
  earn_game_win_hard: "game",
  earn_game_draw: "game",
  earn_game_loss: "game",
  earn_mafia_win: "game",
  earn_mafia_loss: "game",
  earn_publish: "publish",
  earn_achievement: "achievement",
});

const RATE_LIMITS = Object.freeze({
  purchase: { windowMs: 60 * 1000, max: 8 },
  claim: { windowMs: 60 * 1000, max: 5 },
  equip: { windowMs: 60 * 1000, max: 30 },
  restore: { windowMs: 60 * 1000, max: 5 },
  redeem: { windowMs: 60 * 1000, max: 5 },
  codegen: { windowMs: 60 * 1000, max: 20 },
});

const COSMETIC_TYPES = Object.freeze(["frame", "badge", "nameplate", "theme"]);

const EQUIP_SLOT_FIELDS = Object.freeze({
  frame: "equippedFrameId",
  badge: "equippedBadgeId",
  nameplate: "equippedNameplateId",
  theme: "equippedThemeId",
});

const STORE_CATALOG = Object.freeze([
  // --- Cosmetics: frames, badges, nameplates, themes -------------------
  {
    id: "frame_sakura",
    type: "frame",
    section: "cosmetic",
    title: "Sakura Frame",
    description: "A soft cherry-blossom border for your avatar.",
    preview: "sakura",
    price: 80,
    currency: "coins",
    rarity: "common",
    availability: "active",
    premiumOnly: false,
    featured: true,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "frame_gold",
    type: "frame",
    section: "cosmetic",
    title: "Gold Frame",
    description: "A premium gilt frame reserved for Premium members.",
    preview: "gold",
    price: 200,
    currency: "coins",
    rarity: "epic",
    availability: "active",
    premiumOnly: true,
    featured: true,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "frame_obsidian",
    type: "frame",
    section: "cosmetic",
    title: "Obsidian Frame",
    description: "A striking legendary frame for veteran collectors.",
    preview: "obsidian",
    price: 400,
    currency: "coins",
    rarity: "legendary",
    availability: "active",
    premiumOnly: false,
    featured: true,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "frame_dragon",
    type: "frame",
    section: "cosmetic",
    title: "Dragon Frame",
    description: "A mythic dragon-coiled frame for the Dragon Store elite.",
    preview: "dragon",
    price: 900,
    currency: "coins",
    rarity: "mythic",
    availability: "active",
    premiumOnly: true,
    featured: true,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "badge_pioneer",
    type: "badge",
    section: "cosmetic",
    title: "Pioneer Badge",
    description: "Shows you were early to the Pubget community.",
    preview: "pioneer",
    price: 50,
    currency: "coins",
    rarity: "common",
    availability: "active",
    premiumOnly: false,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "badge_sensei",
    type: "badge",
    section: "cosmetic",
    title: "Sensei Badge",
    description: "A mark for dedicated community voices.",
    preview: "sensei",
    price: 120,
    currency: "coins",
    rarity: "rare",
    availability: "active",
    premiumOnly: false,
    featured: true,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "badge_legend",
    type: "badge",
    section: "cosmetic",
    title: "Legend Badge",
    description: "A legendary badge for the most respected members.",
    preview: "legend",
    price: 350,
    currency: "coins",
    rarity: "legendary",
    availability: "active",
    premiumOnly: false,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "nameplate_neon",
    type: "nameplate",
    section: "cosmetic",
    title: "Neon Nameplate",
    description: "A glowing nameplate for your public profile.",
    preview: "neon",
    price: 90,
    currency: "coins",
    rarity: "rare",
    availability: "active",
    premiumOnly: false,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "nameplate_celestial",
    type: "nameplate",
    section: "cosmetic",
    title: "Celestial Nameplate",
    description: "A mythic nameplate woven from starlight.",
    preview: "celestial",
    price: 800,
    currency: "coins",
    rarity: "mythic",
    availability: "active",
    premiumOnly: true,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "theme_sakura",
    type: "theme",
    section: "cosmetic",
    title: "Sakura Theme",
    description: "A cherry-blossom presentation theme.",
    preview: "sakura-theme",
    price: 130,
    currency: "coins",
    rarity: "rare",
    availability: "active",
    premiumOnly: false,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "theme_midnight",
    type: "theme",
    section: "cosmetic",
    title: "Midnight Theme",
    description: "A presentation theme for Premium members.",
    preview: "midnight",
    price: 150,
    currency: "coins",
    rarity: "epic",
    availability: "active",
    premiumOnly: true,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "badge_retired",
    type: "badge",
    section: "cosmetic",
    title: "Retired Badge",
    description: "No longer available in the store.",
    preview: "retired",
    price: 10,
    currency: "coins",
    rarity: "common",
    availability: "inactive",
    premiumOnly: false,
    featured: false,
    schemaVersion: SCHEMA_VERSION,
  },

  // --- Technical expansions (spec 19.3) --------------------------------
  // One-time per tier; each raises the member ceiling for the buyer. The
  // effect is applied server-side inside the purchase transaction.
  {
    id: "expansion_members_50",
    type: "expansion",
    section: "expansion",
    title: "Member Expansion +50",
    description: "Raise the member ceiling of the groups you own by 50.",
    preview: "members-50",
    price: 300,
    currency: "coins",
    rarity: "rare",
    availability: "active",
    premiumOnly: false,
    featured: true,
    effect: { field: "customMaxMembersLimit", amount: 50 },
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "expansion_members_150",
    type: "expansion",
    section: "expansion",
    title: "Member Expansion +150",
    description: "Raise the member ceiling of the groups you own by 150.",
    preview: "members-150",
    price: 700,
    currency: "coins",
    rarity: "epic",
    availability: "active",
    premiumOnly: false,
    featured: false,
    effect: { field: "customMaxMembersLimit", amount: 150 },
    schemaVersion: SCHEMA_VERSION,
  },
  {
    id: "expansion_members_300",
    type: "expansion",
    section: "expansion",
    title: "Member Expansion +300",
    description: "Raise the member ceiling of the groups you own by 300.",
    preview: "members-300",
    price: 1200,
    currency: "coins",
    rarity: "legendary",
    availability: "active",
    premiumOnly: true,
    featured: false,
    effect: { field: "customMaxMembersLimit", amount: 300 },
    schemaVersion: SCHEMA_VERSION,
  },
]);

const STORE_RARITIES_SET = Object.freeze(new Set(STORE_RARITIES));

function isKnownRarity(value) {
  return typeof value === "string" && STORE_RARITIES_SET.has(value);
}

function catalogById(itemId) {
  return STORE_CATALOG.find((item) => item.id === itemId) || null;
}

const DEFAULT_MAX_MEMBERS = 100;
const MAX_MEMBER_LIMIT = 500;

function effectiveMemberLimit(userData) {
  const stored = Number(userData && userData.customMaxMembersLimit) || 0;
  if (!Number.isFinite(stored) || stored <= 0) return DEFAULT_MAX_MEMBERS;
  return Math.min(Math.max(Math.trunc(stored), 2), MAX_MEMBER_LIMIT);
}

module.exports = {
  SCHEMA_VERSION,
  MAX_BALANCE,
  MAX_GRANT,
  MAX_ID,
  MAX_METADATA_KEYS,
  MAX_METADATA_STRING,
  HISTORY_LIMIT,
  STORE_RARITIES,
  STORE_SECTIONS,
  EXPANSION_EFFECTS,
  PREMIUM_CODE,
  REWARD_TYPES,
  REWARD_AMOUNTS,
  DAILY_CAPS,
  DAILY_BUCKET,
  RATE_LIMITS,
  COSMETIC_TYPES,
  EQUIP_SLOT_FIELDS,
  STORE_CATALOG,
  catalogById,
  isKnownRarity,
  DEFAULT_MAX_MEMBERS,
  MAX_MEMBER_LIMIT,
  effectiveMemberLimit,
};
