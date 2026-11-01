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
        async set(data) {
          store.set(resolvedPath, clone(data));
        },
        async update(data) {
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath), data));
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

test("mafia domain posts cards via contract and does not import groupChat", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../src/mafia/mafiaDomain.js"), "utf8");
  assert.equal(source.includes('require("../groupChat")'), false);
  assert.equal(source.includes('require("../chatCardWriter")'), true);
});

test("mafia lobby create is server-side and join is idempotent", async () => {
  const db = createFakeDb(seed());
  const mafia = domain(db);
  const created = await mafia.createMafiaGame({
    auth: { uid: "alice" },
    data: { groupId: "g1", minPlayers: 4, maxPlayers: 8 },
  });
  const game = db.store.get(`mafia_games/${created.gameId}`);
  assert.equal(game.status, "WAITING");
  assert.equal(game.createdBy, "alice");
  assert.equal(game.playersCount, 1);
  assert.ok(db.store.get(`mafia_games/${created.gameId}/players/alice`));
  const priv = db.store.get(`mafia_games/${created.gameId}/players/alice/private/data`);
  assert.equal(priv.role, undefined);
  assert.equal(priv.assigned, false);
  await mafia.joinMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await mafia.joinMafiaGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`mafia_games/${created.gameId}`).playersCount, 2);
  const card = db.store.get(`groups/g1/messages/card-game-${created.gameId}-created`);
  assert.equal(card.type, "game");
  assert.equal(card.senderId, "system");
  assert.equal(card.gameActivity.kind, "created");
  assert.equal(card.gameActivity.gameType, "mafia");
// Mafia create/join/start only write uppercase status strings.
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../src/mafia/mafiaDomain.js"), "utf8");
  assert.equal(source.includes('"waiting"'), false);
  assert.equal(source.includes('"starting"'), false);
  assert.equal(source.includes('"WAITING"'), true);
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

test("mafia creation is gated on the SAMURAI rank floor from spec 13.2, not on manageGames", async () => {
  const ranks = {
    ronin: "ronin",
    gokenin: "gokenin",
    samurai: "samurai",
    hatamoto: "hatamoto",
    daimyo: "daimyo",
  };
  const seedRanks = () => {
    const base = seed();
    Object.entries(ranks).forEach(([uid, role]) => {
      base[`groups/g1/members/${uid}`] = { rankV2: role, userId: uid };
    });
    return base;
  };

  for (const [uid, role] of Object.entries(ranks)) {
    const db = createFakeDb(seedRanks());
    const mafia = domain(db);
    if (role === "ronin" || role === "gokenin") {
      await assert.rejects(
        mafia.createMafiaGame({ auth: { uid }, data: { groupId: "g1" } }),
        (error) => error.code === "permission-denied" &&
          /SAMURAI/.test(error.message),
        `${role} must not be able to create a Mafia game`,
      );
      assert.equal(db.store.size > 0 && db.store.get("mafia_games"), undefined);
      continue;
    }
    const created = await mafia.createMafiaGame({ auth: { uid }, data: { groupId: "g1" } });
    assert.equal(db.store.get(`mafia_games/${created.gameId}`).createdBy, uid);
    assert.equal(db.store.get(`mafia_games/${created.gameId}`).minPlayers, 7);
    assert.equal(db.store.get(`mafia_games/${created.gameId}`).maxPlayers, 15);
  }

  // A SAMURAI holds no manageGames permission in the spec's matrix, and must
  // still be able to create the game. The rank floor is the only gate.
  const db = createFakeDb({
    ...seedRanks(),
    "groups/g1/members/samurai": { rankV2: "samurai", userId: "samurai" },
  });
  assert.deepEqual(
    require("../src/pubgetRanks").ROLE_PERMISSIONS.samurai.includes("manageGames"),
    false,
  );
  const created = await domain(db).createMafiaGame({
    auth: { uid: "samurai" },
    data: { groupId: "g1" },
  });
  assert.equal(db.store.get(`mafia_games/${created.gameId}`).createdBy, "samurai");
});

test("a mafia lobby is 7-15 players and cannot start short", async () => {
  const db = createFakeDb(seed());
  const mafia = domain(db);
  // Nonsense bounds are clamped into the specified range rather than trusted.
  const created = await mafia.createMafiaGame({
    auth: { uid: "alice" },
    data: { groupId: "g1", minPlayers: 3, maxPlayers: 40 },
  });
  const game = db.store.get(`mafia_games/${created.gameId}`);
  assert.equal(game.minPlayers, 7);
  assert.equal(game.maxPlayers, 15);

  // Six players is one short of the minimum, so the host cannot start it.
  for (const uid of ["bob", "dave", "u1", "u2", "u3"]) {
    db.store.set(`groups/g1/members/${uid}`, { rankV2: "ronin", userId: uid });
    await mafia.joinMafiaGame({ auth: { uid }, data: { gameId: created.gameId } });
  }
  assert.equal(db.store.get(`mafia_games/${created.gameId}`).playersCount, 6);
  await assert.rejects(
    mafia.startMafiaGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
});
