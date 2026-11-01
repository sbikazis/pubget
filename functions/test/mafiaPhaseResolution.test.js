"use strict";

// Concurrency and idempotency guarantees for the two paths that end a phase:
// night resolution and vote resolution. Both used to read their inputs outside
// any transaction, so a scheduler retry, a lease expiry, or two overlapping
// invocations could resolve the same night or the same vote twice.

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-mafia-phases" });
}

const { resolveNight } = require("../src/mafia/nightResolver");
const { resolveVotes } = require("../src/mafia/voteResolver");
const { checkWinCondition } = require("../src/mafia/winConditionChecker");

const TIMESTAMP_MARKER = "__timestamp__";
const DELETE_MARKER = "__delete__";

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = {
  serverTimestamp: () => TIMESTAMP_MARKER,
  arrayUnion: (...values) => ({ _arrayUnion: values }),
  delete: () => DELETE_MARKER,
};

const Timestamp = {
  now: () => new Date("2026-09-03T12:00:00Z"),
  fromMillis: (ms) => new Date(ms),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

// The resolvers use the real `admin.firestore.FieldValue` transforms, so this
// fake understands those sentinels instead of a stand-in of its own.
function isTransform(value, name) {
  return Boolean(value) && typeof value === "object" &&
    value.constructor && value.constructor.name === `${name}Transform`;
}

function applyUpdate(current, data) {
  const next = clone(current) || {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value === DELETE_MARKER || isTransform(value, "Delete")) {
      delete next[key];
      continue;
    }
    if (isTransform(value, "ArrayUnion")) {
      const existing = Array.isArray(next[key]) ? next[key] : [];
      const merged = existing.slice();
      for (const item of value.elements || []) {
        const encoded = JSON.stringify(item);
        if (!merged.some((entry) => JSON.stringify(entry) === encoded)) merged.push(item);
      }
      next[key] = merged;
      continue;
    }
    if (isTransform(value, "NumericIncrement")) {
      next[key] = (next[key] || 0) + (value.operand || 1);
      continue;
    }
    next[key] = clone(value);
  }
  return next;
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  let chain = Promise.resolve();
  const makeCollection = (base) => ({
    _isCollection: true,
    doc(id) {
      const resolvedId = id || `auto-${store.size + 1}`;
      const resolvedPath = `${base}/${resolvedId}`;
      return {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return makeCollection(`${resolvedPath}/${name}`);
        },
        async set(data, options) {
          if (options && options.merge) {
            store.set(resolvedPath, applyUpdate(store.get(resolvedPath), data));
            return;
          }
          store.set(resolvedPath, clone(data));
        },
        async get() {
          const data = store.get(resolvedPath);
          return {
            exists: data !== undefined,
            id: resolvedId,
            path: resolvedPath,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        async update(data) {
          if (!store.has(resolvedPath)) throw new Error("not-found");
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath), data));
        },
      };
    },
    where(field, op, value) {
      return query(base, [{ field, op, value }]);
    },
    async get() {
      return query(base, []).get();
    },
  });
  function query(base, filters) {
    return {
      async get() {
        const prefix = `${base}/`;
        const docs = [];
        for (const [path, data] of store.entries()) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes("/")) continue;
          if (!filters.every((filter) => data[filter.field] === filter.value)) continue;
          docs.push({
            id: path.slice(prefix.length),
            ref: makeCollection(base).doc(path.slice(prefix.length)),
            data: () => clone(data),
          });
        }
        return { docs };
      },
    };
  }
  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
    fieldValue: FieldValue,
    timestamp: Timestamp,
    runTransaction(callback) {
      const run = chain.then(() => {
        const transaction = {
          async get(ref) {
            // The real Firestore SDK only accepts a DocumentReference here.
            // Anything else throws, so the fake refuses it too instead of
            // quietly standing in for an API that does not exist.
            if (!ref || typeof ref.path !== "string" || ref._isCollection ||
                typeof ref.id !== "string") {
              throw new Error(
                "transaction-get-invalid-ref: a transaction may only read a document",
              );
            }
            const data = store.get(ref.path);
            return {
              exists: data !== undefined,
              ref,
              data: () => (data === undefined ? undefined : clone(data)),
            };
          },
          create(ref, data) {
            if (store.has(ref.path)) throw new Error("already-exists");
            store.set(ref.path, clone(data));
          },
          set(ref, data, options) {
            if (options && options.merge) {
              store.set(ref.path, applyUpdate(store.get(ref.path), data));
              return;
            }
            store.set(ref.path, clone(data));
          },
          update(ref, data) {
            if (!store.has(ref.path)) throw new Error("not-found");
            store.set(ref.path, applyUpdate(store.get(ref.path), data));
          },
          delete(ref) {
            store.delete(ref.path);
          },
        };
        return callback(transaction);
      });
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

function player(uid, role, team, isAlive = true) {
  return {
    username: uid,
    isAlive,
    hasLeft: false,
    canVote: isAlive,
    canSpeak: isAlive,
    canUseAbility: isAlive,
    revealedRole: false,
  };
}

function playerDoc(uid, role, team, isAlive = true) {
  return {
    [`mafia_games/g1/players/${uid}`]: player(uid, role, team, isAlive),
    [`mafia_games/g1/players/${uid}/private/data`]: { role, team },
  };
}

function groupGame(overrides = {}) {
  return {
    status: "DAY",
    currentPhase: "DAY",
    currentNight: 1,
    currentDay: 2,
    groupId: "grp",
    ...overrides,
  };
}

function nightGame(overrides = {}) {
  return {
    status: "NIGHT",
    currentPhase: "NIGHT",
    currentNight: 2,
    currentDay: 1,
    groupId: "g1",
    ...overrides,
  };
}

test("a night resolves exactly once even when invoked concurrently", async () => {
  const db = createFakeDb({
    "mafia_games/g1": nightGame(),
    ...playerDoc("m1", "mafia", "mafias"),
    ...playerDoc("m2", "don", "mafias"),
    ...playerDoc("doc", "doctor", "citizens"),
    ...playerDoc("det", "detective", "citizens"),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    "mafia_games/g1/night_actions/a1": {
      nightNumber: 2,
      playerId: "m1",
      targetId: "t1",
    },
    "mafia_games/g1/night_actions/a2": {
      nightNumber: 2,
      playerId: "m2",
      targetId: "t1",
    },
  });
  const deps = { db, postFromActivity: async () => null };
  const gameData = { currentNight: 2, groupId: "g1" };
  const results = await Promise.all([
    resolveNight("g1", gameData, deps),
    resolveNight("g1", gameData, deps),
    resolveNight("g1", gameData, deps),
  ]);
  assert.equal(results.filter(Boolean).length, 1, "exactly one invocation may resolve");
  const game = db.store.get("mafia_games/g1");
  assert.deepEqual(game.resolvedNights, [2]);
  assert.equal(game.eliminations.length, 1);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, false);
  // A third, later invocation is still a no-op.
  assert.equal(await resolveNight("g1", gameData, deps), false);
});

test("a night does not resolve once the phase has moved on", async () => {
  const db = createFakeDb({
    "mafia_games/g1": nightGame({ currentPhase: "DAY", status: "DAY" }),
    ...playerDoc("m1", "mafia", "mafias"),
    ...playerDoc("t1", "citizen", "citizens"),
    "mafia_games/g1/night_actions/a1": { nightNumber: 2, playerId: "m1", targetId: "t1" },
  });
  const deps = { db, postFromActivity: async () => null };
  assert.equal(await resolveNight("g1", { currentNight: 2 }, deps), false);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1").resolvedNights, undefined);
});

test("a stale night number never applies its kills", async () => {
  const db = createFakeDb({
    "mafia_games/g1": nightGame({ currentNight: 3 }),
    ...playerDoc("m1", "mafia", "mafias"),
    ...playerDoc("t1", "citizen", "citizens"),
    "mafia_games/g1/night_actions/a1": { nightNumber: 3, playerId: "m1", targetId: "t1" },
  });
  const deps = { db, postFromActivity: async () => null };
  // The scheduler was handed night 2 but the game has already rolled to 3.
  assert.equal(await resolveNight("g1", { currentNight: 2 }, deps), false);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
});

test("a night elimination reveals the role and opens last words", async () => {
  const db = createFakeDb({
    "mafia_games/g1": nightGame(),
    ...playerDoc("m1", "mafia", "mafias"),
    ...playerDoc("det", "detective", "citizens"),
    "mafia_games/g1/night_actions/a1": { nightNumber: 2, playerId: "m1", targetId: "det" },
  });
  const deps = { db, postFromActivity: async () => null };
  assert.equal(await resolveNight("g1", { currentNight: 2 }, deps), true);
  const dead = db.store.get("mafia_games/g1/players/det");
  assert.equal(dead.isAlive, false);
  assert.equal(dead.revealedRole, true, "13.7: an elimination reveals the role");
  assert.equal(dead.canSayLastWords, true);
  assert.equal(dead.canVote, false);
  assert.equal(dead.canSpeak, false);
  assert.equal(dead.canUseAbility, false);
  // The role value itself stays in the private subcollection until the game
  // ends; the table learns it from the public timeline instead.
  assert.equal(dead.role, undefined);
  assert.equal(
    db.store.get("mafia_games/g1/players/det/private/data").role,
    "detective",
  );
  const killed = db.store.get("mafia_games/g1/events/night-2-killed-det");
  assert.equal(killed.payload.role, "detective");
  assert.equal(
    killed.message,
    "det was killed last night. They were the Detective.",
  );
});

function voteGame(overrides = {}) {
  return {
    status: "VOTING",
    currentPhase: "VOTING",
    currentDay: 2,
    currentNight: 1,
    groupId: "g1",
    voteRound: 1,
    ...overrides,
  };
}

test("a vote executes exactly once even when invoked concurrently", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame(),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    ...playerDoc("t3", "detective", "citizens"),
    ...playerDoc("t4", "citizen", "citizens"),
    "mafia_games/g1/votes/v1": { dayNumber: 2, voteRound: 1, voterId: "t1", targetId: "t3" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voteRound: 1, voterId: "t2", targetId: "t3" },
    "mafia_games/g1/votes/v3": { dayNumber: 2, voteRound: 1, voterId: "t3", targetId: "t3" },
    "mafia_games/g1/votes/v4": { dayNumber: 2, voteRound: 1, voterId: "t4", targetId: "t1" },
  });
  const deps = { db };
  const gameData = { currentDay: 2 };
  const results = await Promise.all([
    resolveVotes("g1", gameData, deps),
    resolveVotes("g1", gameData, deps),
    resolveVotes("g1", gameData, deps),
  ]);
  assert.equal(results.filter(Boolean).length, 1, "exactly one invocation may execute");
  const game = db.store.get("mafia_games/g1");
  assert.equal(game.currentPhase, "VOTE_RESULT");
  assert.deepEqual(game.resolvedVoteRounds, ["2:1"]);
  assert.equal(game.votingResults.length, 1);
  assert.equal(game.eliminations.length, 1);
  const dead = db.store.get("mafia_games/g1/players/t3");
  assert.equal(dead.isAlive, false);
  assert.equal(dead.revealedRole, true);
  assert.equal(await resolveVotes("g1", gameData, deps), false);
});

test("a stale day never executes a tally", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame({ currentDay: 3 }),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    "mafia_games/g1/votes/v1": { dayNumber: 2, voterId: "t1", targetId: "t2" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voterId: "t2", targetId: "t1" },
  });
  const deps = { db };
  // Same phase name, different day: a phase-only guard would have let this pass.
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), false);
  assert.equal(db.store.get("mafia_games/g1").currentPhase, "VOTING");
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1/players/t2").isAlive, true);
});

test("a re-vote tie opens one re-vote and never executes anyone", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame(),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    ...playerDoc("t3", "citizen", "citizens"),
    ...playerDoc("t4", "citizen", "citizens"),
    "mafia_games/g1/votes/v1": { dayNumber: 2, voteRound: 1, voterId: "t1", targetId: "t2" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voteRound: 1, voterId: "t2", targetId: "t1" },
    "mafia_games/g1/votes/v3": { dayNumber: 2, voteRound: 1, voterId: "t3", targetId: "t1" },
    "mafia_games/g1/votes/v4": { dayNumber: 2, voteRound: 1, voterId: "t4", targetId: "t2" },
  });
  const deps = { db };
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), true);
  const game = db.store.get("mafia_games/g1");
  assert.equal(game.voteRound, 2);
  assert.deepEqual([...game.revoteCandidates].sort(), ["t1", "t2"]);
  assert.equal(game.currentPhase, "VOTING", "a tie re-opens voting, it does not execute");
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1/players/t2").isAlive, true);
  assert.deepEqual(db.store.get("mafia_games/g1").resolvedVoteRounds, ["2:1"]);

  // Master Spec 13.7: the game may never freeze. Once the re-vote window closes
  // with nobody having voted again, the round resolves as a skip instead of
  // replaying the first round or waiting forever.
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), true);
  const settled = db.store.get("mafia_games/g1");
  assert.equal(settled.currentPhase, "VOTE_RESULT");
  assert.deepEqual(settled.resolvedVoteRounds, ["2:1", "2:2"]);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1/players/t2").isAlive, true);
});

test("a second tie skips the elimination and moves on", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame({ voteRound: 2, revoteCandidates: ["t1", "t2"] }),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    ...playerDoc("t3", "citizen", "citizens"),
    ...playerDoc("t4", "citizen", "citizens"),
    "mafia_games/g1/votes/v1": { dayNumber: 2, voteRound: 2, voterId: "t1", targetId: "t2" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voteRound: 2, voterId: "t2", targetId: "t1" },
    "mafia_games/g1/votes/v3": { dayNumber: 2, voteRound: 2, voterId: "t3", targetId: "t1" },
    "mafia_games/g1/votes/v4": { dayNumber: 2, voteRound: 2, voterId: "t4", targetId: "t2" },
  });
  const deps = { db };
  // Master Spec 13.7: a tie re-votes between the tied players, and a tie that
  // survives the re-vote eliminates nobody and moves on to the next night.
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), true);
  const game = db.store.get("mafia_games/g1");
  assert.equal(game.currentPhase, "VOTE_RESULT");
  assert.equal(game.revoteCandidates, undefined);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1/players/t2").isAlive, true);
  assert.ok(
    db.store.get("mafia_games/g1/events/vote-2-revote-resolved"),
    "the skip is still recorded for the timeline",
  );
});

test("an abstaining disconnected player never freezes the vote", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame(),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    "mafia_games/g1/players/away": {
      ...player("away", "citizen", "citizens"),
      isDisconnected: true,
      hasLeft: true,
    },
    "mafia_games/g1/votes/v1": { dayNumber: 2, voterId: "t1", targetId: "t2" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voterId: "t2", targetId: "t1" },
  });
  const deps = { db };
  // A tie among the two remaining players; the absent third vote is an
  // abstention, so this resolves rather than stalling forever.
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), true);
  const game = db.store.get("mafia_games/g1");
  assert.equal(game.voteRound, 2);
  assert.equal(db.store.get("mafia_games/g1/players/away").isAlive, true);
});

test("a re-vote never re-counts the first round's ballots", async () => {
  const db = createFakeDb({
    "mafia_games/g1": voteGame({ voteRound: 2, revoteCandidates: ["t1", "t2"] }),
    ...playerDoc("t1", "citizen", "citizens"),
    ...playerDoc("t2", "citizen", "citizens"),
    ...playerDoc("t3", "citizen", "citizens"),
    ...playerDoc("t4", "citizen", "citizens"),
    // Round one: a 2-2 tie between t1 and t2.
    "mafia_games/g1/votes/v1": { dayNumber: 2, voteRound: 1, voterId: "t1", targetId: "t2" },
    "mafia_games/g1/votes/v2": { dayNumber: 2, voteRound: 1, voterId: "t2", targetId: "t1" },
    "mafia_games/g1/votes/v3": { dayNumber: 2, voteRound: 1, voterId: "t3", targetId: "t1" },
    "mafia_games/g1/votes/v4": { dayNumber: 2, voteRound: 1, voterId: "t4", targetId: "t2" },
  });
  const deps = { db };
  // Nobody has voted again yet, so the re-vote has no ballots of its own and
  // must resolve as a skip rather than replaying round one forever.
  assert.equal(await resolveVotes("g1", { currentDay: 2 }, deps), true);
  const game = db.store.get("mafia_games/g1");
  assert.equal(game.currentPhase, "VOTE_RESULT");
  assert.deepEqual(game.resolvedVoteRounds, ["2:2"]);
  assert.equal(db.store.get("mafia_games/g1/players/t1").isAlive, true);
  assert.equal(db.store.get("mafia_games/g1/players/t2").isAlive, true);
});

test("a finished game reveals every final role", async () => {
  const db = createFakeDb({
    "mafia_games/g1": groupGame({ status: "RESOLUTION", currentPhase: "RESOLUTION" }),
    "groups/grp": { activeGameId: "g1", gameStatus: "DAY", hasRunningGame: true },
    ...playerDoc("m1", "mafia", "mafias", false),
    ...playerDoc("m2", "mafia", "mafias", false),
    ...playerDoc("don", "don", "mafias", false),
    ...playerDoc("doc", "doctor", "citizens"),
    ...playerDoc("det", "detective", "citizens"),
    ...playerDoc("t1", "citizen", "citizens"),
  });
  const rewards = [];
  const history = [];
  const deps = {
    db,
    writeHistory: async (_gameId, _ref, winner) => history.push(winner),
    distributeRewards: async (_gameId, _ref, winner, snap) => {
      rewards.push(winner);
      assert.equal(snap.docs.length, 6);
    },
    postFromActivity: async () => null,
  };

  // The mafia are all dead and the game is still nominally running. The win
  // must be declared and the whole board published, not just the players who
  // happened to still be alive.
  assert.equal(await checkWinCondition("g1", db.store.get("mafia_games/g1"), deps), true);

  const game = db.store.get("mafia_games/g1");
  assert.equal(game.status, "GAME_OVER");
  assert.equal(game.currentPhase, "GAME_OVER");
  assert.equal(game.winner, "citizens");
  assert.equal(game.phaseEndsAt, undefined);
  assert.deepEqual(history, ["citizens"]);
  assert.deepEqual(rewards, ["citizens"]);

  for (const uid of ["m1", "m2", "don", "doc", "det", "t1"]) {
    const doc = db.store.get(`mafia_games/g1/players/${uid}`);
    assert.equal(doc.revealedRole, true, `${uid} must be revealed`);
    assert.equal(typeof doc.role, "string");
    assert.notEqual(doc.role, "");
  }
  assert.equal(db.store.get("mafia_games/g1/players/don").role, "don");
  assert.equal(db.store.get("mafia_games/g1/players/doc").role, "doctor");
  assert.equal(db.store.get("mafia_games/g1/players/m1").isAlive, false);

  const finished = db.store.get("mafia_games/g1/events/game-finished");
  assert.equal(finished.payload.winner, "citizens");
  assert.deepEqual(
    finished.payload.revealedRoles.map((entry) => entry.role).sort(),
    ["citizen", "detective", "doctor", "don", "mafia", "mafia"],
  );
  // The group stops advertising the finished game as its active one.
  assert.deepEqual(db.store.get("groups/grp"), { hasRunningGame: false });

  // A second check is a no-op: the game is terminal, so no history or rewards.
  assert.equal(await checkWinCondition("g1", game, deps), undefined);
  assert.deepEqual(history, ["citizens"]);
  assert.deepEqual(rewards, ["citizens"]);
});
