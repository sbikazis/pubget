"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createAchievementsDomain, CATALOG, BASE_IDS } = require("../src/achievementsDomain");

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

  function makeDoc(path, id) {
    return {
      path,
      id,
      collection(name) {
        return makeCollection(`${path}/${name}`);
      },
      async get() {
        const data = store.get(path);
        return { exists: data !== undefined, data: () => clone(data), id };
      },
      async set(data, opts = {}) {
        if (opts.merge && store.has(path)) {
          store.set(path, { ...store.get(path), ...clone(data) });
        } else {
          store.set(path, clone(data));
        }
      },
    };
  }

  function makeCollection(base) {
    return {
      doc(id) {
        const resolvedId = id || `auto-${store.size + 1}`;
        return makeDoc(`${base}/${resolvedId}`, resolvedId);
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
    };
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
            return { exists: data !== undefined, data: () => clone(data) };
          },
          create(ref, data) {
            if (store.has(ref.path)) throw new Error("already-exists");
            store.set(ref.path, clone(data));
          },
          set(ref, data, opts = {}) {
            if (opts.merge && store.has(ref.path)) {
              store.set(ref.path, { ...store.get(ref.path), ...clone(data) });
            } else {
              store.set(ref.path, clone(data));
            }
          },
        };
        return callback(transaction);
      });
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

function domainOf(db, extras = {}) {
  return createAchievementsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    clock: { now: () => extras.now || new Date("2026-09-09T00:00:00.000Z") },
    economy: extras.economy,
    notificationBuilder: extras.notificationBuilder,
  });
}

test("catalog is exactly the ten Pubget achievements", () => {
  assert.equal(CATALOG.length, 10);
  assert.deepEqual(
    CATALOG.map((item) => item.id),
    [
      "the_threshold",
      "keeper_of_time",
      "shogun_of_the_realm",
      "thread_of_souls",
      "worldsmith",
      "arena_sovereign",
      "master_of_festivities",
      "crownbearer",
      "legend_of_the_gate",
      "dragon_of_legacy",
    ],
  );
  assert.equal(BASE_IDS.length, 8);
});

test("threshold unlocks on first edit and writes progress", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  const results = await domain.evaluate({
    type: "edit_published",
    userId: "u1",
    metadata: { publishedWorks: 1, impactScore: 0 },
  });
  assert.equal(results.some((r) => r.unlocked && r.achievementId === "the_threshold"), true);
  assert.ok(db.store.has("user_achievements/u1/unlocked/the_threshold"));
  assert.ok(db.store.has("user_achievement_progress/u1/progress/the_threshold"));
  const progress = db.store.get("user_achievement_progress/u1/progress/the_threshold");
  assert.equal(progress.conditions.first_action.met, true);
  assert.equal(progress.currentValue, 1);
  assert.equal(progress.targetValue, 1);
});

test("threshold is idempotent", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  await domain.evaluate({ type: "message_sent", userId: "u1" });
  const second = await domain.evaluate({ type: "group_joined", userId: "u1" });
  assert.equal(
    second.some((r) => r.achievementId === "the_threshold" && r.reason === "already_unlocked"),
    true,
  );
});

test("arena auto-increments wins from successive game_won events", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  for (let i = 0; i < 18; i += 1) {
    await domain.evaluate({
      type: "game_won",
      userIds: ["u1"],
      source: "game",
      metadata: { gameId: `auto-${i}` },
    });
  }
  const progress = db.store.get("user_achievement_progress/u1/progress/arena_sovereign");
  assert.equal(progress.conditions.wins_30.current, 18);
  assert.equal(progress.currentValue, 18);
  assert.equal(db.store.has("user_achievements/u1/unlocked/arena_sovereign"), false);

  for (let i = 18; i < 30; i += 1) {
    await domain.evaluate({
      type: "game_won",
      userIds: ["u1"],
      source: "game",
      metadata: { gameId: `auto-${i}` },
    });
  }
  assert.ok(db.store.has("user_achievements/u1/unlocked/arena_sovereign"));
});

test("arena progress bars accept absolute server numbers before unlock", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  await domain.evaluate({
    type: "game_won",
    userId: "u1",
    metadata: { realWins: 18, realGames: 30 },
  });
  const progress = db.store.get("user_achievement_progress/u1/progress/arena_sovereign");
  assert.equal(progress.conditions.wins_30.current, 18);
  assert.equal(progress.conditions.winrate_55.current, 60);
  assert.equal(db.store.has("user_achievements/u1/unlocked/arena_sovereign"), false);
});

test("composites unlock only after prerequisites", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  // Seed five base unlocks.
  for (const id of BASE_IDS.slice(0, 5)) {
    await domain.unlock("u1", id, { source: "test" });
  }
  assert.ok(db.store.has("user_achievements/u1/unlocked/legend_of_the_gate"));

  // Dragon still blocked without keeper+crown+age.
  assert.equal(db.store.has("user_achievements/u1/unlocked/dragon_of_legacy"), false);

  await domain.unlock("u1", "keeper_of_time", { source: "test" });
  await domain.unlock("u1", "crownbearer", { source: "test" });
  await db.collection("user_achievement_stats").doc("u1").set({
    accountCreatedAt: "2023-01-01T00:00:00.000Z",
  }, { merge: true });
  await domain.evaluate({ type: "achievement_reconcile", userId: "u1" });
  assert.ok(db.store.has("user_achievements/u1/unlocked/dragon_of_legacy"));
});

test("getAchievements returns bilingual fields and progress", async () => {
  const db = createFakeDb();
  const domain = domainOf(db);
  await domain.evaluate({
    type: "edit_published",
    userId: "u1",
    metadata: { publishedWorks: 1 },
  });
  const payload = await domain.getAchievements({
    auth: { uid: "u1" },
    data: {},
  });
  assert.equal(payload.items.length, 10);
  const threshold = payload.items.find((item) => item.id === "the_threshold");
  assert.equal(threshold.nameAr, "العتبة");
  assert.equal(threshold.nameEn, "The Threshold");
  assert.equal(threshold.unlocked, true);
  assert.ok(threshold.unlockedAt);
  assert.equal(threshold.conditions[0].met, true);
  assert.equal(threshold.assetPath.includes("the_threshold"), true);
});

test("client-facing catalog shogun lists separate conditions", () => {
  const shogun = CATALOG.find((item) => item.id === "shogun_of_the_realm");
  assert.equal(shogun.conditions.length, 4);
  assert.deepEqual(
    shogun.conditions.map((c) => c.id),
    ["members_50", "member_age_3d", "member_message_1", "stable_7d"],
  );
});
