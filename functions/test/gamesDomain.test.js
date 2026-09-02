"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  GAME_TYPE_REGISTRY,
  TRANSITIONS,
  assertTransition,
  buildGameEvent,
  canTransition,
  createGamesDomain,
  toGameActivity,
  validateActionShape,
} = require("../src/gamesDomain");

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

function seedGroup({ role = "founder" } = {}) {
  return {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "users/charlie": { username: "Charlie" },
    "groups/g1": { founderId: "alice", name: "G" },
    "groups/g1/members/alice": { role, userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/roles/founder": { permissions: ["manageGames", "manageEvents"] },
    "groups/g1/roles/member": { permissions: [] },
  };
}

function handlers(db, notificationBuilder) {
  return createGamesDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    notificationBuilder,
  });
}

function recordingBuilder() {
  const sent = [];
  return {
    sent,
    build: async (payload) => {
      sent.push(payload);
      return { created: payload.recipientIds.length };
    },
  };
}

test("state machine allows documented transitions and rejects the rest", () => {
  assert.equal(canTransition("draft", "waiting"), true);
  assert.equal(canTransition("waiting", "active"), true);
  assert.equal(canTransition("active", "paused"), true);
  assert.equal(canTransition("paused", "active"), true);
  assert.equal(canTransition("active", "completed"), true);
  assert.equal(canTransition("completed", "active"), false);
  assert.equal(TRANSITIONS.cancelled.size, 0);
  assert.throws(
    () => assertTransition("completed", "active", TestHttpsError),
    (error) => error.code === "failed-precondition",
  );
});

test("mafia is registered but not implemented", () => {
  assert.equal(GAME_TYPE_REGISTRY.mafia.implemented, false);
  assert.equal(GAME_TYPE_REGISTRY.guessCharacter.implemented, true);
});

test("action shape validation rejects empty types and oversized payloads", () => {
  assert.throws(
    () => validateActionShape({ actionType: "" }, TestHttpsError),
    (error) => error.code === "invalid-argument",
  );
  const ok = validateActionShape({
    actionType: "guess",
    payload: { value: "Luffy" },
    clientActionId: "c1",
  }, TestHttpsError);
  assert.equal(ok.actionType, "guess");
});

test("events are versioned and map to a chat activity contract", () => {
  const event = buildGameEvent({
    eventId: "e1",
    gameId: "game-1",
    type: "game_started",
    actorId: "alice",
    payload: { from: "waiting", to: "active" },
    createdAt: new Date("2026-09-01T00:00:00Z"),
  });
  assert.equal(event.schemaVersion, 1);
  const activity = toGameActivity(event, {
    id: "game-1",
    type: "guessCharacter",
    groupId: "g1",
  });
  assert.equal(activity.eventType, "game_started");
  assert.equal(activity.groupId, "g1");
  assert.equal(activity.actor, "alice");
});

test("unauthenticated mutations are rejected", async () => {
  const games = handlers(createFakeDb());
  await assert.rejects(
    games.createGame({ data: { type: "guessCharacter", title: "G", groupId: "g1" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("members without manageGames cannot create a game", async () => {
  const games = handlers(createFakeDb(seedGroup()));
  await assert.rejects(
    games.createGame({
      auth: { uid: "bob" },
      data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("mafia cannot be created and unknown types are rejected", async () => {
  const games = handlers(createFakeDb(seedGroup()));
  await assert.rejects(
    games.createGame({
      auth: { uid: "alice" },
      data: { type: "mafia", title: "Night", groupId: "g1" },
    }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    games.createGame({
      auth: { uid: "alice" },
      data: { type: "unknown", title: "X", groupId: "g1" },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("founder can create, members can join once, and start is idempotent", async () => {
  const notifications = recordingBuilder();
  const db = createFakeDb(seedGroup());
  const games = handlers(db, notifications);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  assert.equal(created.status, "waiting");
  assert.equal(db.store.get(`games/${created.gameId}`).participantsCount, 1);
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).participantsCount, 2);
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "active");
  const startedEvents = [...db.store.entries()]
    .filter(([path, data]) => path.includes("/events/") && data.type === "game_started");
  assert.equal(startedEvents.length, 1);
  assert.ok(notifications.sent.some((item) => item.type === "game_invite"));
  assert.ok(notifications.sent.some((item) => item.type === "game_started"));
});

test("join after start and actions from non-participants are rejected", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "animeChain", title: "Chain", groupId: "g1" },
  });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await assert.rejects(
    games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "bob" },
      data: { gameId: created.gameId, actionType: "submit" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("submitAction is idempotent and rejects impersonation", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "emojiAnimeGuess", title: "Emoji", groupId: "g1" },
  });
  await games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await games.submitGameAction({
    auth: { uid: "bob" },
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { value: "Naruto" },
      clientActionId: "act-1",
    },
  });
  await games.submitGameAction({
    auth: { uid: "bob" },
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { value: "Sasuke" },
      clientActionId: "act-1",
    },
  });
  const actions = [...db.store.entries()].filter(([path]) => path.includes("/actions/"));
  assert.equal(actions.length, 1);
  assert.equal(actions[0][1].payload.value, "Naruto");
  await assert.rejects(
    games.submitGameAction({
      auth: { uid: "bob" },
      data: { gameId: created.gameId, actionType: "guess", playerId: "alice" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("non-members cannot join and cannot force completion", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  await assert.rejects(
    games.joinGame({ auth: { uid: "charlie" }, data: { gameId: created.gameId } }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    games.endGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    games.endGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
});

test("pause, resume, end, and cancel follow the state machine", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await games.pauseGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "paused");
  await games.resumeGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "active");
  await games.endGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  await games.endGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "completed");
  await assert.rejects(
    games.cancelGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } }),
    (error) => error.code === "failed-precondition",
  );
});

test("leave is idempotent and concurrent joins do not duplicate participants", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  await Promise.all([
    games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } }),
    games.joinGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } }),
  ]);
  assert.equal(db.store.get(`games/${created.gameId}`).participantsCount, 2);
  await games.leaveGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  await games.leaveGame({ auth: { uid: "bob" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).participantsCount, 1);
  const bob = db.store.get(`games/${created.gameId}/participants/bob`);
  assert.equal(bob.status, "left");
});

test("initialize moves a draft to waiting", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Draft", groupId: "g1", asDraft: true },
  });
  assert.equal(created.status, "draft");
  await games.initializeGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  assert.equal(db.store.get(`games/${created.gameId}`).status, "waiting");
});

test("games never write group chat messages", async () => {
  const db = createFakeDb(seedGroup());
  const games = handlers(db);
  const created = await games.createGame({
    auth: { uid: "alice" },
    data: { type: "guessCharacter", title: "Guess", groupId: "g1" },
  });
  await games.startGame({ auth: { uid: "alice" }, data: { gameId: created.gameId } });
  const chatWrites = [...db.store.keys()].filter((path) => path.includes("/messages/"));
  assert.equal(chatWrites.length, 0);
});
