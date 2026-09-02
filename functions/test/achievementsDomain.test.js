"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createAchievementsDomain, CATALOG } = require("../src/achievementsDomain");

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
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
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
      for (const [path, data] of store.entries()) {
        if (!path.startsWith(prefix) || path.slice(prefix.length).includes("/")) continue;
        const id = path.slice(prefix.length);
        docs.push({ id, data: () => clone(data) });
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
            return { exists: data !== undefined, data: () => clone(data) };
          },
          create(ref, data) {
            if (store.has(ref.path)) throw new Error("already-exists");
            store.set(ref.path, clone(data));
          },
        };
        return callback(transaction);
      });
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

test("catalog contains the required first-loop achievements", () => {
  const ids = CATALOG.map((item) => item.id);
  for (const id of [
    "first_group", "first_edit", "first_friend", "first_fan",
    "first_event_participation", "first_event_win", "first_game_win",
    "creator_milestone", "community_milestone",
  ]) {
    assert.ok(ids.includes(id), id);
  }
});

test("unlock is idempotent and grants coins once", async () => {
  const db = createFakeDb();
  const rewards = [];
  const notes = [];
  const domain = createAchievementsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    economy: {
      applyReward: async (spec) => {
        rewards.push(spec);
        return { applied: true };
      },
    },
    notificationBuilder: {
      build: async (payload) => {
        notes.push(payload);
        return { created: 1 };
      },
    },
  });
  const first = await domain.unlock("alice", "first_game_win");
  const second = await domain.unlock("alice", "first_game_win");
  assert.equal(first.unlocked, true);
  assert.equal(second.reason, "already_unlocked");
  assert.equal(rewards.length, 1);
  assert.equal(rewards[0].type, "earn_achievement");
  assert.equal(rewards[0].referenceId, "first_game_win");
  assert.equal(notes.length, 1);
  assert.equal(notes[0].id, "achievement-alice-first_game_win");
});

test("evaluate maps domain events and getAchievements is self-only", async () => {
  const db = createFakeDb();
  const domain = createAchievementsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
  });
  await domain.evaluate({ type: "group_created", userId: "alice" });
  await domain.evaluate({ type: "friend_accepted", userIds: ["alice", "bob"] });
  const alice = await domain.getAchievements({ auth: { uid: "alice" } });
  const group = alice.items.find((item) => item.id === "first_group");
  const friend = alice.items.find((item) => item.id === "first_friend");
  assert.equal(group.unlocked, true);
  assert.equal(friend.unlocked, true);
  await assert.rejects(
    domain.getAchievements({}),
    (error) => error.code === "unauthenticated",
  );
});
