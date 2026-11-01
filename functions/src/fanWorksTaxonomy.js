"use strict";

/**
 * The single source of truth for the Fan Works type and category taxonomy.
 *
 * The Dart mirror is `lib/features/fan_works/models/fan_work_taxonomy.dart`.
 * Both files ship the same ids on purpose: the mirror lets the picker render
 * instantly and offline, while this module is the gate that actually rejects
 * a bad id. `functions/test/fanWorksTaxonomy.test.js` locks the list here, and
 * `test/fan_work_taxonomy_test.dart` locks the mirror, so a divergence fails CI
 * instead of surfacing as a user-visible rejection.
 *
 * Categories are a closed set, never free text (owner brief).
 */

/** Types a creator may publish today. */
const CREATABLE_TYPES = Object.freeze(["manga", "story", "drawing", "character"]);

/**
 * Types that still exist in the database and must keep rendering, but that can
 * no longer be created. `aiCharacter` predates the rebuild and is folded into
 * `character` with `origin: "aiGenerated"` on read.
 */
const LEGACY_READ_ONLY_TYPES = Object.freeze([
  "worldbuilding",
  "other",
  "aiCharacter",
]);

/** Every type the client and server both understand. */
const ALL_TYPES = Object.freeze([...CREATABLE_TYPES, ...LEGACY_READ_ONLY_TYPES]);

/** The four entries shown in the type picker. */
const CREATABLE_TYPE_LABELS = Object.freeze({
  manga: Object.freeze({ en: "Manga", ar: "مانغا" }),
  story: Object.freeze({ en: "Story", ar: "قصة" }),
  drawing: Object.freeze({ en: "Drawing", ar: "رسمة" }),
  character: Object.freeze({ en: "Character", ar: "شخصية" }),
});

const NARRATIVE_CATEGORIES = Object.freeze([
  Object.freeze({ id: "action", en: "Action", ar: "أكشن" }),
  Object.freeze({ id: "adventure", en: "Adventure", ar: "مغامرة" }),
  Object.freeze({ id: "comedy", en: "Comedy", ar: "كوميديا" }),
  Object.freeze({ id: "drama", en: "Drama", ar: "دراما" }),
  Object.freeze({ id: "romance", en: "Romance", ar: "رومانسي" }),
  Object.freeze({ id: "fantasy", en: "Fantasy", ar: "فانتازيا" }),
  Object.freeze({ id: "sciFi", en: "Sci-Fi", ar: "خيال علمي" }),
  Object.freeze({ id: "supernatural", en: "Supernatural", ar: "ما وراء الطبيعة" }),
  Object.freeze({ id: "horror", en: "Horror", ar: "رعب" }),
  Object.freeze({ id: "mystery", en: "Mystery", ar: "غموض" }),
  Object.freeze({ id: "sliceOfLife", en: "Slice of Life", ar: "حياة يومية" }),
  Object.freeze({ id: "historical", en: "Historical", ar: "تاريخي" }),
]);

const ART_CATEGORIES = Object.freeze([
  Object.freeze({ id: "portrait", en: "Portrait", ar: "بورتريه" }),
  Object.freeze({ id: "characterArt", en: "Character Art", ar: "رسم شخصيات" }),
  Object.freeze({ id: "fullBody", en: "Full Body", ar: "جسم كامل" }),
  Object.freeze({ id: "landscape", en: "Landscape", ar: "منظر طبيعي" }),
  Object.freeze({ id: "conceptArt", en: "Concept Art", ar: "فن المفاهيم" }),
  Object.freeze({ id: "digitalArt", en: "Digital Art", ar: "رسم رقمي" }),
  Object.freeze({ id: "traditionalArt", en: "Traditional Art", ar: "رسم تقليدي" }),
  Object.freeze({ id: "animeStyle", en: "Anime Style", ar: "أسلوب أنمي" }),
  Object.freeze({ id: "chibi", en: "Chibi", ar: "تشيبي" }),
  Object.freeze({ id: "fanArt", en: "Fan Art", ar: "فن معجبين" }),
]);

const CHARACTER_CATEGORIES = Object.freeze([
  Object.freeze({ id: "human", en: "Human", ar: "بشري" }),
  Object.freeze({ id: "superhuman", en: "Superhuman", ar: "خارق" }),
  Object.freeze({ id: "demon", en: "Demon", ar: "شيطان" }),
  Object.freeze({ id: "spirit", en: "Spirit", ar: "روح" }),
  Object.freeze({ id: "creature", en: "Creature", ar: "كائن خيالي" }),
  Object.freeze({ id: "android", en: "Android", ar: "آلي" }),
  Object.freeze({ id: "animal", en: "Animal", ar: "حيوان" }),
  Object.freeze({ id: "warrior", en: "Warrior", ar: "محارب" }),
  Object.freeze({ id: "royalty", en: "Royalty", ar: "ملك" }),
  Object.freeze({ id: "antiHero", en: "Anti-Hero", ar: "ضد بطل" }),
]);

/** Category list per type. Legacy types had no category, so they get none. */
const CATEGORIES_BY_TYPE = Object.freeze({
  manga: NARRATIVE_CATEGORIES,
  story: NARRATIVE_CATEGORIES,
  drawing: ART_CATEGORIES,
  character: CHARACTER_CATEGORIES,
  worldbuilding: Object.freeze([]),
  other: Object.freeze([]),
  aiCharacter: CHARACTER_CATEGORIES,
});

const ORIGINS = Object.freeze(["handmade", "aiGenerated"]);

function isKnownType(type) {
  return typeof type === "string" && ALL_TYPES.includes(type);
}

function isCreatableType(type) {
  return typeof type === "string" && CREATABLE_TYPES.includes(type);
}

function categoriesFor(type) {
  return CATEGORIES_BY_TYPE[type] || Object.freeze([]);
}

function supportsCategory(type) {
  return categoriesFor(type).length > 0;
}

function isValidCategory(type, id) {
  if (typeof id !== "string" || id.length === 0) return false;
  return categoriesFor(type).some((category) => category.id === id);
}

/**
 * Returns the canonical id, or an empty string when the id is not in the closed
 * list. An unknown id is never passed through: that would let a client invent
 * a category the picker cannot render.
 */
function normalizeCategory(type, id) {
  return isValidCategory(type, id) ? id : "";
}

function normalizeOrigin(raw) {
  return ORIGINS.includes(raw) ? raw : "handmade";
}

/**
 * Reads a legacy `aiCharacter` work as a plain `character` with an explicit
 * origin, so the whole codebase only ever deals with four types while the old
 * rows stay intact.
 */
function canonicalType(type) {
  return type === "aiCharacter" ? "character" : type;
}

module.exports = Object.freeze({
  ALL_TYPES,
  CREATABLE_TYPES,
  CREATABLE_TYPE_LABELS,
  LEGACY_READ_ONLY_TYPES,
  NARRATIVE_CATEGORIES,
  ART_CATEGORIES,
  CHARACTER_CATEGORIES,
  CATEGORIES_BY_TYPE,
  ORIGINS,
  isKnownType,
  isCreatableType,
  categoriesFor,
  supportsCategory,
  isValidCategory,
  normalizeCategory,
  normalizeOrigin,
  canonicalType,
});
