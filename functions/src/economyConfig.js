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

const REWARD_TYPES = Object.freeze([
  "earn_event",
  "earn_game",
  "earn_publish",
  "earn_referral_inviter",
  "earn_referral_invited",
  "purchase_cosmetic",
  "refund",
  "admin_adjustment",
]);

const REWARD_AMOUNTS = Object.freeze({
  earn_event: 10,
  earn_game: 10,
  earn_publish: 10,
  earn_referral_inviter: 70,
  earn_referral_invited: 30,
});

const DAILY_CAPS = Object.freeze({
  earn_event: 3,
  earn_game: 3,
  earn_publish: 1,
});

const DAILY_BUCKET = Object.freeze({
  earn_event: "event",
  earn_game: "event",
  earn_publish: "publish",
});

const RATE_LIMITS = Object.freeze({
  purchase: { windowMs: 60 * 1000, max: 8 },
  claim: { windowMs: 60 * 1000, max: 5 },
  equip: { windowMs: 60 * 1000, max: 30 },
  restore: { windowMs: 60 * 1000, max: 5 },
});

const COSMETIC_TYPES = Object.freeze(["frame", "badge", "nameplate", "theme"]);

const EQUIP_SLOT_FIELDS = Object.freeze({
  frame: "equippedFrameId",
  badge: "equippedBadgeId",
  nameplate: "equippedNameplateId",
  theme: "equippedThemeId",
});

const STORE_CATALOG = Object.freeze([
  {
    id: "frame_sakura",
    type: "frame",
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
    id: "badge_pioneer",
    type: "badge",
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
    id: "nameplate_neon",
    type: "nameplate",
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
    id: "theme_midnight",
    type: "theme",
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
]);

function catalogById(itemId) {
  return STORE_CATALOG.find((item) => item.id === itemId) || null;
}

module.exports = {
  SCHEMA_VERSION,
  MAX_BALANCE,
  MAX_GRANT,
  MAX_ID,
  MAX_METADATA_KEYS,
  MAX_METADATA_STRING,
  HISTORY_LIMIT,
  REWARD_TYPES,
  REWARD_AMOUNTS,
  DAILY_CAPS,
  DAILY_BUCKET,
  RATE_LIMITS,
  COSMETIC_TYPES,
  EQUIP_SLOT_FIELDS,
  STORE_CATALOG,
  catalogById,
};
