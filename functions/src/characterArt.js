"use strict";

// Pubget-owned original silhouette recipes. These are geometric portraits,
// not licensed anime stills. The character → asset map stays server-side.
// Public state only receives an opaque assetId plus draw commands.

const PALETTES = [
  ["#4C1D95", "#F5D76E", "#F8FAFC"],
  ["#9A3412", "#FDBA74", "#1C1917"],
  ["#1E3A8A", "#93C5FD", "#F8FAFC"],
  ["#14532D", "#86EFAC", "#052E16"],
  ["#831843", "#F9A8D4", "#FFF1F2"],
  ["#0F766E", "#5EEAD4", "#042F2E"],
  ["#B45309", "#FDE68A", "#1C1917"],
  ["#6D28D9", "#C4B5FD", "#F5F3FF"],
];

const ART_BY_CHARACTER = Object.freeze({
  luffy: { assetId: "pgart_3f8c1a92b4e0", seed: 11 },
  zoro: { assetId: "pgart_7a21d06c9b55", seed: 23 },
  nami: { assetId: "pgart_c04e88a1d73b", seed: 31 },
  naruto: { assetId: "pgart_19b6e2f40c8d", seed: 41 },
  sasuke: { assetId: "pgart_aa17c5d82e90", seed: 47 },
  sakura: { assetId: "pgart_5d33a0b1fe26", seed: 53 },
  ichigo: { assetId: "pgart_e8c2b19470aa", seed: 59 },
  rukia: { assetId: "pgart_02f9d6c4b811", seed: 61 },
  eren: { assetId: "pgart_bb45a7e103cd", seed: 67 },
  mikasa: { assetId: "pgart_71d0c8a29f14", seed: 71 },
  levi: { assetId: "pgart_d4a6e09c5b32", seed: 73 },
  tanjiro: { assetId: "pgart_8e21f5b0a647", seed: 79 },
  nezuko: { assetId: "pgart_c9b3d17e40f8", seed: 83 },
  yuji: { assetId: "pgart_14ae90c6d2bb", seed: 89 },
  gojo: { assetId: "pgart_f03c58a1e7d4", seed: 97 },
  deku: { assetId: "pgart_6b27d9c4a810", seed: 101 },
  bakugo: { assetId: "pgart_ad51e0b38c22", seed: 103 },
  edward: { assetId: "pgart_30c8f4a9d156", seed: 107 },
  alphonse: { assetId: "pgart_9f12b7e6c043", seed: 109 },
  loid: { assetId: "pgart_e7d4a21c908b", seed: 113 },
  anya: { assetId: "pgart_2c90b5d8e14f", seed: 127 },
  yor: { assetId: "pgart_a8e1c36b5720", seed: 131 },
  frieren: { assetId: "pgart_55d0a9c2b8e7", seed: 137 },
  fern: { assetId: "pgart_c1b47e09d3a6", seed: 139 },
  gon: { assetId: "pgart_08f3d6a5c219", seed: 149 },
  killua: { assetId: "pgart_b6c2e04d9178", seed: 151 },
  light: { assetId: "pgart_d91a47e0c5b3", seed: 157 },
  l: { assetId: "pgart_4e70b8c1a2d9", seed: 163 },
  denji: { assetId: "pgart_91c5e3a07f2b", seed: 167 },
  power: { assetId: "pgart_f2a80d6c4b15", seed: 173 },
  hinata: { assetId: "pgart_3a19c7e5d084", seed: 179 },
  kageyama: { assetId: "pgart_c70e2b94a561", seed: 181 },
  taki: { assetId: "pgart_5b84d0c1e937", seed: 191 },
  mitsuha: { assetId: "pgart_e05c9a2b714d", seed: 193 },
  chihiro: { assetId: "pgart_27d1b8f4c0ae", seed: 197 },
  haku: { assetId: "pgart_a4f6c13e8d20", seed: 199 },
});

function portraitForSeed(seed) {
  const palette = PALETTES[seed % PALETTES.length];
  const lean = (seed % 7) - 3;
  const hat = seed % 3;
  const accent = seed % 5;
  const shapes = [
    { type: "rect", x: 8, y: 8, w: 84, h: 84, r: 18, color: palette[0] },
    { type: "circle", x: 50 + lean, y: 46, r: 22, color: palette[2] },
    { type: "rect", x: 32 + lean, y: 64, w: 36, h: 28, r: 10, color: palette[1] },
  ];
  if (hat === 0) {
    shapes.push({ type: "ellipse", x: 50 + lean, y: 26, rx: 24, ry: 10, color: palette[1] });
  } else if (hat === 1) {
    shapes.push({ type: "rect", x: 28 + lean, y: 18, w: 44, h: 10, r: 4, color: palette[1] });
  } else {
    shapes.push({ type: "circle", x: 50 + lean, y: 22, r: 8, color: palette[1] });
  }
  if (accent === 0) {
    shapes.push({ type: "rect", x: 18, y: 70, w: 10, h: 22, r: 3, color: palette[2] });
    shapes.push({ type: "rect", x: 72, y: 70, w: 10, h: 22, r: 3, color: palette[2] });
  } else if (accent === 1) {
    shapes.push({ type: "circle", x: 24, y: 38, r: 6, color: palette[1] });
  } else if (accent === 2) {
    shapes.push({ type: "rect", x: 44 + lean, y: 78, w: 12, h: 14, r: 2, color: palette[0] });
  }
  return {
    background: palette[0],
    shapes,
  };
}

function isOpaqueAssetId(value) {
  return typeof value === "string" && /^pgart_[a-f0-9]{12}$/.test(value);
}

function artworkForCharacter(characterId) {
  const spec = ART_BY_CHARACTER[characterId];
  if (!spec) return null;
  return {
    assetId: spec.assetId,
    license: "pubget-original",
    attribution: "Original Pubget silhouette",
    source: "pubget",
    version: 1,
    portrait: portraitForSeed(spec.seed),
  };
}

function publicArtwork(characterId) {
  const artwork = artworkForCharacter(characterId);
  if (!artwork) return null;
  if (!assertArtworkSafe(artwork, { id: characterId })) return null;
  return artwork;
}

function assertArtworkSafe(artwork, character) {
  if (!artwork || !isOpaqueAssetId(artwork.assetId)) return false;
  const blob = JSON.stringify(artwork).toLowerCase();
  const forbidden = [
    character.id,
    character.name,
    character.animeId,
    character.animeTitle,
  ].filter(Boolean).map((item) => String(item).toLowerCase());
  return !forbidden.some((item) => item.length > 2 && blob.includes(item));
}

module.exports = {
  ART_BY_CHARACTER,
  artworkForCharacter,
  publicArtwork,
  isOpaqueAssetId,
  assertArtworkSafe,
};
