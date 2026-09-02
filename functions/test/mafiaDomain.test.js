"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  PHASES,
  assignRoles,
  canTransitionPhase,
  checkWinner,
  createMafiaDomain,
  defaultRoleCounts,
  resolveNight,
  resolveRoleCounts,
  resolveVotes,
  validateMafiaConfig,
} = require("../src/mafiaDomain");
const { createGamesDomain } = require("../src/gamesDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
  increment: (value) => ({ _increment: value }),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

function applyUpdate(current, data) {
  const next = clone(current);
  for (const [key, value] of Object.entries(data)) {
    if (value && value._increment != null) {
      next[key] = (next[key] || 0) + value._increment;
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
    doc(id) {
      const resolvedId = id || `auto-${store.size + 1}`;
      const resolvedPath = `${base}/${resolvedId}`;
      return {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return makeCollection(`${resolvedPath}/${name}`);
        },
        async set(data) {
          store.set(resolvedPath, clone(data));
        },
        async get() {
          const data = store.get(resolvedPath);
          return {
            exists: data !== undefined,
            id: resolvedId,
            ref: makeCollection(base).doc(resolvedId),
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        async update(data) {
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath) || {}, data));
        },
      };
    },
    where(field, op, value) {
      return query(base, [{ field, op, value }]);
    },
    limit(n) {
      return query(base, []).limit(n);
    },
    get() {
      return query(base, []).get();
    },
  });
  function query(base, filters) {
    const chainQuery = {
      _limit: 25,
      where(field, op, value) {
        return query(base, [...filters, { field, op, value }]);
      },
      limit(n) {
        chainQuery._limit = n;
        return chainQuery;
      },
      async get() {
        const prefix = `${base}/`;
        const docs = [];
        for (const [path, data] of store.entries()) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes("/")) {
            continue;
          }
          let ok = true;
          for (const filter of filters) {
            if (filter.op === "==" && data[filter.field] !== filter.value) ok = false;
          }
          if (ok) {
            const id = path.slice(prefix.length);
            docs.push({
              id,
              ref: makeCollection(base).doc(id),
              data: () => clone(data),
            });
          }
        }
        return { docs: docs.slice(0, chainQuery._limit) };
      },
    };
    return chainQuery;
  }
  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
    runTransaction(callback) {
      const run = chain.then(() => {
        const transaction = {
          async get(ref) {
            if (ref && typeof ref.get === "function" && typeof ref.path !== "string") {
              return ref.get();
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
          set(ref, data) {
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

function seedGroup() {
  return {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "users/charlie": { username: "Charlie" },
    "users/dana": { username: "Dana" },
    "users/eve": { username: "Eve" },
    "groups/g1": { founderId: "alice", name: "G" },
    "groups/g1/members/alice": { role: "founder", userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/members/dana": { role: "member", userId: "dana" },
    "groups/g1/members/eve": { role: "member", userId: "eve" },
    "groups/g1/roles/founder": { permissions: ["manageGames", "manageEvents"] },
    "groups/g1/roles/member": { permissions: [] },
  };
}

function zeroBytes() {
  return Buffer.alloc(4);
}

function handlers(db, notificationBuilder) {
  const mafia = createMafiaDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    notificationBuilder,
    randomBytes: zeroBytes,
  });
  const games = createGamesDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    notificationBuilder,
    mafia,
  });
  return { games, mafia };
}

async function startFourPlayerMafia(games) {
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "mafia", title: "Night", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.joinGame({ auth: { uid: "dana" }, data: { gameId: created.gameId } });
  await games.joinGame({ auth: { uid: "eve" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  return created.gameId;
}

test("phase machine allows documented edges and rejects jumps", () => {
  assert.equal(canTransitionPhase("setup", "night"), true);
  assert.equal(canTransitionPhase("night", "day"), true);
  assert.equal(canTransitionPhase("night", "voting"), false);
  assert.equal(canTransitionPhase("finished", "night"), false);
  assert.ok(PHASES.includes("resolution"));
});

test("role counts match the documented defaults", () => {
  assert.deepEqual(defaultRoleCounts(4), {
    mafiaCount: 1, doctorCount: 0, detectiveCount: 0, civilianCount: 3,
  });
  assert.equal(defaultRoleCounts(5).doctorCount, 1);
  assert.equal(defaultRoleCounts(6).detectiveCount, 1);
  assert.equal(resolveRoleCounts(3), null);
});

test("configuration is clamped server-side", () => {
  const config = validateMafiaConfig({
    minPlayers: 2,
    maxPlayers: 99,
    extra: { nightDurationSeconds: 1, mafiaCount: 1 },
  });
  assert.equal(config.minPlayers, 4);
  assert.equal(config.maxPlayers, 16);
  assert.equal(config.extra.nightDurationSeconds, 10);
  assert.equal(config.extra.deadCanChat, false);
});

test("assignRoles is deterministic with an injected byte source", () => {
  const roles = assignRoles(["dana", "alice", "bob", "eve"], {
    mafiaCount: 1, detectiveCount: 0, doctorCount: 0, civilianCount: 3,
  }, zeroBytes);
  assert.equal(Object.keys(roles).length, 4);
  assert.equal(Object.values(roles).filter((role) => role === "mafia").length, 1);
  const again = assignRoles(["eve", "bob", "alice", "dana"], {
    mafiaCount: 1, detectiveCount: 0, doctorCount: 0, civilianCount: 3,
  }, zeroBytes);
  assert.deepEqual(roles, again);
});

test("night and vote resolution follow plurality with ties as no-elim", () => {
  const roles = { alice: "mafia", bob: "civilian", dana: "doctor", eve: "detective" };
  const alive = { alice: true, bob: true, dana: true, eve: true };
  const killed = resolveNight({ roles, alive, kills: { alice: "bob" }, protect: null });
  assert.equal(killed.eliminatedUserId, "bob");
  const saved = resolveNight({ roles, alive, kills: { alice: "bob" }, protect: "bob" });
  assert.equal(saved.saved, true);
  assert.equal(saved.eliminatedUserId, null);
  const votes = resolveVotes({
    roles, alive, votes: { bob: "alice", dana: "eve", eve: "alice" },
  });
  assert.equal(votes.winnerId, "alice");
  const tied = resolveVotes({
    roles, alive, votes: { bob: "alice", dana: "eve" },
  });
  assert.equal(tied.winnerId, null);
  assert.equal(tied.tied, true);
});

test("win conditions are server calculated", () => {
  assert.equal(checkWinner(
    { alice: "mafia", bob: "civilian" },
    { alice: false, bob: true },
  ), "town");
  assert.equal(checkWinner(
    { alice: "mafia", bob: "civilian" },
    { alice: true, bob: true },
  ), "mafia");
  assert.equal(checkWinner(
    { alice: "mafia", bob: "civilian", dana: "civilian" },
    { alice: true, bob: true, dana: true },
  ), null);
});

test("start assigns private roles and never writes public role maps", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  const game = db.store.get(`games/${gameId}`);
  assert.equal(game.status, "active");
  assert.equal(game.mafia.phase, "night");
  assert.equal(game.mafia.roles, undefined);
  const secret = db.store.get(`games/${gameId}/secret/state`);
  assert.ok(secret.roles.alice);
  const alicePrivate = db.store.get(`games/${gameId}/private/alice`);
  assert.ok(["mafia", "civilian", "detective", "doctor"].includes(alicePrivate.role));
  const bobPrivate = db.store.get(`games/${gameId}/private/bob`);
  assert.notEqual(alicePrivate.role && bobPrivate.role ? true : false, false);
  const chatWrites = [...db.store.keys()].filter((path) => path.includes("/messages/"));
  assert.equal(chatWrites.length, 0);
});

test("start is rejected below the minimum player count", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "mafia", title: "Night", groupId: "g1" },
  });
  await assert.rejects(
    games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
});

test("duplicate start does not reassign roles", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  const first = clone(db.store.get(`games/${gameId}/secret/state`).roles);
  await games.startGame({ auth: { uid: "alice" }, data: { gameId } });
  assert.deepEqual(db.store.get(`games/${gameId}/secret/state`).roles, first);
});

test("leave is blocked after Mafia starts", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  await assert.rejects(
    games.leaveGame({ auth: { uid: "bob" }, data: { gameId } }),
    (error) => error.code === "failed-precondition",
  );
});

test("mafia night action, civilian rejection, impersonation, and duplicates", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  const roles = db.store.get(`games/${gameId}/secret/state`).roles;
  const mafiaId = Object.keys(roles).find((id) => roles[id] === "mafia");
  const civilianId = Object.keys(roles).find((id) => roles[id] === "civilian");
  const targetId = Object.keys(roles).find((id) => id !== mafiaId && roles[id] !== "mafia");
  await games.submitGameAction({
    auth: { uid: mafiaId },
    data: { gameId, actionType: "mafia_kill", payload: { targetId } },
  });
  await games.submitGameAction({
    auth: { uid: mafiaId },
    data: { gameId, actionType: "mafia_kill", payload: { targetId } },
  });
  const night = db.store.get(`games/${gameId}/secret/state`).night;
  assert.equal(night[1].kills[mafiaId], targetId);
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: civilianId },
      data: { gameId, actionType: "mafia_kill", payload: { targetId: mafiaId } },
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: mafiaId },
      data: {
        gameId,
        actionType: "mafia_kill",
        payload: { targetId },
        playerId: civilianId,
      },
    }),
    (error) => error.code === "permission-denied",
  );
  const publicActions = [...db.store.keys()].filter((path) => path.includes("/actions/"));
  assert.equal(publicActions.length, 0);
});

test("night resolution, doctor save, detective privacy, and idempotent advance", async () => {
  const db = createFakeDb(seedGroup());
  const { games, mafia } = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: {
      type: "mafia",
      title: "Night",
      groupId: "g1",
      configuration: {
        extra: { mafiaCount: 1, detectiveCount: 1, doctorCount: 1, nightDurationSeconds: 10 },
      },
    },
  });
  const gameId = created.gameId;
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId } });
  await games.joinGame({ auth: { uid: "dana" }, data: { gameId } });
  await games.joinGame({ auth: { uid: "eve" }, data: { gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId } });
  const roles = db.store.get(`games/${gameId}/secret/state`).roles;
  const mafiaId = Object.keys(roles).find((id) => roles[id] === "mafia");
  const doctorId = Object.keys(roles).find((id) => roles[id] === "doctor");
  const detectiveId = Object.keys(roles).find((id) => roles[id] === "detective");
  const civilianId = Object.keys(roles).find((id) => roles[id] === "civilian");
  await games.submitGameAction({
    auth: { uid: mafiaId },
    data: { gameId, actionType: "mafia_kill", payload: { targetId: civilianId } },
  });
  await games.submitGameAction({
    auth: { uid: doctorId },
    data: { gameId, actionType: "mafia_protect", payload: { targetId: civilianId } },
  });
  await games.submitGameAction({
    auth: { uid: detectiveId },
    data: { gameId, actionType: "mafia_investigate", payload: { targetId: mafiaId } },
  });
  const current = db.store.get(`games/${gameId}`);
  current.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, current);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  const after = db.store.get(`games/${gameId}`);
  assert.equal(after.mafia.phase, "day");
  assert.equal(after.mafia.lastNight.saved, true);
  assert.equal(after.mafia.lastNight.eliminatedUserId, null);
  assert.equal(db.store.get(`games/${gameId}/participants/${civilianId}`).isAlive, true);
  const detectivePrivate = db.store.get(`games/${gameId}/private/${detectiveId}`);
  assert.equal(detectivePrivate.investigation.isMafia, true);
  assert.equal(after.mafia.lastNight.investigation, undefined);
  const events = [...db.store.values()].filter((data) => data && data.type === "mafia_night_resolved");
  assert.equal(events.length, 1);
  assert.equal(events[0].payload.isMafia, undefined);
});

test("dead players cannot vote and vote resolution is idempotent", async () => {
  const db = createFakeDb(seedGroup());
  const { games, mafia } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  const roles = db.store.get(`games/${gameId}/secret/state`).roles;
  const mafiaId = Object.keys(roles).find((id) => roles[id] === "mafia");
  const town = Object.keys(roles).filter((id) => roles[id] !== "mafia");
  await games.submitGameAction({
    auth: { uid: mafiaId },
    data: { gameId, actionType: "mafia_kill", payload: { targetId: town[0] } },
  });
  const night = db.store.get(`games/${gameId}`);
  night.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, night);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  const day = db.store.get(`games/${gameId}`);
  day.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, day);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  const discussion = db.store.get(`games/${gameId}`);
  discussion.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, discussion);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  assert.equal(db.store.get(`games/${gameId}`).mafia.phase, "voting");
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: town[0] },
      data: { gameId, actionType: "mafia_vote", payload: { targetId: mafiaId } },
    }),
    (error) => error.code === "failed-precondition",
  );
  await games.submitGameAction({
    auth: { uid: town[1] },
    data: { gameId, actionType: "mafia_vote", payload: { targetId: mafiaId } },
  });
  await games.submitGameAction({
    auth: { uid: town[2] },
    data: { gameId, actionType: "mafia_vote", payload: { targetId: mafiaId } },
  });
  const voting = db.store.get(`games/${gameId}`);
  voting.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, voting);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  const completed = db.store.get(`games/${gameId}`);
  assert.equal(completed.status, "completed");
  assert.equal(completed.mafia.winner, "town");
  assert.equal(completed.result.summary.roles[mafiaId], "mafia");
  const voteEvents = [...db.store.values()].filter((data) => data && data.type === "mafia_vote_resolved");
  assert.equal(voteEvents.length, 1);
});

test("clients cannot submit a winner through actions", async () => {
  const db = createFakeDb(seedGroup());
  const { games } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "alice" },
      data: { gameId, actionType: "mafia_win", payload: { winner: "mafia" } },
    }),
    (error) => error.code === "invalid-argument",
  );
  assert.equal(db.store.get(`games/${gameId}`).mafia.winner, null);
});

test("concurrent votes keep a single authoritative tally", async () => {
  const db = createFakeDb(seedGroup());
  const { games, mafia } = handlers(db);
  const gameId = await startFourPlayerMafia(games);
  const current = db.store.get(`games/${gameId}`);
  current.mafia.phase = "voting";
  current.mafia.phaseEndsAt = new Date(Date.now() + 60000);
  db.store.set(`games/${gameId}`, current);
  const roles = db.store.get(`games/${gameId}/secret/state`).roles;
  const mafiaId = Object.keys(roles).find((id) => roles[id] === "mafia");
  const town = Object.keys(roles).filter((id) => roles[id] !== "mafia");
  await Promise.all([
    games.submitGameAction({
      auth: { uid: town[0] },
      data: { gameId, actionType: "mafia_vote", payload: { targetId: mafiaId } },
    }),
    games.submitGameAction({
      auth: { uid: town[1] },
      data: { gameId, actionType: "mafia_vote", payload: { targetId: mafiaId } },
    }),
  ]);
  const votes = db.store.get(`games/${gameId}/secret/state`).votes[1];
  assert.equal(votes[town[0]], mafiaId);
  assert.equal(votes[town[1]], mafiaId);
  current.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, db.store.get(`games/${gameId}`));
  const latest = db.store.get(`games/${gameId}`);
  latest.mafia.phase = "voting";
  latest.mafia.phaseEndsAt = new Date(Date.now() - 1000);
  db.store.set(`games/${gameId}`, latest);
  await mafia.advanceMafiaPhase({ auth: { uid: "alice" }, data: { gameId } });
  assert.equal(db.store.get(`games/${gameId}`).mafia.lastVote.eliminatedUserId, mafiaId);
});

test("unauthenticated mafia mutations are rejected", async () => {
  const db = createFakeDb(seedGroup());
  const { mafia } = handlers(db);
  await assert.rejects(
    mafia.advanceMafiaPhase({ data: { gameId: "x" } }),
    (error) => error.code === "unauthenticated",
  );
});
