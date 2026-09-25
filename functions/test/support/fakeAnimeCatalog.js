"use strict";

// Test double for the canonical Anime/Character repository.
//
// It exposes the same surface as `animeCatalogDomain` over a fixed set of real
// titles (real titles, real studios, real genres) with fixture IDs, so game
// tests never depend on a network provider. Production code never imports this.

const { sharesRelation, emojiCluesFor, normalizeText } = require("../../src/animeCatalogDomain");

const ANIME = Object.freeze([
  {
    id: "jikan:1001",
    source: "jikan",
    sourceId: 1001,
    title: "One Piece",
    alternativeTitles: ["One Piece TV"],
    year: 1999,
    season: "fall",
    type: "TV",
    status: "Currently Airing",
    score: 8.7,
    members: 900000,
    genres: ["Action", "Adventure", "Fantasy", "Shounen"],
    studios: ["Toei Animation"],
    relations: [],
    characters: [
      { id: "jikan:2001", name: "Monkey D. Luffy" },
      { id: "jikan:2002", name: "Roronoa Zoro" },
    ],
  },
  {
    id: "jikan:1002",
    source: "jikan",
    sourceId: 1002,
    title: "Naruto",
    alternativeTitles: ["Naruto Shippuuden"],
    year: 2002,
    season: "fall",
    type: "TV",
    status: "Finished Airing",
    score: 8.0,
    members: 800000,
    genres: ["Action", "Adventure", "Drama", "Shounen"],
    studios: ["Pierrot"],
    relations: [{ id: "jikan:1005", relation: "sequel", title: "Boruto: Naruto Next Generations" }],
    characters: [
      { id: "jikan:2003", name: "Naruto Uzumaki" },
      { id: "jikan:2004", name: "Sasuke Uchiha" },
    ],
  },
  {
    id: "jikan:1003",
    source: "jikan",
    sourceId: 1003,
    title: "Bleach",
    alternativeTitles: [],
    year: 2004,
    season: "fall",
    type: "TV",
    status: "Finished Airing",
    score: 8.2,
    members: 700000,
    genres: ["Action", "Adventure", "Fantasy", "Shounen"],
    studios: ["Pierrot"],
    relations: [],
    characters: [{ id: "jikan:2005", name: "Ichigo Kurosaki" }],
  },
  {
    id: "jikan:1004",
    source: "jikan",
    sourceId: 1004,
    title: "Attack on Titan",
    alternativeTitles: ["Shingeki no Kyojin"],
    year: 2013,
    season: "spring",
    type: "TV",
    status: "Finished Airing",
    score: 8.6,
    members: 750000,
    genres: ["Action", "Drama", "Fantasy", "Shounen"],
    studios: ["Wit Studio"],
    relations: [],
    characters: [{ id: "jikan:2006", name: "Eren Yeager" }],
  },
  {
    id: "jikan:1005",
    source: "jikan",
    sourceId: 1005,
    title: "Boruto: Naruto Next Generations",
    alternativeTitles: ["Boruto"],
    year: 2016,
    season: "spring",
    type: "TV",
    status: "Finished Airing",
    score: 7.2,
    members: 300000,
    genres: ["Action", "Adventure", "Shounen"],
    studios: ["Pierrot"],
    relations: [{ id: "jikan:1002", relation: "prequel", title: "Naruto" }],
    characters: [],
  },
  {
    id: "jikan:1006",
    source: "jikan",
    sourceId: 1006,
    title: "Steins;Gate",
    alternativeTitles: ["Steins Gate"],
    year: 2011,
    season: "spring",
    type: "TV",
    status: "Finished Airing",
    score: 9.1,
    members: 500000,
    genres: ["Sci-Fi", "Suspense", "Psychological"],
    studios: ["White Fox"],
    relations: [],
    characters: [],
  },
]);

function allCharacters() {
  const list = [];
  ANIME.forEach((anime) => {
    anime.characters.forEach((character) => {
      list.push({ ...character, animeId: anime.id, animeTitle: anime.title });
    });
  });
  return list;
}

const CHARACTERS = Object.freeze(allCharacters().map((character) => ({
  id: character.id,
  source: "jikan",
  sourceId: Number(character.id.slice(7)),
  name: character.name,
  nameKanji: "",
  animeIds: [character.animeId],
  imageUrl: "",
  about: "",
})));

const ANIME_BY_ID = new Map(ANIME.map((item) => [item.id, item]));
const CHARACTER_BY_ID = new Map(CHARACTERS.map((item) => [item.id, item]));

function titlesOf(anime) {
  return [anime.title, ...(anime.alternativeTitles || [])];
}

function matchesTitle(anime, needle) {
  const target = normalizeText(needle);
  if (!target) return false;
  return titlesOf(anime).some((title) => normalizeText(title) === target);
}

function createFakeAnimeCatalog(options = {}) {
  const calls = { searchAnime: 0, getAnime: 0, getCharacter: 0, pool: 0 };
  const failAnimePool = options.failAnimePool === true;
  return {
    calls,
    async searchAnime(query, { limit = 12 } = {}) {
      calls.searchAnime += 1;
      const needle = normalizeText(query);
      const matched = ANIME.filter((item) => matchesTitle(item, needle) ||
        titlesOf(item).some((title) => normalizeText(title).includes(needle)));
      return matched.slice(0, limit);
    },
    async getAnime(id) {
      calls.getAnime += 1;
      const anime = ANIME_BY_ID.get(id);
      return anime ? { ...anime } : null;
    },
    async getCharacter(id) {
      calls.getCharacter += 1;
      const character = CHARACTER_BY_ID.get(id);
      return character ? { ...character } : null;
    },
    async searchCharacters(query, { limit = 20, animeId = null } = {}) {
      const needle = normalizeText(query);
      const matched = CHARACTERS.filter((character) => {
        if (animeId) return character.animeIds.includes(animeId);
        if (!needle) return false;
        return normalizeText(character.name).includes(needle);
      });
      return matched.slice(0, limit);
    },
    async animePool() {
      calls.pool += 1;
      if (failAnimePool) throw new Error("provider_unavailable");
      return ANIME.map((item) => ({ ...item }));
    },
    emojiCluesFor,
    sharesRelation,
    validateChainSubmission(previous, submitted) {
      if (!previous || !submitted) return { ok: false, reason: "unknown_anime" };
      if (previous.id === submitted.id) return { ok: false, reason: "duplicate_anime" };
      if (!sharesRelation(previous, submitted)) return { ok: false, reason: "broken_chain" };
      return { ok: true, reason: "valid" };
    },
    animeToPublicSearchItem(anime) {
      if (!anime) return null;
      return {
        id: anime.id,
        title: anime.title,
        alternativeTitles: anime.alternativeTitles || [],
        imageUrl: anime.imageUrl || "",
        year: anime.year || null,
        type: anime.type || null,
        genres: anime.genres || [],
        studios: anime.studios || [],
      };
    },
    characterToPublicItem(character) {
      if (!character) return null;
      return {
        id: character.id,
        name: character.name,
        animeIds: character.animeIds || [],
        imageUrl: character.imageUrl || "",
      };
    },
  };
}

module.exports = {
  createFakeAnimeCatalog,
  FAKE_ANIME: ANIME,
  FAKE_CHARACTERS: CHARACTERS,
  characterIdsOf: (animeId) => {
    const anime = ANIME_BY_ID.get(animeId);
    return anime ? anime.characters.map((item) => item.id) : [];
  },
  relatedAnimeId: (animeId) => {
    const anime = ANIME_BY_ID.get(animeId);
    if (!anime) return null;
    const related = ANIME.find((item) => item.id !== animeId && sharesRelation(anime, item));
    return related ? related.id : null;
  },
  titleOf: (animeId) => {
    const anime = ANIME_BY_ID.get(animeId);
    return anime ? anime.title : null;
  },
};
