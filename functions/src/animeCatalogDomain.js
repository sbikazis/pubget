"use strict";

// Server-side canonical Anime/Character repository.
//
// PUBGET Master Spec 16.2 defines the data contract for the whole product:
//   `AnimeRepository` abstraction, Jikan (MyAnimeList) as the primary source,
//   AniList GraphQL as the alternative, and an internal Firestore cache that
//   keeps upstream pressure low and keeps the product working when a provider
//   degrades.
//
// Games (Axis 12) are server-authoritative: a submitted Character/Anime ID must
// be validated against real catalog data, never against a hardcoded list. This
// module is that repository. It is provider-agnostic on purpose: the engines
// only see the normalized shapes below.
//
// Normalized shapes:
//
//   anime:     { id, source, sourceId, title, titleEnglish, titleJapanese,
//                alternativeTitles, synopsis, imageUrl, year, season, type,
//                status, score, members, genres, studios, relations }
//   character: { id, source, sourceId, name, nameKanji, animeIds, imageUrl }
//
// `id` is namespaced by provider so an ID from one provider can never be
// silently resolved by another.

const crypto = require("crypto");

const JIKAN_BASE = "https://api.jikan.moe/v4";
const ANILIST_ENDPOINT = "https://graphql.anilist.co";
const CACHE_COLLECTION = "animeCatalogCache";

const DEFAULT_TTL_MS = 6 * 60 * 60 * 1000;
const DETAIL_TTL_MS = 24 * 60 * 60 * 1000;
const SEARCH_PAGE_SIZE = 25;
const MAX_LIMIT = 25;
const REQUEST_TIMEOUT_MS = 8000;
const PROVIDER_RETRY_MS = 400;
const PROVIDER_MAX_RETRIES = 2;

const GENRE_EMOJI = Object.freeze({
  action: "⚔️",
  adventure: "🗺️",
  comedy: "😂",
  drama: "🎭",
  fantasy: "🧙",
  horror: "👻",
  mystery: "🔍",
  romance: "💗",
  "sci-fi": "🛸",
  "slice of life": "🍃",
  sports: "🏅",
  supernatural: "✨",
  thriller: "🕵️",
  mecha: "🤖",
  music: "🎵",
  school: "🎒",
  historical: "🏯",
  military: "🎖️",
  police: "🚓",
  psychological: "🧠",
  awards: "🏆",
});

const TYPE_EMOJI = Object.freeze({
  TV: "📺",
  Movie: "🎬",
  OVA: "💿",
  ONA: "🎞️",
  Music: "🎵",
  TV_special: "🎬",
  Special: "🎬",
  Unknown: "✨",
});

const STUDIO_HINTS = [
  [/\bGhibli\b/i, "🏯"],
  [/\bCoMix Wave\b/i, "🌀"],
  [/\bMAPPA\b/i, "🗺️"],
  [/\bMadhouse\b/i, "🎬"],
  [/\bBones\b/i, "🦴"],
  [/\bUfotable\b/i, "⚔️"],
  [/\bToei\b/i, "🏴‍☠️"],
  [/\bPierrot\b/i, "🎭"],
  [/\bWit Studio\b/i, "🧱"],
  [/\bProduction I\.?G\b/i, "🖌️"],
  [/\bA-1 Pictures\b/i, "🅰️"],
  [/\bKyoto Animation\b/i, "🍃"],
];

const ACCEPTED_RELATIONS = new Set([
  "sequel",
  "prequel",
  "side story",
  "parent story",
  "full story",
  "alternative setting",
  "alternative version",
]);

function normalizeText(value) {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .toLowerCase()
    .replace(/[\u064b-\u065f]/g, "")
    .replace(/[!?.:,'"'\u2019()\[\]]/g, "")
    .replace(/&/g, "and")
    .replace(/\s+/g, " ");
}

function clampLimit(value, fallback) {
  const n = Number.isInteger(value) ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(MAX_LIMIT, Math.max(1, n));
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function isJikanId(id) {
  return typeof id === "string" && /^jikan:\d+$/.test(id);
}

function isAniListId(id) {
  return typeof id === "string" && /^anilist:\d+$/.test(id);
}

const JIKAN_PREFIX = "jikan:";
const ANILIST_PREFIX = "anilist:";

function splitId(id) {
  if (isJikanId(id)) return { source: "jikan", sourceId: Number(id.slice(JIKAN_PREFIX.length)) };
  if (isAniListId(id)) {
    return { source: "anilist", sourceId: Number(id.slice(ANILIST_PREFIX.length)) };
  }
  return null;
}

function imageOf(raw) {
  if (!raw || typeof raw !== "object") return "";
  const jpg = raw.jpg || raw.jpeg || {};
  return firstNonEmpty(jpg.large_image_url, jpg.image_url, raw.large, raw.medium);
}

function textOf(raw) {
  if (typeof raw === "string") return raw;
  if (!raw || typeof raw !== "object") return "";
  return firstNonEmpty(raw.romaji, raw.english, raw.native, raw.userPreferred);
}

function mapJikanAnime(raw, { full = false } = {}) {
  if (!raw || typeof raw !== "object") return null;
  const sourceId = Number(raw.mal_id);
  if (!Number.isInteger(sourceId) || sourceId <= 0) return null;
  const titles = Array.isArray(raw.titles) ? raw.titles : [];
  const alternativeTitles = [];
  const primaryTitle = normalizeText(firstNonEmpty(
    raw.title,
    raw.title_english,
    raw.title_japanese,
  ));
  const addAlternative = (value) => {
    const title = firstNonEmpty(value);
    if (!title) return;
    const normalized = normalizeText(title);
    if (!normalized || normalized === primaryTitle) return;
    if (alternativeTitles.some((item) => normalizeText(item) === normalized)) {
      return;
    }
    alternativeTitles.push(title);
  };
  titles.forEach((entry) => {
    if (!entry || typeof entry !== "object") return;
    addAlternative(entry.title);
  });
  addAlternative(raw.title_english);
  addAlternative(raw.title_japanese);
  addAlternative(raw.title);

  const genres = [];
  const pushName = (list) => {
    (Array.isArray(list) ? list : []).forEach((entry) => {
      const name = firstNonEmpty(
        typeof entry === "string" ? entry : entry && entry.name,
      );
      if (!name) return;
      if (genres.some((item) => normalizeText(item) === normalizeText(name))) return;
      genres.push(name);
    });
  };
  pushName(raw.genres);
  pushName(raw.explicit_genres);
  pushName(raw.themes);
  pushName(raw.demographics);

  const studios = [];
  const pushStudio = (list) => {
    (Array.isArray(list) ? list : []).forEach((entry) => {
      const name = firstNonEmpty(
        typeof entry === "string" ? entry : entry && entry.name,
      );
      if (!name) return;
      if (studios.some((item) => normalizeText(item) === normalizeText(name))) return;
      studios.push(name);
    });
  };
  pushStudio(raw.studios);
  pushStudio(raw.producers);

  const relations = [];
  if (full && Array.isArray(raw.relations)) {
    raw.relations.forEach((entry) => {
      if (!entry || typeof entry !== "object") return;
      const relation = firstNonEmpty(entry.relation).toLowerCase();
      if (!relation || !ACCEPTED_RELATIONS.has(relation)) return;
      const entries = Array.isArray(entry.entry) ? entry.entry : [];
      entries.forEach((linked) => {
        const linkedId = Number(linked && linked.mal_id);
        if (!Number.isInteger(linkedId) || linkedId <= 0) return;
        relations.push({
          id: `jikan:${linkedId}`,
          relation,
          title: firstNonEmpty(linked && linked.name),
        });
      });
    });
  }

  const title = firstNonEmpty(
    raw.title,
    raw.title_english,
    raw.title_japanese,
    ...titles.map((entry) => (entry && entry.title) || ""),
  );
  if (!title) return null;

  return {
    id: `jikan:${sourceId}`,
    source: "jikan",
    sourceId,
    title,
    titleEnglish: firstNonEmpty(raw.title_english),
    titleJapanese: firstNonEmpty(raw.title_japanese),
    alternativeTitles,
    synopsis: firstNonEmpty(raw.synopsis).slice(0, 1200),
    imageUrl: imageOf(raw.images),
    year: Number.isInteger(raw.year) ? raw.year : null,
    season: firstNonEmpty(raw.season).toLowerCase() || null,
    type: firstNonEmpty(raw.type) || "Unknown",
    status: firstNonEmpty(raw.status) || null,
    score: typeof raw.score === "number" ? raw.score : null,
    members: Number.isInteger(raw.members) ? raw.members : null,
    episodes: Number.isInteger(raw.episodes) ? raw.episodes : null,
    genres,
    studios,
    relations,
  };
}

function mapJikanCharacter(raw) {
  if (!raw || typeof raw !== "object") return null;
  const sourceId = Number(raw.mal_id);
  if (!Number.isInteger(sourceId) || sourceId <= 0) return null;
  const name = firstNonEmpty(raw.name);
  if (!name) return null;
  const animeIds = [];
  const media = raw.anime;
  const entries = media && Array.isArray(media) ? media : [];
  entries.forEach((entry) => {
    const node = entry && (entry.node || entry);
    const linkedId = Number(node && node.mal_id);
    if (!Number.isInteger(linkedId) || linkedId <= 0) return;
    const id = `jikan:${linkedId}`;
    if (!animeIds.includes(id)) animeIds.push(id);
  });
  return {
    id: `jikan:${sourceId}`,
    source: "jikan",
    sourceId,
    name,
    nameKanji: firstNonEmpty(raw.name_kanji),
    animeIds,
    imageUrl: imageOf(raw.images),
    about: firstNonEmpty(raw.about).slice(0, 600),
  };
}

function mapAniListAnime(node) {
  if (!node || typeof node !== "object") return null;
  const sourceId = Number(node.id);
  if (!Number.isInteger(sourceId) || sourceId <= 0) return null;
  const title = textOf(node.title);
  if (!title) return null;
  const titles = node.title && typeof node.title === "object" ? node.title : {};
  const alternativeTitles = [];
  const primaryTitle = normalizeText(title);
  const addAlternative = (value) => {
    const text = firstNonEmpty(value);
    if (!text) return;
    const normalized = normalizeText(text);
    if (!normalized || normalized === primaryTitle) return;
    if (alternativeTitles.some((item) => normalizeText(item) === normalized)) {
      return;
    }
    alternativeTitles.push(text);
  };
  addAlternative(titles.romaji);
  addAlternative(titles.english);
  addAlternative(titles.native);
  (Array.isArray(node.synonyms) ? node.synonyms : []).forEach(addAlternative);

  const genres = [];
  (Array.isArray(node.genres) ? node.genres : []).forEach((entry) => {
    const name = firstNonEmpty(entry);
    if (!name) return;
    if (!genres.some((item) => normalizeText(item) === normalizeText(name))) {
      genres.push(name);
    }
  });

  const studios = [];
  const studioNodes =
    node.studios && Array.isArray(node.studios.nodes) ? node.studios.nodes : [];
  studioNodes.forEach((entry) => {
    const name = firstNonEmpty(entry && entry.name);
    if (!name) return;
    if (!studios.some((item) => normalizeText(item) === normalizeText(name))) {
      studios.push(name);
    }
  });

  const relations = [];
  const edges =
    node.relations && Array.isArray(node.relations.edges) ? node.relations.edges : [];
  edges.forEach((edge) => {
    if (!edge || typeof edge !== "object") return;
    const relation = firstNonEmpty(edge.relationType)
      .toLowerCase()
      .replace(/[_-]/g, " ");
    if (!relation || !ACCEPTED_RELATIONS.has(relation)) return;
    const linkedId = Number(edge.node && edge.node.id);
    if (!Number.isInteger(linkedId) || linkedId <= 0) return;
    relations.push({
      id: `anilist:${linkedId}`,
      relation,
      title: textOf(edge.node && edge.node.title),
    });
  });

  return {
    id: `anilist:${sourceId}`,
    source: "anilist",
    sourceId,
    title,
    titleEnglish: firstNonEmpty(titles.english),
    titleJapanese: firstNonEmpty(titles.native),
    alternativeTitles,
    synopsis: firstNonEmpty(node.description)
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 1200),
    imageUrl: firstNonEmpty(
      node.coverImage && (node.coverImage.large || node.coverImage.medium),
    ),
    year: Number.isInteger(node.seasonYear) ? node.seasonYear : null,
    season: firstNonEmpty(node.season).toLowerCase() || null,
    type: firstNonEmpty(node.format, node.type) || "Unknown",
    status: firstNonEmpty(node.status) || null,
    score: typeof node.averageScore === "number" ? node.averageScore / 10 : null,
    members: Number.isInteger(node.popularity) ? node.popularity : null,
    episodes: Number.isInteger(node.episodes) ? node.episodes : null,
    genres,
    studios,
    relations,
  };
}

function mapAniListCharacter(node) {
  if (!node || typeof node !== "object") return null;
  const sourceId = Number(node.id);
  if (!Number.isInteger(sourceId) || sourceId <= 0) return null;
  const nameBlock = node.name && typeof node.name === "object" ? node.name : {};
  const name = firstNonEmpty(nameBlock.full, nameBlock.native, nameBlock.alternative);
  if (!name) return null;
  const animeIds = [];
  const edges =
    node.media && Array.isArray(node.media.edges) ? node.media.edges : [];
  edges.forEach((edge) => {
    const linkedId = Number(edge && edge.node && edge.node.id);
    if (!Number.isInteger(linkedId) || linkedId <= 0) return;
    const id = `anilist:${linkedId}`;
    if (!animeIds.includes(id)) animeIds.push(id);
  });
  return {
    id: `anilist:${sourceId}`,
    source: "anilist",
    sourceId,
    name,
    nameKanji: firstNonEmpty(nameBlock.native),
    animeIds,
    imageUrl: firstNonEmpty(
      node.image && (node.image.large || node.image.medium),
    ),
    about: "",
  };
}

// Genre-derived emoji are deterministic and carry no title information, so a
// round can present "3-4 emoji only, no words, no name" without ever leaking
// the answer. Nothing here is authored per title: every emoji is a function of
// real catalog fields.
function emojiCluesFor(anime) {
  if (!anime || typeof anime !== "object") return [];
  const clues = [];
  const push = (emoji) => {
    if (!emoji || clues.includes(emoji)) return;
    if (clues.length < 4) clues.push(emoji);
  };
  const tags = Array.isArray(anime.genres) ? anime.genres : [];
  tags.forEach((tag) => {
    const key = normalizeText(tag);
    push(GENRE_EMOJI[key]);
  });
  if (clues.length < 3) {
    TYPE_EMOJI[anime.type] && push(TYPE_EMOJI[anime.type]);
  }
  if (clues.length < 3) {
    const studios = Array.isArray(anime.studios) ? anime.studios : [];
    for (const studio of studios) {
      const hit = STUDIO_HINTS.find(([pattern]) => pattern.test(studio));
      if (hit) {
        push(hit[1]);
        break;
      }
    }
  }
  // A round must always show at least three emoji. The filler is derived from
  // the catalog ID, so it is stable per title and carries no title information.
  let cursor = 0;
  while (clues.length < 3 && cursor < FILLER_EMOJI.length) {
    push(FILLER_EMOJI[(hashOf(anime.id) + cursor) % FILLER_EMOJI.length]);
    cursor += 1;
  }
  return clues.slice(0, 4);
}

const FILLER_EMOJI = Object.freeze(["🌸", "✨", "🌙", "🍃", "🗻", "🎐", "🌊", "🍥"]);

function hashOf(value) {
  let hash = 0;
  const text = typeof value === "string" ? value : "";
  for (let index = 0; index < text.length; index += 1) {
    hash = (hash * 31 + text.charCodeAt(index)) % 1000003;
  }
  return Math.abs(hash);
}

function sharesTag(fromList, toList) {
  const from = new Set((fromList || []).map(normalizeText).filter(Boolean));
  return (toList || []).some((item) => from.has(normalizeText(item)));
}

function sharesRelation(from, to) {
  if (!from || !to) return false;
  if (from.id === to.id) return false;
  if (sharesTag(from.studios, to.studios)) return true;
  if (sharesTag(from.genres, to.genres)) return true;
  const fromRelations = (from.relations || []).map((item) => item && item.id).filter(Boolean);
  const toRelations = (to.relations || []).map((item) => item && item.id).filter(Boolean);
  return fromRelations.includes(to.id) || toRelations.includes(from.id);
}

function animeToPublicSearchItem(anime) {
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
}

function characterToPublicItem(character) {
  if (!character) return null;
  return {
    id: character.id,
    name: character.name,
    animeIds: character.animeIds || [],
    imageUrl: character.imageUrl || "",
  };
}

function createAnimeCatalogDomain(options = {}) {
  const db = options.db || null;
  const fetchJson = typeof options.fetchJson === "function"
    ? options.fetchJson
    : defaultFetchJson;
  const now = typeof options.now === "function" ? options.now : () => new Date();
  const searchTtlMs = Number.isInteger(options.searchTtlMs)
    ? options.searchTtlMs
    : DEFAULT_TTL_MS;
  const detailTtlMs = Number.isInteger(options.detailTtlMs)
    ? options.detailTtlMs
    : DETAIL_TTL_MS;
  const inMemory = new Map();

  function cacheRef(key) {
    return db.collection(CACHE_COLLECTION).doc(cacheKey(key));
  }

  async function writeCache(key, value, ttlMs = searchTtlMs) {
    const fetchedAtMs = now().getTime();
    inMemory.set(key, { value, expiresAt: fetchedAtMs + ttlMs });
    if (!db) return;
    try {
      await cacheRef(key).set(
        { key, value, fetchedAtMs, updatedAt: fetchedAtMs },
        { merge: true },
      );
    } catch (_) {
      // A cache write failure must never fail a game.
    }
  }

  // A stale cache entry is a better answer than a broken game: providers
  // degrade, the product does not.
  async function cached(key, producer, ttlMs = searchTtlMs) {
    const clock = now().getTime();
    const memoryEntry = inMemory.get(key);
    if (memoryEntry && memoryEntry.expiresAt > clock) {
      return memoryEntry.value;
    }
    let stale = memoryEntry ? memoryEntry.value : null;
    if (db) {
      try {
        const snapshot = await cacheRef(key).get();
        if (snapshot.exists) {
          const data = snapshot.data() || {};
          if (data.value !== undefined) stale = data.value;
          if ((data.fetchedAtMs || 0) + ttlMs > clock) {
            inMemory.set(key, {
              value: data.value,
              expiresAt: (data.fetchedAtMs || 0) + ttlMs,
            });
            return data.value;
          }
        }
      } catch (_) {
        // A cache read failure falls back to whatever we already hold.
      }
    }
    try {
      const value = await producer();
      await writeCache(key, value, ttlMs);
      return value;
    } catch (error) {
      if (stale !== null && stale !== undefined) return stale;
      throw error;
    }
  }

  function jikanUri(path, query) {
    const base = JIKAN_BASE.endsWith("/") ? JIKAN_BASE : `${JIKAN_BASE}/`;
    const url = new URL(`${base}${path}`);
    Object.entries(query || {}).forEach(([key, value]) => {
      if (value === undefined || value === null) return;
      url.searchParams.set(key, String(value));
    });
    return url.toString();
  }

  async function jikan(path, query) {
    const body = await fetchJson(jikanUri(path, query));
    if (!body || typeof body !== "object") {
      throw new Error("jikan_empty_response");
    }
    return body;
  }

  async function anilist(query, variables) {
    return fetchJson(ANILIST_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query, variables: variables || {} }),
    });
  }

  const ANIME_FIELDS = `
    id
    title { romaji english native }
    synonyms
    description(asHtml: false)
    coverImage { large medium }
    season
    seasonYear
    type
    format
    status
    episodes
    averageScore
    popularity
    genres
    studios(isMain: true) { nodes { name } }
    relations {
      edges {
        relationType(version: 2)
        node { id title { romaji english native } type }
      }
    }
  `;

  const CHARACTER_FIELDS = `
    id
    name { full native alternative }
    image { large medium }
    media(perPage: 20) { edges { node { id } } }
  `;

  async function searchAnime(query, { limit = 12 } = {}) {
    const text = normalizeText(query);
    if (!text) return [];
    const size = clampLimit(limit, 12);
    const key = `search:anime:${text}:${size}`;
    const value = await cached(key, async () => {
      const jikanItems = await (async () => {
        const body = await jikan("anime", {
          q: text,
          limit: size,
          order_by: "members",
          sort: "desc",
          sfw: "true",
        });
        return (Array.isArray(body.data) ? body.data : [])
          .map((item) => mapJikanAnime(item))
          .filter(Boolean);
      })();
      if (jikanItems.length > 0) return jikanItems;
      const body = await anilist(
        `query ($search: String, $perPage: Int) {
           Page(page: 1, perPage: $perPage) {
             media(search: $search, type: ANIME, sort: POPULARITY_DESC) { ${ANIME_FIELDS} }
           }
         }`,
        { search: query, perPage: size },
      );
      const nodes = body && body.data && body.data.Page && body.data.Page.media;
      return (Array.isArray(nodes) ? nodes : []).map(mapAniListAnime).filter(Boolean);
    });
    return (Array.isArray(value) ? value : []).slice(0, size);
  }

  async function getAnime(id) {
    const parsed = splitId(id);
    if (!parsed) return null;
    const key = `anime:${id}`;
    const value = await cached(
      key,
      async () => {
        if (parsed.source === "jikan") {
          const body = await jikan(`anime/${parsed.sourceId}/full`);
          return mapJikanAnime(body && body.data, { full: true });
        }
        const body = await anilist(
          `query ($id: Int) { Media(id: $id, type: ANIME) { ${ANIME_FIELDS} } }`,
          { id: parsed.sourceId },
        );
        return mapAniListAnime(body && body.data && body.data.Media);
      },
      detailTtlMs,
    ).catch(() => null);
    return value || null;
  }

  async function searchCharacters(query, { limit = 20, animeId = null } = {}) {
    const text = normalizeText(query);
    const size = clampLimit(limit, 20);
    if (!text && !animeId) return [];
    const key = animeId
      ? `characters:anime:${animeId}:${size}`
      : `search:character:${text}:${size}`;
    const value = await cached(key, async () => {
      if (animeId) {
        const anime = await getAnime(animeId);
        if (!anime || anime.source !== "jikan") return [];
        const body = await jikan(`anime/${anime.sourceId}/characters`);
        return (Array.isArray(body && body.data) ? body.data : [])
          .map((entry) => {
            const character = mapJikanCharacter(entry && entry.character);
            if (!character) return null;
            return { ...character, animeIds: [anime.id] };
          })
          .filter(Boolean)
          .slice(0, size);
      }
      const jikanItems = await (async () => {
        const body = await jikan("characters", { q: text, limit: size, order_by: "favorites", sort: "desc" });
        return (Array.isArray(body.data) ? body.data : [])
          .map((item) => mapJikanCharacter(item))
          .filter(Boolean);
      })();
      if (jikanItems.length > 0) return jikanItems;
      const body = await anilist(
        `query ($search: String, $perPage: Int) {
           Page(page: 1, perPage: $perPage) {
             characters(search: $search, sort: FAVOURITES_DESC) { ${CHARACTER_FIELDS} }
           }
         }`,
        { search: query, perPage: size },
      );
      const nodes = body && body.data && body.data.Page && body.data.Page.characters;
      return (Array.isArray(nodes) ? nodes : []).map(mapAniListCharacter).filter(Boolean);
    });
    return (Array.isArray(value) ? value : []).slice(0, size);
  }

  async function getCharacter(id) {
    const parsed = splitId(id);
    if (!parsed) return null;
    const key = `character:${id}`;
    const value = await cached(
      key,
      async () => {
        if (parsed.source === "jikan") {
          const body = await jikan(`characters/${parsed.sourceId}/full`);
          return mapJikanCharacter(body && body.data);
        }
        const body = await anilist(
          `query ($id: Int) { Character(id: $id) { ${CHARACTER_FIELDS} } }`,
          { id: parsed.sourceId },
        );
        return mapAniListCharacter(body && body.data && body.data.Character);
      },
      detailTtlMs,
    ).catch(() => null);
    return value || null;
  }

  // Candidate pool for a game round. Real titles only, ordered by popularity so
  // the pool stays recognizable, never fabricated.
  async function animePool({ limit = 24 } = {}) {
    const size = clampLimit(limit, SEARCH_PAGE_SIZE);
    const key = `pool:anime:${size}`;
    const value = await cached(key, async () => {
      const body = await jikan("top/anime", {
        filter: "bypopularity",
        page: "1",
        limit: String(size),
        sfw: "true",
      });
      const items = (Array.isArray(body && body.data) ? body.data : [])
        .map((item) => mapJikanAnime(item))
        .filter(Boolean);
      if (items.length > 0) return items;
      const fallback = await anilist(
        `query ($perPage: Int) {
           Page(page: 1, perPage: $perPage) {
             media(type: ANIME, sort: POPULARITY_DESC, isAdult: false) { ${ANIME_FIELDS} }
           }
         }`,
        { perPage: size },
      );
      const nodes = fallback && fallback.data && fallback.data.Page && fallback.data.Page.media;
      return (Array.isArray(nodes) ? nodes : []).map(mapAniListAnime).filter(Boolean);
    });
    return (Array.isArray(value) ? value : []).slice(0, size);
  }

  // The chain rule is published to players and re-evaluated server-side on
  // every submission: the submitted anime must share a studio, a genre/theme,
  // or be a direct relation of the title the previous player picked.
  function validateChainSubmission(previous, submitted) {
    if (!previous || !submitted) {
      return { ok: false, reason: "unknown_anime" };
    }
    if (previous.id === submitted.id) {
      return { ok: false, reason: "duplicate_anime" };
    }
    if (!sharesRelation(previous, submitted)) {
      return { ok: false, reason: "broken_chain" };
    }
    return { ok: true, reason: "valid" };
  }

  return {
    searchAnime,
    getAnime,
    searchCharacters,
    getCharacter,
    animePool,
    emojiCluesFor,
    sharesRelation,
    validateChainSubmission,
    animeToPublicSearchItem,
    characterToPublicItem,
    splitId,
    isJikanId,
    isAniListId,
  };
}

function cacheKey(raw) {
  return crypto.createHash("sha1").update(String(raw)).digest("hex");
}

async function defaultFetchJson(url, init, attempt = 0) {
  if (typeof fetch !== "function") {
    throw new Error("fetch_unavailable");
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      ...(init || {}),
      signal: controller.signal,
    });
    if (!response.ok) {
      const error = new Error(`http_${response.status}`);
      error.status = response.status;
      if (response.status === 429) {
        // Rate limited. Retry a bounded number of times, then surface the
        // failure so the caller can fall back to its stale cache entry.
        if (attempt >= PROVIDER_MAX_RETRIES) throw error;
        const retryAfter = Number(response.headers && response.headers.get("retry-after"));
        const waitMs = Number.isFinite(retryAfter) && retryAfter > 0
          ? Math.min(retryAfter * 1000, 5000)
          : PROVIDER_RETRY_MS;
        await new Promise((resolve) => setTimeout(resolve, waitMs));
        return defaultFetchJson(url, init, attempt + 1);
      }
      throw error;
    }
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  createAnimeCatalogDomain,
  mapJikanAnime,
  mapJikanCharacter,
  mapAniListAnime,
  mapAniListCharacter,
  emojiCluesFor,
  sharesRelation,
  sharesTag,
  normalizeText,
  splitId,
  isJikanId,
  isAniListId,
  CHAIN_RULE_TEXT: "The next title must share a studio, a genre, or be a direct story relation of the previous title.",
  CACHE_COLLECTION,
};
