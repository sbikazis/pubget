"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createHistoryWriter } = require("../src/mafia/historyWriter");

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
  increment: (n) => ({ _increment: n }),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

// Deep apply of a delta with Firestore field-path semantics. Dotted keys
// (`roleCounts.<role>`) resolve to nested paths, and leaf values carrying
// `_increment` add to the existing number (or 0) — mirroring how
// FieldValue.increment applies to nested role statistics.
function applyFields(target, source) {
  const next = clone(target) || {};
  for (const [rawKey, value] of Object.entries(source)) {
    applyAt(next, rawKey.split("."), value);
  }
  return next;
}

function applyAt(next, keys, value) {
  const key = keys[0];
  if (keys.length === 1) {
    if (
      value &&
      typeof value === "object" &&
      typeof value._increment === "number"
    ) {
      const base = typeof next[key] === "number" ? next[key] : 0;
      next[key] = base + value._increment;
    } else if (value && typeof value === "object" && !Array.isArray(value)) {
      next[key] = applyFields(next[key], value);
    } else {
      next[key] = clone(value);
    }
    return;
  }
  if (
    !next[key] ||
    typeof next[key] !== "object" ||
    next[key] instanceof Date ||
    Array.isArray(next[key])
  ) {
    next[key] = {};
  }
  applyAt(next[key], keys.slice(1), value);
}

// A path-based fake Firestore whose runTransaction models optimistic
// concurrency: reads snapshot versions, and a commit aborts+retries when a
// read document changed since it was read — matching Cloud Run transaction
// behavior closely enough to reproduce the SEC-H-02 double-increment race.
function createConflictDb(seed) {
  const store = new Map();
  for (const [path, data] of Object.entries(seed)) {
    store.set(path, { version: 0, data: clone(data) });
  }

  const makeDocRef = (base, id) => {
    const path = `${base}/${id}`;
    return {
      path,
      id,
      collection: (name) => makeCollection(`${path}/${name}`),
    };
  };
  const makeCollection = (base) => ({
    doc: (id) => makeDocRef(base, id),
    async get() {
      const prefix = `${base}/`;
      const docs = [];
      for (const path of store.keys()) {
        if (!path.startsWith(prefix)) continue;
        const rest = path.slice(prefix.length);
        if (!rest || rest.includes("/")) continue;
        docs.push({
          id: rest,
          ref: makeDocRef(base, rest),
          data: () => clone(store.get(path).data),
        });
      }
      return { docs };
    },
  });

  async function runTransaction(callback) {
    for (let attempts = 1; ; attempts += 1) {
      if (attempts > 10) throw new Error("transaction-retries-exceeded");
      const reads = [];
      const writes = [];
      let writeSeen = false;
      const transaction = {
        async get(ref) {
          if (writeSeen) throw new Error("reads-after-write-not-supported");
          const entry = store.get(ref.path);
          reads.push({ path: ref.path, version: entry ? entry.version : -1 });
          return {
            exists: entry !== undefined,
            ref,
            data: () => (entry ? clone(entry.data) : undefined),
          };
        },
        set(ref, data, options) {
          writeSeen = true;
          writes.push({ kind: "set", ref, data, options });
        },
        update(ref, data) {
          writeSeen = true;
          writes.push({ kind: "update", ref, data });
        },
      };

      let outcome;
      try {
        outcome = await callback(transaction);
      } catch (error) {
        throw error;
      }

      const conflicted = reads.some(({ path, version }) => {
        const entry = store.get(path);
        if (version === -1) return entry !== undefined;
        return entry === undefined || entry.version !== version;
      });
      if (conflicted) continue;

      for (const write of writes) {
        const entry = store.get(write.ref.path);
        const nextVersion = entry ? entry.version + 1 : 1;
        if (write.kind === "set") {
          const data = write.options && write.options.merge
            ? applyFields(entry ? entry.data : {}, write.data)
            : clone(write.data);
          store.set(write.ref.path, { version: nextVersion, data });
        } else if (write.kind === "update") {
          if (!entry) throw new Error("not-found");
          store.set(write.ref.path, {
            version: nextVersion,
            data: applyFields(entry.data, write.data),
          });
        }
      }
      return outcome;
    }
  }

  return { store, collection: makeCollection, runTransaction };
}

function seedGame() {
  return {
    "mafia_games/g1": {
      groupId: "g1",
      status: "finished",
      version: "classic",
    },
    "mafia_games/g1/players/alice": { userId: "alice", username: "Alice" },
    "mafia_games/g1/players/bob": { userId: "bob", username: "Bob" },
    "mafia_games/g1/players/alice/private/data": {
      role: "citizen",
      team: "citizens",
    },
    "mafia_games/g1/players/bob/private/data": {
      role: "mafia",
      team: "mafias",
    },
  };
}

async function playersSnapshot(db) {
  return db.collection("mafia_games/g1/players").get();
}

test("a finished game writes full history plus short history and stats once", async () => {
  const db = createConflictDb(seedGame());
  const writer = createHistoryWriter({ db, FieldValue });
  await writer.writeHistory(
    "g1",
    db.collection("mafia_games").doc("g1"),
    "citizens",
    await playersSnapshot(db),
  );

  const historyDoc = db.store.get("mafia_history/g1").data;
  assert.deepEqual(historyDoc.players, ["alice", "bob"]);
  assert.equal(historyDoc.winner, "citizens");
  assert.equal(historyDoc.version, "classic");
  assert.equal(historyDoc.playerDetails.length, 2);
  const alice = historyDoc.playerDetails.find((entry) => entry.userId === "alice");
  const bob = historyDoc.playerDetails.find((entry) => entry.userId === "bob");
  assert.equal(alice.won, true);
  assert.equal(bob.won, false);

  assert.equal(db.store.get("mafia_games/g1").data.historyWritten, true);
  assert.equal(db.store.get("users/alice/user_mafia_history/g1").data.won, true);
  assert.equal(db.store.get("users/bob/user_mafia_history/g1").data.won, false);

  const aliceStats = db.store.get("users/alice/user_mafia_history/stats").data;
  assert.equal(aliceStats.gamesPlayed, 1);
  assert.equal(aliceStats.wins, 1);
  assert.equal(aliceStats.losses, undefined);
  assert.equal(aliceStats.roleCounts.citizen, 1);

  const bobStats = db.store.get("users/bob/user_mafia_history/stats").data;
  assert.equal(bobStats.gamesPlayed, 1);
  assert.equal(bobStats.wins, undefined);
  assert.equal(bobStats.losses, 1);
  assert.equal(bobStats.roleCounts.mafia, 1);
});

test("a repeated sequential call is idempotent and does not re-increment stats", async () => {
  const db = createConflictDb(seedGame());
  const writer = createHistoryWriter({ db, FieldValue });
  const snapshot = await playersSnapshot(db);
  await writer.writeHistory("g1", db.collection("mafia_games").doc("g1"), "citizens", snapshot);
  await writer.writeHistory("g1", db.collection("mafia_games").doc("g1"), "citizens", snapshot);

  const aliceStats = db.store.get("users/alice/user_mafia_history/stats").data;
  assert.equal(aliceStats.gamesPlayed, 1);
  assert.equal(aliceStats.wins, 1);
});

test("concurrent invocations claim the history transactionally and increment stats once", async () => {
  const db = createConflictDb(seedGame());
  const snapshot = await playersSnapshot(db);
  const writer = createHistoryWriter({ db, FieldValue });
  const results = await Promise.allSettled([
    writer.writeHistory("g1", db.collection("mafia_games").doc("g1"), "citizens", snapshot),
    writer.writeHistory("g1", db.collection("mafia_games").doc("g1"), "citizens", snapshot),
  ]);

  assert.equal(results.filter((result) => result.status === "fulfilled").length, 2);
  assert.equal(results.filter((result) => result.status === "rejected").length, 0);

  const aliceStats = db.store.get("users/alice/user_mafia_history/stats").data;
  assert.equal(aliceStats.gamesPlayed, 1);
  assert.equal(aliceStats.wins, 1);
  const bobStats = db.store.get("users/bob/user_mafia_history/stats").data;
  assert.equal(bobStats.gamesPlayed, 1);
  assert.equal(bobStats.losses, 1);

  const historyDoc = db.store.get("mafia_history/g1").data;
  assert.equal(historyDoc.players.length, 2);
  assert.equal(db.store.get("mafia_games/g1").data.historyWritten, true);
});

test("a second game still merges increments onto the same stats document", async () => {
  const db = createConflictDb({
    "mafia_games/g1": {
      groupId: "g1",
      status: "finished",
      version: "classic",
      historyWritten: true,
    },
    "mafia_games/g2": {
      groupId: "g1",
      status: "finished",
      version: "classic",
    },
    "mafia_games/g2/players/alice": { userId: "alice", username: "Alice" },
    "mafia_games/g2/players/bob": { userId: "bob", username: "Bob" },
    "mafia_games/g2/players/alice/private/data": {
      role: "citizen",
      team: "citizens",
    },
    "mafia_games/g2/players/bob/private/data": {
      role: "mafia",
      team: "mafias",
    },
    "users/alice/user_mafia_history/stats": {
      gamesPlayed: 1,
      wins: 1,
      losses: 0,
      roleCounts: { citizen: 1 },
    },
    "users/bob/user_mafia_history/stats": {
      gamesPlayed: 1,
      wins: 0,
      losses: 1,
      roleCounts: { mafia: 1 },
    },
  });
  const writer = createHistoryWriter({ db, FieldValue });
  await writer.writeHistory(
    "g2",
    db.collection("mafia_games").doc("g2"),
    "citizens",
    await db.collection("mafia_games/g2/players").get(),
  );

  const aliceStats = db.store.get("users/alice/user_mafia_history/stats").data;
  assert.equal(aliceStats.gamesPlayed, 2);
  assert.equal(aliceStats.wins, 2);
  assert.equal(aliceStats.roleCounts.citizen, 2);
  const bobStats = db.store.get("users/bob/user_mafia_history/stats").data;
  assert.equal(bobStats.gamesPlayed, 2);
  assert.equal(bobStats.losses, 2);
  assert.equal(bobStats.roleCounts.mafia, 2);
});