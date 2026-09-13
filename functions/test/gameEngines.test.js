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

function millisOf(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function matchesFilter(data, filter) {
  const val = data[filter.field];
  if (filter.op === "==") return val === filter.value;
  const left = millisOf(val);
  const right = millisOf(filter.value);
  if (left == null || right == null) return false;
  if (filter.op === "<=") return left <= right;
  if (filter.op === "<") return left < right;
  if (filter.op === ">=") return left >= right;
  if (filter.op === ">") return left > right;
  return false;
}

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
  function query(base, filters, orders = []) {
    const chainQuery = {
      _limit: 100,
      where(field, op, value) {
        return query(base, [...filters, { field, op, value }], orders);
      },
      orderBy(field, direction = "asc") {
        return query(base, filters, [...orders, { field, direction }]);
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
          if (!filters.every((filter) => matchesFilter(data, filter))) continue;
          const id = path.slice(prefix.length);
          docs.push({
            id,
            ref: makeCollection(base).doc(id),
            data: () => clone(data),
            _data: data,
          });
        }
        if (orders.length > 0) {
          docs.sort((a, b) => {
            for (const order of orders) {
              const av = millisOf(a._data[order.field]) ?? 0;
              const bv = millisOf(b._data[order.field]) ?? 0;
              if (av === bv) continue;
              return order.direction === "desc" ? bv - av : av - bv;
            }
            return 0;
          });
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
    data: {
      type: "guessCharacter",
      title: "Guess",
      groupId: "g1",
      creationSource: "group_chat",
    },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: {
      gameId: created.gameId,
      actionType: "select_character",
      payload: { characterId: "luffy" },
      clientActionId: "select-alice",
    },
  });
  await games.submitGameAction({
    auth: { uid: "bob" },
    data: {
      gameId: created.gameId,
      actionType: "select_character",
      payload: { characterId: "naruto" },
      clientActionId: "select-bob",
    },
  });
  return created.gameId;
}

test("guess character uses private selections and yes/no turns", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const gameId = await startGuess(db, games);
  const secret = db.store.get(`games/${gameId}/secret/round`);
  const publicState = db.store.get(`games/${gameId}`).publicState;
  assert.equal(publicState.phase, "question");
  assert.deepEqual(secret.selections, { alice: "luffy", bob: "naruto" });
  assert.equal(publicState.characterOptions.some((item) => item.id === "naruto"), true);
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: {
      gameId,
      actionType: "question",
      payload: { question: "Does the character wear orange?" },
      clientActionId: "a1",
    },
  });
  await games.submitGameAction({
    auth: { uid: "bob" },
    data: {
      gameId,
      actionType: "answer",
      payload: { answer: "yes" },
      clientActionId: "b1",
    },
  });
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: {
      gameId,
      actionType: "guess",
      payload: { characterId: "naruto", score: 100 },
      clientActionId: "a2",
    },
  });
  const after = db.store.get(`games/${gameId}`);
  assert.equal(after.status, "completed");
  assert.deepEqual(after.result.winnerIds, ["alice"]);
  assert.equal(after.result.scores.alice, 1);
});

test("guess character rejects duplicate selections, non-players, and stale versions", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const gameId = await startGuess(db, games);
  await games.submitGameAction({
    auth: { uid: "alice" },
    data: {
      gameId,
      actionType: "question",
      payload: { question: "Is the character a ninja?" },
      clientActionId: "a1",
    },
  });
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "alice" },
      data: {
        gameId,
        actionType: "question",
        payload: { question: "Another question?" },
        clientActionId: "a2",
      },
    }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "dave" },
      data: { gameId, actionType: "question", payload: { question: "?" } },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("guess character timeout resolves a selection forfeiture", async () => {
  let now = new Date("2026-09-02T12:00:00Z");
  const db = createFakeDb(seed());
  const games = domain(db, { clock: { now: () => now } });
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: {
      type: "guessCharacter",
      title: "Guess",
      groupId: "g1",
      creationSource: "group_chat",
    },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  const gameId = created.gameId;
  now = new Date("2026-09-02T12:05:00Z");
  await games.processExpiredGames();
  const after = db.store.get(`games/${gameId}`);
  assert.equal(after.status, "completed");
  assert.deepEqual(after.result.winnerIds, []);
});

test("anime chain validates studio/character relations and turn order", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: {
      type: "animeChain",
      title: "Chain",
      groupId: "g1",
      creationSource: "group_chat",
    },
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
  await games.submitGameAction({
    auth: { uid: next.publicState.currentPlayerId },
    data: {
      gameId: created.gameId,
      actionType: "submit",
      payload: { title: "Not a real anime" },
    },
  });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "completed");
});

test("emoji guess uses server clues and scores a correct title", async () => {
  const db = createFakeDb(seed());
  const games = domain(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: {
      type: "emojiAnimeGuess",
      title: "Emoji",
      groupId: "g1",
      creationSource: "group_chat",
    },
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
  const other = publicState.eligibleGuesserIds[0];
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: current },
      data: {
        gameId: created.gameId,
        actionType: "guess",
        payload: { title: secret.title },
      },
    }),
    (error) => error.code === "failed-precondition",
  );
  await games.submitGameAction({
    auth: { uid: other },
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { title: secret.title },
    },
  });
  const after = db.store.get(`games/${created.gameId}`);
  assert.ok(after.publicState.scores[other] >= 1);
  assert.ok(after.publicState.lastReveal);
  assert.equal(after.publicState.lastReveal.title, secret.title);
});

test("emoji guess timeout advances without scoring the current player", async () => {
  let now = new Date("2026-09-02T12:00:00Z");
  const db = createFakeDb(seed());
  const games = domain(db, { clock: { now: () => now } });
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: {
      type: "emojiAnimeGuess",
      title: "Emoji",
      groupId: "g1",
      creationSource: "group_chat",
    },
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
