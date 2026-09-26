"use strict";

// Offline snapshot of real catalog entries. It is never the source of truth:
// live data always comes from the canonical repository
// (`animeCatalogDomain`, Master Spec 16.2). The snapshot exists so a provider
// outage degrades a game into a still-playable round instead of a crash.
const snapshot = require("../gameCatalog");

function clampInt(value, fallback, min, max) {
  const n = Number.isInteger(value) ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function toMillis(value) {
  if (value == null) return 0;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (typeof value._millis === "number") return value._millis;
  if (typeof value.seconds === "number") {
    return value.seconds * 1000 + Math.floor((value.nanoseconds || 0) / 1e6);
  }
  return 0;
}

function isExpired(deadlineAt, now) {
  const due = toMillis(deadlineAt);
  if (!due) return false;
  return now.getTime() >= due;
}

function deadlineAt(now, seconds) {
  return new Date(now.getTime() + seconds * 1000);
}

function shuffle(list, random) {
  const next = [...list];
  const rng = typeof random === "function" ? random : Math.random;
  for (let i = next.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    [next[i], next[j]] = [next[j], next[i]];
  }
  return next;
}

function pickOne(list, random) {
  if (!list.length) return null;
  const rng = typeof random === "function" ? random : Math.random;
  return list[Math.floor(rng() * list.length)];
}

function secretRef(gameRef) {
  return gameRef.collection("secret").doc("round");
}

function privateRef(gameRef, uid) {
  return gameRef.collection("private").doc(uid);
}

function historyRef(db, gameId) {
  return db.collection("game_history").doc(gameId);
}

function emptyScores(playerIds) {
  const scores = {};
  for (const id of playerIds) scores[id] = 0;
  return scores;
}

function winnersFromScores(scores) {
  const entries = Object.entries(scores || {});
  if (entries.length === 0) {
    return { winnerIds: [], draw: true, top: 0 };
  }
  let top = -Infinity;
  for (const [, score] of entries) {
    if (score > top) top = score;
  }
  const winnerIds = entries
    .filter(([, score]) => score === top)
    .map(([id]) => id);
  return {
    winnerIds: winnerIds.length === entries.length && entries.length > 1
      ? []
      : winnerIds,
    draw: winnerIds.length !== 1,
    top,
  };
}

function assertActiveParticipant(existing, uid, HttpsError) {
  if (!existing || !existing.exists) {
    throw new HttpsError("permission-denied", "You are not a participant in this game.");
  }
  const data = existing.data() || {};
  if (data.status === "left" || data.leftAt) {
    throw new HttpsError("permission-denied", "You are not a participant in this game.");
  }
}

function rejectStale(payload, game, HttpsError) {
  if (payload && payload.stateVersion != null &&
      Number(payload.stateVersion) !== Number(game.stateVersion || 0)) {
    throw new HttpsError(
      "aborted",
      "This game state is stale. Refresh and try again.",
    );
  }
}

function bumpVersion(game) {
  return (Number(game.stateVersion) || 0) + 1;
}

// The engines must never decide from their own tables: a submitted ID is only
// accepted when the canonical repository resolves it. `catalog` is resolved
// outside the Firestore transaction by the domain, so a network call never
// happens while transaction locks are held.
function requireCatalog(ctx) {
  const catalog = ctx && ctx.catalog;
  if (!catalog || typeof catalog.getCharacter !== "function") {
    throw new Error("catalog_unavailable");
  }
  return catalog;
}

async function resolveCharacter(ctx, value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const id = value.trim();
  const catalog = requireCatalog(ctx);
  try {
    const live = await catalog.getCharacter(id);
    if (live) return live;
  } catch (_) {
    // Fall through to the snapshot below.
  }
  const fallback = snapshot.characterById(id);
  if (!fallback) return null;
  return {
    id: fallback.id,
    name: fallback.name,
    animeIds: fallback.animeId ? [fallback.animeId] : [],
    source: "snapshot",
  };
}

async function resolveAnime(ctx, value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const id = value.trim();
  const catalog = requireCatalog(ctx);
  try {
    const live = await catalog.getAnime(id);
    if (live) return live;
  } catch (_) {
    // Fall through to the snapshot below.
  }
  const fallback = snapshot.byAnimeId(id);
  if (!fallback) return null;
  return {
    ...fallback,
    id: fallback.id,
    source: "snapshot",
    relations: [],
  };
}

// A player may submit either a catalog ID (from the search UI) or a title they
// typed. The repository resolves the text — including alternative titles — and
// an exact match is required, so a fuzzy hit can never silently become a
// different title and fail a chain rule the player actually satisfied.
async function resolveAnimeByText(ctx, text) {
  if (typeof text !== "string" || !text.trim()) return null;
  const catalog = requireCatalog(ctx);
  const needle = normalizeText(text);
  const matches = await catalog.searchAnime(text, { limit: 8 });
  const exact = (Array.isArray(matches) ? matches : []).find((anime) => {
    const titles = [anime.title, ...(anime.alternativeTitles || [])];
    return titles.some((title) => normalizeText(title) === needle);
  });
  return exact || null;
}

function animeIdFromPayload(payload) {
  if (!payload || typeof payload !== "object") return null;
  const value = payload.animeId || payload.selection || payload.value;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function animeTextFromPayload(payload) {
  if (!payload || typeof payload !== "object") return null;
  const value = payload.title;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function characterIdFromPayload(payload) {
  if (!payload || typeof payload !== "object") return null;
  const value = payload.characterId || payload.value;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function normalizeText(value) {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .toLowerCase()
    .replace(/[\u064b-\u065f]/g, "")
    .replace(/[!?.:,'"\u2019()\[\]]/g, "")
    .replace(/&/g, "and")
    .replace(/\s+/g, " ");
}

async function loadAnimePool(ctx, limit) {
  const catalog = requireCatalog(ctx);
  const size = Number.isInteger(limit) ? limit : 24;
  const pool = await catalog.animePool({ limit: size });
  if (Array.isArray(pool) && pool.length >= 2) return pool;
  // Degraded mode: keep the round playable with the offline snapshot.
  return snapshot.ANIME.slice(0, size);
}

module.exports = {
  clampInt,
  toMillis,
  isExpired,
  deadlineAt,
  shuffle,
  pickOne,
  secretRef,
  privateRef,
  historyRef,
  emptyScores,
  winnersFromScores,
  assertActiveParticipant,
  rejectStale,
  bumpVersion,
  requireCatalog,
  resolveCharacter,
  resolveAnime,
  resolveAnimeByText,
  animeIdFromPayload,
  animeTextFromPayload,
  characterIdFromPayload,
  normalizeText,
  loadAnimePool,
  snapshot,
};
