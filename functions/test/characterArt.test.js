"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const catalog = require("../src/gameCatalog");
const art = require("../src/characterArt");

test("every catalog character has opaque licensed artwork metadata", () => {
  for (const character of catalog.allCharacters()) {
    const artwork = art.artworkForCharacter(character.id);
    assert.ok(artwork, character.id);
    assert.equal(art.isOpaqueAssetId(artwork.assetId), true);
    assert.equal(artwork.license, "pubget-original");
    assert.equal(artwork.source, "pubget");
    assert.ok(artwork.portrait && Array.isArray(artwork.portrait.shapes));
    assert.equal(art.assertArtworkSafe(artwork, character), true);
    const publicArt = art.publicArtwork(character.id);
    assert.ok(publicArt, character.id);
    const blob = JSON.stringify(publicArt).toLowerCase();
    if (character.id.length > 2) {
      assert.equal(blob.includes(character.id.toLowerCase()), false);
    }
    if (character.name.length > 2) {
      assert.equal(blob.includes(character.name.toLowerCase()), false);
    }
  }
});

test("unknown or unsafe artwork is rejected without exposing identity", () => {
  assert.equal(art.artworkForCharacter("missing-character"), null);
  assert.equal(art.publicArtwork("missing-character"), null);
  const character = catalog.characterById("luffy");
  assert.equal(art.assertArtworkSafe({ assetId: "luffy.png" }, character), false);
  assert.equal(art.assertArtworkSafe({
    assetId: "pgart_3f8c1a92b4e0",
    license: "pubget-original",
    correctName: "Monkey D. Luffy",
  }, character), false);
});
