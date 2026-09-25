"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  createAnimeCatalogDomain,
  mapJikanAnime,
  mapJikanCharacter,
  mapAniListAnime,
  mapAniListCharacter,
  emojiCluesFor,
  sharesRelation,
} = require("../src/animeCatalogDomain");

const JIKAN_ANIME = {
  mal_id: 21,
  title: "One Piece",
  title_english: "One Piece",
  title_japanese: "ONE PIECE",
  titles: [
    { type: "default", title: "One Piece" },
    { type: "english", title: "One Piece" },
  ],
  type: "TV",
  status: "Currently Airing",
  year: 1999,
  season: "fall",
  score: 8.72,
  members: 900000,
  synopsis: "Gol D. Roger was known as the Pirate King.",
  images: { jpg: { large_image_url: "https://cdn.example/large.jpg" } },
  genres: [{ name: "Action" }, { name: "Adventure" }],
  explicit_genres: [{ name: "Fantasy" }],
  themes: [{ name: "Organized Crime" }],
  demographics: [{ name: "Shounen" }],
  studios: [{ name: "Toei Animation" }],
  producers: [{ name: "Toei Animation" }, { name: "Bandai Entertainment" }],
  relations: [
    {
      relation: "Side Story",
      entry: [{ mal_id: 10015, type: "anime", name: "One Piece: Clockwork Island Adventure" }],
    },
  ],
};

const JIKAN_CHARACTER = {
  mal_id: 141391,
  name: "Monkey D. Luffy",
  name_kanji: "モンキー・D・ルフィ",
  images: { jpg: { image_url: "https://cdn.example/luffy.jpg" } },
  about: "Monkey D. Luffy is the captain of the Straw Hat Pirates.",
  anime: [{ mal_id: 21, position: "Main" }],
};

const ANILIST_ANIME = {
  id: 100,
  title: { romaji: "Cowboy Bebop", english: "Cowboy Bebop", native: "カウボーイビバップ" },
  synonyms: ["COWBOY BEBOP"],
  description: "Space bounty hunters.",
  coverImage: { large: "https://cdn.example/bebop.jpg" },
  season: "spring",
  seasonYear: 1998,
  type: "ANIME",
  format: "TV",
  status: "FINISHED",
  episodes: 26,
  averageScore: 87,
  popularity: 500000,
  genres: ["Action", "Award Winning", "Space"],
  studios: { nodes: [{ name: "Sunrise" }] },
  relations: {
    edges: [
      { relationType: "SIDE_STORY", node: { id: 101, title: { romaji: "Knights of Sidonia" } } },
      { relationType: "SUMMARY", node: { id: 102, title: { romaji: "Summarized" } } },
    ],
  },
};

test("Jikan anime maps to the canonical shape without leaking provider fields", () => {
  const mapped = mapJikanAnime(JIKAN_ANIME, { full: true });
  assert.equal(mapped.id, "jikan:21");
  assert.equal(mapped.title, "One Piece");
  assert.equal(mapped.titleJapanese, "ONE PIECE");
  // Case-only duplicates are collapsed on purpose: the search normalizes case,
  // so an extra "ONE PIECE" entry would only bloat every document.
  assert.ok(!mapped.alternativeTitles.includes("ONE PIECE"));
  assert.ok(!mapped.alternativeTitles.includes("One Piece"));
  assert.equal(mapped.imageUrl, "https://cdn.example/large.jpg");
  assert.equal(mapped.year, 1999);
  assert.equal(mapped.season, "fall");
  assert.ok(mapped.genres.includes("Action"));
  assert.ok(mapped.genres.includes("Fantasy"));
  assert.ok(mapped.genres.includes("Shounen"));
  assert.ok(mapped.studios.includes("Toei Animation"));
  assert.ok(mapped.studios.includes("Bandai Entertainment"));
  assert.deepEqual(mapped.relations, [
    { id: "jikan:10015", relation: "side story", title: "One Piece: Clockwork Island Adventure" },
  ]);
});

test("Jikan character maps to the canonical shape with its anime", () => {
  const mapped = mapJikanCharacter(JIKAN_CHARACTER);
  assert.equal(mapped.id, "jikan:141391");
  assert.equal(mapped.name, "Monkey D. Luffy");
  assert.equal(mapped.nameKanji, "モンキー・D・ルフィ");
  assert.deepEqual(mapped.animeIds, ["jikan:21"]);
});

test("AniList fallback maps the same canonical shape", () => {
  const mapped = mapAniListAnime(ANILIST_ANIME);
  assert.equal(mapped.id, "anilist:100");
  assert.equal(mapped.title, "Cowboy Bebop");
  assert.equal(mapped.titleEnglish, "Cowboy Bebop");
  assert.equal(mapped.titleJapanese, "カウボーイビバップ");
  assert.equal(mapped.score, 8.7);
  assert.ok(mapped.studios.includes("Sunrise"));
  // SUMMARY is not a story relation, so it never enters the chain graph.
  assert.deepEqual(mapped.relations, [
    { id: "anilist:101", relation: "side story", title: "Knights of Sidonia" },
  ]);
});

test("AniList character mapping keeps the anime edges", () => {
  const mapped = mapAniListCharacter({
    id: 500,
    name: { full: "Edward Wong", native: "エドワード・ウォン" },
    image: { large: "https://cdn.example/edward.jpg" },
    media: { edges: [{ node: { id: 21 } }, { node: { id: 21 } }, { node: { id: 22 } }] },
  });
  assert.equal(mapped.id, "anilist:500");
  assert.equal(mapped.name, "Edward Wong");
  assert.deepEqual(mapped.animeIds, ["anilist:21", "anilist:22"]);
});

test("emoji clues are derived from catalog fields and never contain the title", () => {
  const mapped = mapJikanAnime(JIKAN_ANIME, { full: true });
  const first = emojiCluesFor(mapped);
  const second = emojiCluesFor(mapped);
  assert.deepEqual(first, second, "derivation must be deterministic");
  assert.ok(first.length >= 3 && first.length <= 4);
  const blob = JSON.stringify(first).toLowerCase();
  assert.equal(blob.includes("one piece"), false);
  assert.equal(blob.includes("luffy"), false);
  assert.ok(!first.includes("🏴‍☠️"), "no hand-authored per-title emoji");
});

test("emoji clues stay usable when a title has no usable genres", () => {
  const clues = emojiCluesFor({
    title: "Unknown Anime",
    genres: [],
    studios: [],
    type: "Unknown",
  });
  assert.equal(clues.length, 3);
});

test("chain relation accepts a shared studio, a shared genre, or a direct relation", () => {
  const onePiece = mapJikanAnime(JIKAN_ANIME, { full: true });
  const sameStudio = { id: "anilist:9", genres: ["Fantasy"], studios: ["Toei Animation"], relations: [] };
  const sameGenre = { id: "anilist:8", genres: ["Action"], studios: ["Bones"], relations: [] };
  const unrelated = { id: "anilist:7", genres: ["Sports"], studios: ["I.G"], relations: [] };
  assert.equal(sharesRelation(onePiece, sameStudio), true);
  assert.equal(sharesRelation(onePiece, sameGenre), true);
  assert.equal(sharesRelation(onePiece, unrelated), false);
  assert.equal(sharesRelation(onePiece, onePiece), false);
  const related = { id: "anilist:9", genres: ["Sports"], studios: ["I.G"], relations: [{ id: "jikan:21" }] };
  assert.equal(sharesRelation(onePiece, related), true);
});

function jikanRouter(routes) {
  return async (url) => {
    const target = String(url);
    const key = Object.keys(routes).find((pattern) => target.includes(pattern));
    if (!key) throw new Error(`unexpected provider call: ${url}`);
    const value = routes[key];
    return typeof value === "function" ? value() : value;
  };
}

function memoryDb() {
  const store = new Map();
  return {
    store,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            path,
            id,
            async get() {
              const data = store.get(path);
              return { exists: data !== undefined, data: () => data };
            },
            async set(value) {
              store.set(path, value);
            },
          };
        },
      };
    },
  };
}

test("an anime detail lookup uses the full payload including relations", async () => {
  const catalog = createAnimeCatalogDomain({
    fetchJson: jikanRouter({ "/anime/21/full": { data: JIKAN_ANIME } }),
  });
  const anime = await catalog.getAnime("jikan:21");
  assert.equal(anime.id, "jikan:21");
  assert.deepEqual(anime.relations.map((item) => item.id), ["jikan:10015"]);
});

test("search resolves through Jikan and caches the result", async () => {
  const db = memoryDb();
  let calls = 0;
  const catalog = createAnimeCatalogDomain({
    db,
    fetchJson: async () => {
      calls += 1;
      return { data: [JIKAN_ANIME] };
    },
  });
  const first = await catalog.searchAnime("one piece", { limit: 5 });
  const second = await catalog.searchAnime("one piece", { limit: 5 });
  assert.equal(calls, 1, "the second search must be served from cache");
  assert.equal(first.length, 1);
  assert.equal(second[0].id, "jikan:21");
  assert.equal(db.store.size, 1);
});

test("AniList is used when the primary provider returns nothing", async () => {
  const catalog = createAnimeCatalogDomain({
    fetchJson: async (url, init) => {
      if (String(url).includes("api.jikan.moe")) return { data: [] };
      assert.equal(init.method, "POST");
      return { data: { Page: { media: [ANILIST_ANIME] } } };
    },
  });
  const items = await catalog.searchAnime("cowboy bebop", { limit: 5 });
  assert.equal(items.length, 1);
  assert.equal(items[0].id, "anilist:100");
});

test("a provider outage degrades to the last good cache instead of failing", async () => {
  const db = memoryDb();
  let healthy = true;
  const catalog = createAnimeCatalogDomain({
    db,
    fetchJson: async () => {
      if (!healthy) throw new Error("provider_down");
      return { data: JIKAN_ANIME };
    },
  });
  await catalog.getAnime("jikan:21");
  healthy = false;
  const stale = await catalog.getAnime("jikan:21");
  assert.equal(stale.id, "jikan:21");
});

test("an unknown ID resolves to null instead of inventing an entity", async () => {
  const catalog = createAnimeCatalogDomain({
    fetchJson: async () => {
      throw new Error("not_found");
    },
  });
  assert.equal(await catalog.getAnime("jikan:999999999"), null);
  assert.equal(await catalog.getAnime("not-an-id"), null);
  assert.equal(await catalog.getCharacter("jikan:999999999"), null);
});

test("public projections never carry provider internals", async () => {
  const catalog = createAnimeCatalogDomain({
    fetchJson: jikanRouter({
      "/anime?": { data: [JIKAN_ANIME] },
      "/characters": { data: [JIKAN_CHARACTER] },
    }),
  });
  const [anime] = await catalog.searchAnime("one piece");
  const [character] = await catalog.searchCharacters("luffy");
  const animeItem = catalog.animeToPublicSearchItem(anime);
  assert.deepEqual(Object.keys(animeItem).sort(), [
    "alternativeTitles",
    "genres",
    "id",
    "imageUrl",
    "studios",
    "title",
    "type",
    "year",
  ]);
  const characterItem = catalog.characterToPublicItem(character);
  assert.deepEqual(Object.keys(characterItem).sort(), [
    "animeIds",
    "id",
    "imageUrl",
    "name",
  ]);
});

let clockMs = Date.parse("2026-01-01T00:00:00Z");

test("AniList mapping keeps the format, not the media category", () => {
  const mapped = mapAniListAnime({
    id: 7,
    title: { romaji: "Kimi no Na wa." },
    description: "<p>A boy meets a girl.</p>",
    type: "ANIME",
    format: "MOVIE",
  });
  assert.equal(mapped.type, "MOVIE");
  assert.equal(mapped.synopsis, "A boy meets a girl.");
});

test("a detail entry keeps its longer TTL in memory", async () => {
  const db = memoryDb();
  let calls = 0;
  const catalog = createAnimeCatalogDomain({
    db,
    searchTtlMs: 1000,
    detailTtlMs: 60 * 60 * 1000,
    now: () => new Date(clockMs),
    fetchJson: async () => {
      calls += 1;
      return { data: JIKAN_ANIME };
    },
  });
  await catalog.getAnime("jikan:21");
  clockMs += 5000;
  await catalog.getAnime("jikan:21");
  assert.equal(calls, 1, "the detail entry must not expire with the search TTL");
});
