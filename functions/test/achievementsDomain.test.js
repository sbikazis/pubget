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

test("seasonal achievements obey server time and stay idempotent", async () => {
  let now = new Date("2026-08-15T00:00:00Z");
  const db = createFakeDb();
  const rewards = [];
  const domain = createAchievementsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    clock: { now: () => now },
    economy: {
      applyReward: async (spec) => {
        rewards.push(spec);
        return { applied: true };
      },
    },
  });
  const before = await domain.evaluate({ type: "game_won", userIds: ["alice"] });
  const seasonalBefore = before.find((item) => item.achievementId === "autumn_2026_rally");
  assert.equal(seasonalBefore.unlocked, false);
  assert.equal(seasonalBefore.reason, "season_not_started");
  now = new Date("2026-09-03T12:00:00Z");
  const during = await domain.evaluate({ type: "game_won", userIds: ["alice"] });
  assert.equal(during.find((item) => item.achievementId === "autumn_2026_rally").unlocked, true);
  const duplicate = await domain.unlock("alice", "autumn_2026_rally");
  assert.equal(duplicate.reason, "already_unlocked");
  assert.equal(rewards.filter((item) => item.referenceId === "autumn_2026_rally").length, 1);
  const listed = await domain.getAchievements({ auth: { uid: "alice" } });
  const rally = listed.items.find((item) => item.id === "autumn_2026_rally");
  assert.equal(rally.seasonState, "active");
  assert.equal(rally.unlocked, true);
  now = new Date("2026-12-15T00:00:00Z");
  const after = await domain.unlock("bob", "autumn_2026_rally");
  assert.equal(after.unlocked, false);
  assert.equal(after.reason, "season_ended");
  const historical = await domain.getAchievements({ auth: { uid: "alice" } });
  const ended = historical.items.find((item) => item.id === "autumn_2026_rally");
  assert.equal(ended.seasonState, "ended");
  assert.equal(ended.unlocked, true);
  const invalid = await domain.unlock("alice", "not-real");
  assert.equal(invalid.reason, "invalid");
});
