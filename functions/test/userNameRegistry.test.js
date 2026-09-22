"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  USERNAME_MIN,
  USERNAME_MAX,
  validateUsername,
  normalizeUsername,
  createUserNameRegistry,
  createUserNameCallables,
  createUsernameReconciliationTrigger,
} = require("../src/userNameRegistry");

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

// Minimal in-memory Firestore stand-in that supports the exact access pattern
// used by userNameRegistry.js (doc get + runTransaction with get/set/update/delete).
function MemoryUsernamesDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  return {
    store,
    collection() {
      return {
        doc: (id) => ({
          id,
          async get() {
            return { exists: store.has(id), data: () => store.get(id) };
          },
          async set(value) {
            store.set(id, value);
          },
          async update(value) {
            store.set(id, { ...(store.get(id) || {}), ...value });
          },
        }),
      };
    },
    async runTransaction(run) {
      const tx = {
        async get(ref) {
          return ref.get();
        },
        update(ref, value) {
          store.set(ref.id, { ...(store.get(ref.id) || {}), ...value });
        },
        set(ref, value) {
          store.set(ref.id, value);
        },
        delete(ref) {
          store.delete(ref.id);
        },
      };
      return run(tx);
    },
  };
}

function registryFor(seed = {}) {
  return createUserNameRegistry({ db: MemoryUsernamesDb(seed) });
}

test("validateUsername enforces the §3.2 charset and bounds", () => {
  assert.equal(USERNAME_MIN, 3);
  assert.equal(USERNAME_MAX, 20);
  assert.deepEqual(validateUsername("fan"), { valid: true, reason: null });
  assert.deepEqual(validateUsername("fan_2024"), { valid: true, reason: null });
  assert.deepEqual(validateUsername("a.b-c__9"), { valid: true, reason: null });
  assert.deepEqual(validateUsername("أحمد"), { valid: true, reason: null });
  assert.deepEqual(validateUsername("ahmed".length === 5 ? "ahmeD" : "ahmeD"), { valid: true, reason: null });

  assert.deepEqual(validateUsername(""), { valid: false, reason: "empty" });
  assert.deepEqual(validateUsername("ab"), { valid: false, reason: "too-short" });
  assert.equal(validateUsername("a".repeat(21)).valid, false);
  assert.equal(validateUsername("a".repeat(21)).reason, "too-long");
  assert.equal(validateUsername("a".repeat(20)).valid, true);
  assert.deepEqual(validateUsername("1fan"), { valid: false, reason: "invalid-start" });
  assert.deepEqual(validateUsername("_fan"), { valid: false, reason: "invalid-start" });
  assert.deepEqual(validateUsername("fan name"), { valid: false, reason: "invalid-characters" });
  assert.deepEqual(validateUsername("fan@pubget"), { valid: false, reason: "invalid-characters" });
});

test("normalizeUsername trims and lowercases", () => {
  assert.equal(normalizeUsername("  Pubget_Fan  "), "pubget_fan");
  assert.equal(normalizeUsername("أحمد"), "أحمد");
  assert.equal(normalizeUsername(undefined), "");
  assert.equal(normalizeUsername(null), "");
});

test("registry status reports validation and taken states", async () => {
  const registry = registryFor({ taken: { uid: "bob" } });
  const free = await registry.status("alice");
  assert.equal(free.valid, true);
  assert.equal(free.reason, null);
  assert.equal(free.normalized, "alice");

  const taken = await registry.status("Taken");
  assert.equal(taken.valid, true);
  assert.equal(taken.reason, "taken");

  const bad = await registry.status("9lives");
  assert.equal(bad.valid, false);
  assert.equal(bad.reason, "invalid-start");
});

test("registry reserve is race-safe and idempotent per owner", async () => {
  const db = MemoryUsernamesDb();
  const registry = createUserNameRegistry({ db });

  assert.equal(await registry.reserve("alice", "Fan", HttpsError), "claimed");
  const claimed = db.store.get("fan");
  assert.equal(claimed.uid, "alice");
  assert.equal(claimed.normalized, "fan");

  // Same owner re-claim is a no-op success.
  assert.equal(await registry.reserve("alice", "fan", HttpsError), "already-claimed");

  // A different owner is refused and flagged.
  await assert.rejects(
    () => registry.reserve("bob", "fan", HttpsError),
    (error) => error instanceof HttpsError && error.code === "already-exists",
  );
  assert.equal(db.store.get("fan").conflictingUid, "bob");
  assert.equal(db.store.get("fan").uid, "alice");

  // Invalid names never reach the store.
  await assert.rejects(
    () => registry.reserve("bob", "1bad", HttpsError),
    (error) => error instanceof HttpsError && error.code === "invalid-argument",
  );
  assert.equal(db.store.has("1bad"), false);
});

test("registry release is scoped to the owner and never throws", async () => {
  const db = MemoryUsernamesDb({
    mine: { uid: "alice" },
    theirs: { uid: "bob" },
  });
  const registry = createUserNameRegistry({ db });

  await registry.release("alice", "Mine");
  assert.equal(db.store.has("mine"), false);

  await registry.release("alice", "theirs");
  assert.equal(db.store.has("theirs"), true);

  await registry.release("alice", "missing");
  await registry.release("alice", "");
  assert.equal(db.store.size, 1);
});

test("callables require authentication and honor the registry", async () => {
  const callables = createUserNameCallables({
    db: MemoryUsernamesDb({ taken: { uid: "bob" } }),
    HttpsError,
  });

  await assert.rejects(
    () => callables.checkUsernameAvailable({ data: { username: "fan" } }),
    (error) => error instanceof HttpsError && error.code === "unauthenticated",
  );
  await assert.rejects(
    () => callables.reserveUsername({ data: { username: "fan" } }),
    (error) => error instanceof HttpsError && error.code === "unauthenticated",
  );

  const check = await callables.checkUsernameAvailable({
    auth: { uid: "alice" },
    data: { username: "fan" },
  });
  assert.deepEqual(check, { available: true, normalized: "fan", reason: null });

  const takenCheck = await callables.checkUsernameAvailable({
    auth: { uid: "alice" },
    data: { username: "taken" },
  });
  assert.equal(takenCheck.available, false);
  assert.equal(takenCheck.reason, "taken");

  await assert.rejects(
    () => callables.reserveUsername({
      auth: { uid: "alice" },
      data: { username: "1bad" },
    }),
    (error) => error instanceof HttpsError && error.code === "invalid-argument",
  );

  const reserve = await callables.reserveUsername({
    auth: { uid: "alice" },
    data: { username: "fan" },
  });
  assert.deepEqual(reserve, { normalized: "fan", alreadyClaimed: false });
});

test("reconciliation trigger claims new names and releases renamed ones", async () => {
  const db = MemoryUsernamesDb({ oldname: { uid: "alice" } });
  const trigger = createUsernameReconciliationTrigger({ db });
  const event = (beforeData, afterData) => ({
    params: { uid: "alice" },
    data: {
      before: { exists: !!beforeData, data: () => beforeData },
      after: { exists: true, data: () => afterData },
    },
  });

  await trigger(event({ username: "oldname" }, { username: "newname" }));
  assert.equal(db.store.has("oldname"), false);
  assert.equal(db.store.has("newname"), true);
  assert.equal(db.store.get("newname").uid, "alice");

  // No-op when unchanged.
  await trigger(event({ username: "newname" }, { username: "newname" }));
  assert.equal(db.store.size, 1);
});

test("reconciliation trigger never steals a name owned by another uid", async () => {
  const db = MemoryUsernamesDb({ coveted: { uid: "bob" } });
  const trigger = createUsernameReconciliationTrigger({ db });

  await trigger({
    params: { uid: "alice" },
    data: {
      before: { exists: true, data: () => ({ username: "aliceold" }) },
      after: { exists: true, data: () => ({ username: "coveted" }) },
    },
  });
  assert.equal(db.store.get("coveted").uid, "bob");
});