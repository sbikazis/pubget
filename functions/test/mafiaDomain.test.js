"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createMafiaDomain } = require("../src/mafia/mafiaDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
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
  const next = clone(current) || {};
  for (const [key, value] of Object.entries(data)) {
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
      };
    },
    async get() {
      const prefix = `${base}/`;
      const docs = [];
      for (const [path, data] of store) {
        if (!path.startsWith(prefix)) continue;
        const rest = path.slice(prefix.length);
        if (!rest || rest.includes("/")) continue;
        docs.push({
          id: rest,
          data: () => clone(data),
        });
      }
      return { docs };
    },
  });
  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
    runTransaction(callback) {
      const run = chain.then(() => {
        const transaction = {
          async get(ref) {
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
            store.set(ref.path, applyUpdate(store.get(ref.path), data));
          },
        };
        return callback(transaction);
      });
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

function seed() {
  return {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "users/dave": { username: "Dave" },
    "groups/g1": { founderId: "alice", name: "G", hasRunningGame: false },
    "groups/g1/members/alice": { role: "founder", userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/members/dave": { role: "member", userId: "dave" },
    "groups/g1/roles/founder": { permissions: ["manageGames"] },
    "groups/g1/roles/member": { permissions: [] },
  };
}

function domain(db) {
  return createMafiaDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
  });
}

test("mafia lobby create is server-side and join is idempotent", async () => {
  const db = createFakeDb(seed());
  const mafia = domain(db);
  const created = await mafia.createMafiaGame({
    auth: { uid: "alice" },
    data: { groupId: "g1", minPlayers: 4, maxPlayers: 8 },
  });
  const game = db.store.get(`mafia_games/${created.gameId}`);
  assert.equal(game.status, "waiting");
  assert.equal(game.createdBy, "alice");
  assert.equal(game.playersCount, 1);
  assert.ok(db.store.get(`mafia_games/${created.gameId}/players/alice`));
  const priv = db.store.get(`mafia_games/${created.gameId}/players/alice/private/data`);
  assert.equal(priv.role, undefined);
  assert.equal(priv.assigned, false);
  await mafia.joinMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await mafia.joinMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`mafia_games/${created.gameId}`).playersCount, 2);
});

test("mafia start requires the host, min players, and cannot be forced by a client role", async () => {
  const db = createFakeDb(seed());
  const mafia = domain(db);
  const created = await mafia.createMafiaGame({
    auth: { uid: "alice" },
    data: { groupId: "g1", minPlayers: 4, maxPlayers: 8 },
  });
  await mafia.joinMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await assert.rejects(
    mafia.startMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    mafia.startMafiaGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    mafia.createMafiaGame({
      auth: { uid: "bob" },
      data: { groupId: "g1" },
    }),
    (error) => error.code === "permission-denied",
  );
});
