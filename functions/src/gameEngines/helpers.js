"use strict";

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
};
