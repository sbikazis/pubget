"use strict";

/**
 * Live Firestore emulator verification for achievements.
 * Requires: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 and a running emulator.
 *
 * Covers:
 * 1) Client write to unlocked/progress is denied with a real permission error
 * 2) Threshold unlock path via evaluate(group_joined) writes unlockedAt
 * 3) Arena progress updates across game_won events
 * 4) Composite legend_of_the_gate unlocks within the same evaluate/unlock chain
 *    after the 5th base achievement (no app reopen)
 */

const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const admin = require("firebase-admin");
const { createAchievementsDomain } = require("../src/achievementsDomain");

const PROJECT_ID = "demo-pubget-achievements-live";
const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

let env;
let adminApp;
let adminDb;
let domain;

test.before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  }
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: "127.0.0.1", port: 8080, rules },
  });
  adminApp = admin.initializeApp({ projectId: PROJECT_ID }, "achievements-live");
  adminDb = adminApp.firestore();
  domain = createAchievementsDomain({
    db: adminDb,
    FieldValue: admin.firestore.FieldValue,
    HttpsError: TestHttpsError,
  });
});

test.after(async () => {
  if (env) await env.cleanup();
  if (adminApp) await adminApp.delete();
});

test.beforeEach(async () => {
  await env.clearFirestore();
});

test("LIVE emulator: client cannot write user_achievements unlocked path (permission-denied)", async () => {
  const client = env.authenticatedContext("alice").firestore();
  const ref = client.doc("user_achievements/alice/unlocked/the_threshold");
  let caught;
  try {
    await ref.set({
      achievementId: "the_threshold",
      unlockedAt: new Date().toISOString(),
      source: "forged-client",
    });
  } catch (error) {
    caught = error;
  }
  assert.ok(caught, "expected client write to throw");
  const code = caught.code || caught.codePrefix || "";
  const message = String(caught.message || caught);
  assert.match(
    `${code} ${message}`,
    /permission-denied|PERMISSION_DENIED|Missing or insufficient permissions/i,
    `expected real permission error, got: ${code} ${message}`,
  );
  // Double-check via assertFails helper used by the suite.
  await assertFails(client.doc("user_achievements/alice/unlocked/arena_sovereign").set({
    achievementId: "arena_sovereign",
  }));
  await assertFails(client.doc("user_achievement_progress/alice/progress/the_threshold").set({
    currentValue: 1,
    targetValue: 1,
  }));
  await assertFails(client.doc("user_achievement_stats/alice").set({
    firstActionCount: 1,
  }));
});

test("LIVE emulator: Threshold unlocks on group_joined with unlockedAt in Firestore", async () => {
  await adminDb.doc("public_profiles/threshold_user").set({
    uid: "threshold_user",
    username: "Threshold",
    createdAt: admin.firestore.Timestamp.fromDate(new Date("2025-01-01T00:00:00Z")),
  });

  const started = Date.now();
  const results = await domain.evaluate({
    type: "group_joined",
    userId: "threshold_user",
    source: "group",
    metadata: { groupId: "g-live-1" },
  });
  const elapsedMs = Date.now() - started;

  assert.equal(
    results.some((r) => r.unlocked && r.achievementId === "the_threshold"),
    true,
    `threshold not unlocked; results=${JSON.stringify(results)}`,
  );

  const unlocked = await adminDb
    .doc("user_achievements/threshold_user/unlocked/the_threshold")
    .get();
  assert.equal(unlocked.exists, true);
  const data = unlocked.data() || {};
  assert.ok(data.unlockedAt, "unlockedAt missing on unlocked doc");
  assert.equal(data.achievementId || "the_threshold", "the_threshold");

  const progress = await adminDb
    .doc("user_achievement_progress/threshold_user/progress/the_threshold")
    .get();
  assert.equal(progress.exists, true);
  assert.equal((progress.data() || {}).currentValue, 1);

  // Client may still read the unlock (profile strip).
  await assertSucceeds(
    env.authenticatedContext("visitor").firestore()
      .doc("user_achievements/threshold_user/unlocked/the_threshold")
      .get(),
  );

  assert.ok(elapsedMs < 5000, `threshold path took too long: ${elapsedMs}ms`);
});

test("LIVE emulator: Arena Sovereign progressSnapshot updates across wins then unlocks at 30", async () => {
  const uid = "arena_user";
  await adminDb.doc("public_profiles/" + uid).set({
    uid,
    username: "Arena",
    createdAt: admin.firestore.Timestamp.now(),
  });

  for (let i = 0; i < 18; i += 1) {
    await domain.evaluate({
      type: "game_won",
      userIds: [uid],
      source: "game",
      metadata: { gameId: `g-${i}` },
    });
  }

  let progress = await adminDb.doc(`user_achievement_progress/${uid}/progress/arena_sovereign`).get();
  assert.equal(progress.exists, true);
  assert.equal((progress.data() || {}).currentValue, 18);
  assert.equal((progress.data() || {}).targetValue, 30);
  assert.equal(
    await adminDb.doc(`user_achievements/${uid}/unlocked/arena_sovereign`).get().then((d) => d.exists),
    false,
  );

  // Client can observe live progress without refresh (streamable doc).
  const clientSnap = await assertSucceeds(
    env.authenticatedContext(uid).firestore()
      .doc(`user_achievement_progress/${uid}/progress/arena_sovereign`)
      .get(),
  );
  assert.equal(clientSnap.data().currentValue, 18);

  for (let i = 18; i < 30; i += 1) {
    await domain.evaluate({
      type: "game_won",
      userIds: [uid],
      source: "game",
      metadata: { gameId: `g-${i}` },
    });
  }

  progress = await adminDb.doc(`user_achievement_progress/${uid}/progress/arena_sovereign`).get();
  assert.equal((progress.data() || {}).currentValue, 30);
  const unlocked = await adminDb.doc(`user_achievements/${uid}/unlocked/arena_sovereign`).get();
  assert.equal(unlocked.exists, true);
  assert.ok((unlocked.data() || {}).unlockedAt);
});

test("LIVE emulator: 5th base unlock triggers legend_of_the_gate in same chain (no reopen)", async () => {
  const uid = "composite_user";
  const now = admin.firestore.Timestamp.now();
  await adminDb.doc("public_profiles/" + uid).set({
    uid,
    username: "Composite",
    createdAt: admin.firestore.Timestamp.fromDate(new Date("2020-01-01T00:00:00Z")),
  });
  await adminDb.doc(`user_achievement_stats/${uid}`).set({
    accountCreatedAt: admin.firestore.Timestamp.fromDate(new Date("2020-01-01T00:00:00Z")),
    accountAgeDays: 800,
  });

  // Seed four base unlocks as if earned earlier.
  const seeded = [
    "the_threshold",
    "keeper_of_time",
    "shogun_of_the_realm",
    "thread_of_souls",
  ];
  for (const id of seeded) {
    await adminDb.doc(`user_achievements/${uid}/unlocked/${id}`).set({
      achievementId: id,
      unlockedAt: now,
      source: "seed",
    });
    await adminDb.doc(`user_achievements/${uid}/items/${id}`).set({
      achievementId: id,
      unlockedAt: now,
      source: "seed",
    });
  }

  assert.equal(
    await adminDb.doc(`user_achievements/${uid}/unlocked/legend_of_the_gate`).get().then((d) => d.exists),
    false,
  );

  const started = Date.now();
  // Fifth base unlock via domain.unlock → evaluateComposites in same call stack.
  const result = await domain.unlock(uid, "worldsmith", {
    source: "seed_fifth",
    progressSnapshot: { published_works: 1 },
  });
  const elapsedMs = Date.now() - started;

  assert.equal(result.unlocked, true);
  assert.equal(result.achievementId, "worldsmith");

  const legend = await adminDb.doc(`user_achievements/${uid}/unlocked/legend_of_the_gate`).get();
  assert.equal(legend.exists, true, "legend_of_the_gate should unlock automatically after 5th base");
  assert.ok((legend.data() || {}).unlockedAt);
  assert.equal((legend.data() || {}).source, "composite");
  assert.ok(elapsedMs < 5000, `composite chain took too long: ${elapsedMs}ms`);

  // Dragon requires legend + keeper + crown + age>=730. Add crown and re-run composites.
  await domain.unlock(uid, "crownbearer", { source: "seed_crown" });
  const dragon = await adminDb.doc(`user_achievements/${uid}/unlocked/dragon_of_legacy`).get();
  assert.equal(dragon.exists, true, "dragon_of_legacy should unlock when all composite prereqs met");
  assert.ok((dragon.data() || {}).unlockedAt);
});
