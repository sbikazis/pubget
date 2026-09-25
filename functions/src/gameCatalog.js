"use strict";

// Offline snapshot of real catalog entries (real titles, real character names,
// real studios). It is NOT the source of truth for Games: live data always
// comes from the canonical repository in `animeCatalogDomain`
// (Master Spec 16.2 — Jikan primary, AniList alternative, Firestore cache).
//
// This snapshot is used for two things only:
//   1. degraded mode, so a provider outage cannot crash a running game;
//   2. the Events (Axis 14) option validation, which resolves synchronously.
//
// No clue, emoji, or relation here is authored per title: the game engines
// derive those from real catalog fields at runtime.

const ANIME = Object.freeze([
  {
    id: "one_piece",
    title: "One Piece",
    studio: "Toei Animation",
    genres: ["adventure", "shonen"],
    characters: [
      { id: "luffy", name: "Monkey D. Luffy" },
      { id: "zoro", name: "Roronoa Zoro" },
      { id: "nami", name: "Nami" },
    ],
  },
  {
    id: "naruto",
    title: "Naruto",
    studio: "Pierrot",
    genres: ["action", "shonen"],
    characters: [
      { id: "naruto", name: "Naruto Uzumaki" },
      { id: "sasuke", name: "Sasuke Uchiha" },
      { id: "sakura", name: "Sakura Haruno" },
    ],
  },
  {
    id: "bleach",
    title: "Bleach",
    studio: "Pierrot",
    genres: ["action", "supernatural"],
    characters: [
      { id: "ichigo", name: "Ichigo Kurosaki" },
      { id: "rukia", name: "Rukia Kuchiki" },
    ],
  },
  {
    id: "attack_on_titan",
    title: "Attack on Titan",
    studio: "Wit Studio",
    genres: ["action", "drama"],
    characters: [
      { id: "eren", name: "Eren Yeager" },
      { id: "mikasa", name: "Mikasa Ackerman" },
      { id: "levi", name: "Levi Ackerman" },
    ],
  },
  {
    id: "demon_slayer",
    title: "Demon Slayer",
    studio: "Ufotable",
    genres: ["action", "historical"],
    characters: [
      { id: "tanjiro", name: "Tanjiro Kamado" },
      { id: "nezuko", name: "Nezuko Kamado" },
    ],
  },
  {
    id: "jujutsu_kaisen",
    title: "Jujutsu Kaisen",
    studio: "MAPPA",
    genres: ["action", "supernatural"],
    characters: [
      { id: "yuji", name: "Yuji Itadori" },
      { id: "gojo", name: "Satoru Gojo" },
    ],
  },
  {
    id: "my_hero_academia",
    title: "My Hero Academia",
    studio: "Bones",
    genres: ["action", "school"],
    characters: [
      { id: "deku", name: "Izuku Midoriya" },
      { id: "bakugo", name: "Katsuki Bakugo" },
    ],
  },
  {
    id: "fullmetal_alchemist",
    title: "Fullmetal Alchemist",
    studio: "Bones",
    genres: ["adventure", "steampunk"],
    characters: [
      { id: "edward", name: "Edward Elric" },
      { id: "alphonse", name: "Alphonse Elric" },
    ],
  },
  {
    id: "spy_x_family",
    title: "Spy x Family",
    studio: "Wit Studio",
    genres: ["comedy", "slice_of_life"],
    characters: [
      { id: "loid", name: "Loid Forger" },
      { id: "anya", name: "Anya Forger" },
      { id: "yor", name: "Yor Forger" },
    ],
  },
  {
    id: "frieren",
    title: "Frieren: Beyond Journey's End",
    studio: "Madhouse",
    genres: ["fantasy", "adventure"],
    characters: [
      { id: "frieren", name: "Frieren" },
      { id: "fern", name: "Fern" },
    ],
  },
  {
    id: "hunter_x_hunter",
    title: "Hunter x Hunter",
    studio: "Madhouse",
    genres: ["adventure", "shonen"],
    characters: [
      { id: "gon", name: "Gon Freecss" },
      { id: "killua", name: "Killua Zoldyck" },
    ],
  },
  {
    id: "death_note",
    title: "Death Note",
    studio: "Madhouse",
    genres: ["mystery", "psychological"],
    characters: [
      { id: "light", name: "Light Yagami" },
      { id: "l", name: "L" },
    ],
  },
  {
    id: "chainsaw_man",
    title: "Chainsaw Man",
    studio: "MAPPA",
    genres: ["action", "dark"],
    characters: [
      { id: "denji", name: "Denji" },
      { id: "power", name: "Power" },
    ],
  },
  {
    id: "haikyuu",
    title: "Haikyu!!",
    studio: "Production I.G",
    genres: ["sports", "school"],
    characters: [
      { id: "hinata", name: "Shoyo Hinata" },
      { id: "kageyama", name: "Tobio Kageyama" },
    ],
  },
  {
    id: "your_name",
    title: "Your Name",
    studio: "CoMix Wave Films",
    genres: ["romance", "drama"],
    characters: [
      { id: "taki", name: "Taki Tachibana" },
      { id: "mitsuha", name: "Mitsuha Miyamizu" },
    ],
  },
  {
    id: "spirited_away",
    title: "Spirited Away",
    studio: "Studio Ghibli",
    genres: ["fantasy", "adventure"],
    characters: [
      { id: "chihiro", name: "Chihiro Ogino" },
      { id: "haku", name: "Haku" },
    ],
  },
]);

function allCharacters() {
  const list = [];
  for (const anime of ANIME) {
    for (const character of anime.characters) {
      list.push({
        ...character,
        animeId: anime.id,
        animeTitle: anime.title,
      });
    }
  }
  return list;
}

function byAnimeId(id) {
  return ANIME.find((item) => item.id === id) || null;
}

function characterById(id) {
  return allCharacters().find((item) => item.id === id) || null;
}

function animeByTitle(raw) {
  const needle = normalizeTitle(raw);
  if (!needle) return null;
  return ANIME.find((item) => {
    if (normalizeTitle(item.title) === needle) return true;
    const alternatives = Array.isArray(item.alternativeTitles)
      ? item.alternativeTitles
      : [];
    return alternatives.some((title) => normalizeTitle(title) === needle);
  }) || null;
}

function normalizeTitle(value) {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .toLowerCase()
    .replace(/[!?.:,'"’]/g, "")
    .replace(/\s+/g, " ");
}

function sharesRelation(fromId, toId) {
  const from = byAnimeId(fromId);
  const to = byAnimeId(toId);
  if (!from || !to || from.id === to.id) return false;
  if (from.studio && from.studio === to.studio) return true;
  const fromChars = new Set(from.characters.map((item) => item.id));
  return to.characters.some((item) => fromChars.has(item.id));
}

module.exports = {
  ANIME,
  allCharacters,
  byAnimeId,
  characterById,
  animeByTitle,
  normalizeTitle,
  sharesRelation,
};
