"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const taxonomy = require("../src/fanWorksTaxonomy");

test("exactly four types are creatable", () => {
  assert.deepEqual(taxonomy.CREATABLE_TYPES, [
    "manga",
    "story",
    "drawing",
    "character",
  ]);
  for (const type of taxonomy.CREATABLE_TYPES) {
    assert.equal(taxonomy.isCreatableType(type), true);
  }
  for (const type of taxonomy.LEGACY_READ_ONLY_TYPES) {
    assert.equal(taxonomy.isCreatableType(type), false);
    assert.equal(taxonomy.isKnownType(type), true);
  }
});

test("worldbuilding and other stay readable but never creatable", () => {
  for (const type of ["worldbuilding", "other"]) {
    assert.equal(taxonomy.isKnownType(type), true);
    assert.equal(taxonomy.isCreatableType(type), false);
    assert.equal(taxonomy.supportsCategory(type), false);
    assert.deepEqual(taxonomy.categoriesFor(type), []);
  }
});

test("manga and story share one narrative list, drawing and character differ", () => {
  assert.equal(taxonomy.categoriesFor("manga"), taxonomy.NARRATIVE_CATEGORIES);
  assert.equal(taxonomy.categoriesFor("story"), taxonomy.NARRATIVE_CATEGORIES);
  assert.equal(taxonomy.categoriesFor("drawing"), taxonomy.ART_CATEGORIES);
  assert.equal(taxonomy.categoriesFor("character"), taxonomy.CHARACTER_CATEGORIES);
});

test("category ids are unique inside every list", () => {
  for (const [type, categories] of Object.entries(taxonomy.CATEGORIES_BY_TYPE)) {
    const ids = categories.map((category) => category.id);
    assert.equal(new Set(ids).size, ids.length, `duplicate id in ${type}`);
  }
});

test("category ids are camelCase-safe for the Dart mirror", () => {
  const all = [
    ...taxonomy.NARRATIVE_CATEGORIES,
    ...taxonomy.ART_CATEGORIES,
    ...taxonomy.CHARACTER_CATEGORIES,
  ];
  for (const category of all) {
    assert.match(category.id, /^[a-z][A-Za-z]*$/, category.id);
    assert.ok(category.en && category.ar, category.id);
  }
});

test("every creatable type has a non-empty closed category list", () => {
  for (const type of taxonomy.CREATABLE_TYPES) {
    assert.equal(taxonomy.supportsCategory(type), true, type);
  }
});

test("isValidCategory rejects unknown, empty, and cross-type ids", () => {
  assert.equal(taxonomy.isValidCategory("manga", "action"), true);
  assert.equal(taxonomy.isValidCategory("manga", "portrait"), false);
  assert.equal(taxonomy.isValidCategory("drawing", "action"), false);
  assert.equal(taxonomy.isValidCategory("manga", ""), false);
  assert.equal(taxonomy.isValidCategory("manga", "made-up"), false);
  assert.equal(taxonomy.isValidCategory("worldbuilding", "action"), false);
  assert.equal(taxonomy.isValidCategory("unknownType", "action"), false);
});

test("normalizeCategory passes valid ids through and never invents one", () => {
  assert.equal(taxonomy.normalizeCategory("character", "demon"), "demon");
  assert.equal(taxonomy.normalizeCategory("character", "action"), "");
  assert.equal(taxonomy.normalizeCategory("character", undefined), "");
  assert.equal(taxonomy.normalizeCategory("worldbuilding", "human"), "");
});

test("origins are closed and default to handmade", () => {
  assert.deepEqual(taxonomy.ORIGINS, ["handmade", "aiGenerated"]);
  assert.equal(taxonomy.normalizeOrigin("aiGenerated"), "aiGenerated");
  assert.equal(taxonomy.normalizeOrigin("handmade"), "handmade");
  assert.equal(taxonomy.normalizeOrigin("machine"), "handmade");
  assert.equal(taxonomy.normalizeOrigin(undefined), "handmade");
});

test("legacy aiCharacter reads as character", () => {
  assert.equal(taxonomy.canonicalType("aiCharacter"), "character");
  assert.equal(taxonomy.canonicalType("manga"), "manga");
  assert.equal(taxonomy.isCreatableType("aiCharacter"), false);
});

test("exported tables are frozen so a caller cannot widen the taxonomy", () => {
  assert.equal(Object.isFrozen(taxonomy.CATEGORIES_BY_TYPE), true);
  assert.equal(Object.isFrozen(taxonomy.NARRATIVE_CATEGORIES), true);
  assert.equal(Object.isFrozen(taxonomy.ART_CATEGORIES), true);
  assert.equal(Object.isFrozen(taxonomy.CHARACTER_CATEGORIES), true);
  assert.equal(Object.isFrozen(taxonomy.CREATABLE_TYPES), true);
  assert.throws(() => {
    "use strict";
    taxonomy.CREATABLE_TYPES.push("other");
  });
});
