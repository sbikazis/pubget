"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createGamesDomain } = require("../src/gamesDomain");
const catalog = require("../src/gameCatalog");

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
            path: resolvedPath,
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
      _limit: 100,
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
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes("/")) continue;
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

function seed() {
  return {
    "users/alice": { username: "Alice", coinsBalance: 0 },
    "users/bob": { username: "Bob", coinsBalance: 0 },
    "users/dave": { username: "Dave", coinsBalance: 0 },
    "groups/g1": { founderId: "alice", name: "G" },
    "groups/g1/members/alice": { role: "founder", userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/members/dave": { role: "member", userId: "dave" },
    "groups/g1/roles/founder": { permissions: ["manageGames"] },
    "groups/g1/roles/member": { permissions: [] },
  };
}

function domain(db, extras = {}) {
  return createGamesDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    clock: extras.clock,
    random: extras.random || (() => 0.2),
    economy: extras.economy,
    achievements: extras.achievements,
  });
}

async function startGuess(db, games) {
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  return created.gameId;
}

test("guess character scores server-side and ignores client score", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const gameId = await startGuess(db, games);
  const secret = db.store.get(`games/${gameId}/secret/round`);
  const publicState = db.store.get(`games/${gameId}`).publicState;
  const correct = secret.correctId;
  const wrong = publicState.prompt.choices.find((item) => item.id !== correct).id;
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: {
      gameId,
      actionType: "guess",
      payload: { choiceId: correct, score: 100 },
      clientActionId: "a1",
    },
  });
  await games.submitGameAction({
    auth: { uid: "bob" },
    data: {
      gameId,
      actionType: "guess",
      payload: { choiceId: wrong },
      clientActionId: "b1",
    },
  });
  const after = db.store.get(`games/${gameId}`);
  assert.equal(after.publicState.scores.alice, 1);
  assert.equal(after.publicState.scores.bob, 0);
  assert.notEqual(after.publicState.roundNumber, 1);
});

test("guess character rejects duplicate answers, non-players, and stale versions", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const gameId = await startGuess(db, games);
  const choice = db.store.get(`games/${gameId}`).publicState.prompt.choices[0].id;
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: { gameId, actionType: "guess", payload: { choiceId: choice }, clientActionId: "a1" },
  });
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "alice" },
      data: { gameId, actionType: "guess", payload: { choiceId: choice }, clientActionId: "a2" },
    }),
    (error) => error.code === "already-exists",
  );
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "dave" },
      data: { gameId, actionType: "guess", payload: { choiceId: choice } },
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "bob" },
      data: {
        gameId,
        actionType: "guess",
        payload: { choiceId: choice, stateVersion: -1 },
      },
    }),
    (error) => error.code === "aborted",
  );
});

test("guess character timeout advances the round without client clocks", async () => {
  let now = new Date("2026-09-02T12:00:00Z");
  const db = createFakeDb(seed());
  const games = domain(db, { clock: { now: () => now } });
  const gameId = await startGuess(db, games);
  now = new Date("2026-09-02T12:05:00Z");
  await games.processExpiredGames();
  const after = db.store.get(`games/${gameId}`);
  assert.ok(after.publicState.roundNumber >= 2 || after.status === "completed");
  assert.equal(after.publicState.scores.alice, 0);
});

test("anime chain validates studio/character relations and turn order", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "animeChain", title: "Chain", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  const game = db.store.get(`games/${created.gameId}`);
  const lastId = game.publicState.chain[0].animeId;
  const current = game.publicState.currentPlayerId;
  const other = current === "alice" ? "bob" : "alice";
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: other },
      data: { gameId: created.gameId, actionType: "submit", payload: { title: "Naruto" } },
    }),
    (error) => error.code === "failed-precondition",
  );
  const valid = catalog.ANIME.find((item) => catalog.sharesRelation(lastId, item.id));
  await games.submitGameAction({
    auth: { uid: current },
    data: {
      gameId: created.gameId,
      actionType: "submit",
      payload: { title: valid.title },
      clientActionId: "c1",
    },
  });
  const next = db.store.get(`games/${created.gameId}`);
  assert.equal(next.publicState.chain.length, 2);
  assert.equal(next.publicState.scores[current], 1);
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: next.publicState.currentPlayerId },
      data: { gameId: created.gameId, actionType: "submit", payload: { title: valid.title } },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("emoji guess uses server clues and scores a correct title", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "emojiAnimeGuess", title: "Emoji", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  const publicState = db.store.get(`games/${created.gameId}`).publicState;
  const secret = db.store.get(`games/${created.gameId}/secret/round`);
  assert.equal(publicState.phase, "guess");
  assert.ok(Array.isArray(publicState.emojis) && publicState.emojis.length >= 3);
  assert.equal(JSON.stringify(publicState).includes(secret.title), false);
  assert.ok(!publicState.title);
  const current = publicState.currentPlayerId;
  const other = current === "alice" ? "bob" : "alice";
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: other },
      data: {
        gameId: created.gameId,
        actionType: "guess",
        payload: { title: secret.title },
      },
    }),
    (error) => error.code === "failed-precondition",
  );
  await games.submitGameAction({
    auth: { uid: current },
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { title: secret.title },
    },
  });
  const after = db.store.get(`games/${created.gameId}`);
  assert.ok(after.publicState.scores[current] >= 1);
  assert.ok(after.publicState.lastReveal);
  assert.equal(after.publicState.lastReveal.title, secret.title);
});

test("emoji guess timeout advances without scoring the current player", async () => {
  let now = new Date("2026-09-02T12:00:00Z");
  const db = createFakeDb(seed());
  const games = domain(db, { clock: { now: () => now } });
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "emojiAnimeGuess", title: "Emoji", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  const before = db.store.get(`games/${created.gameId}`).publicState.currentPlayerId;
  now = new Date("2026-09-02T12:05:00Z");
  await games.processExpiredGames();
  const after = db.store.get(`games/${created.gameId}`);
  assert.notEqual(after.publicState.currentPlayerId, before);
  assert.equal(after.publicState.scores[before], 0);
});
