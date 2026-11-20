"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createGroupCreationOutboxHandler } = require("../src/groupCreationOutbox");

const DELETE = Symbol("delete");
const FieldValue = {
  serverTimestamp: () => "SERVER_TIMESTAMP",
  delete: () => DELETE,
};

function createDb(seed) {
  const store = new Map(Object.entries(seed || {}));
  let chain = Promise.resolve();
  const db = {
    store,
    runTransaction(callback) {
      const run = chain.then(() => callback({
        async get(ref) {
          const data = store.get(ref.path);
          return { exists: data !== undefined, data: () => data };
        },
        update(ref, patch) {
          const current = store.get(ref.path);
          if (!current) throw new Error("not-found");
          const next = { ...current };
          for (const [key, value] of Object.entries(patch)) {
            if (value === DELETE) delete next[key];
            else next[key] = value;
          }
          store.set(ref.path, next);
        },
      }));
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
  return db;
}

function eventFor(db, path = "group_creation_outbox/g1") {
  const data = db.store.get(path);
  return {
    params: { eventId: "g1" },
    data: {
      ref: { path },
      exists: true,
      data: () => data,
    },
  };
}

function seedEvent(overrides = {}) {
  return {
    eventId: "g1",
    type: "group_created",
    userId: "alice",
    groupId: "g1",
    status: "pending",
    attempts: 0,
    ...overrides,
  };
}

test("group creation event evaluates achievements and completes its durable record", async () => {
  const db = createDb({ "group_creation_outbox/g1": seedEvent() });
  const evaluated = [];
  let now = 1000;
  const handler = createGroupCreationOutboxHandler({
    db,
    achievements: { evaluate: async (value) => evaluated.push(value) },
    FieldValue,
    clock: { now: () => now },
    randomUUID: () => "worker-1",
  });

  const result = await handler(eventFor(db));
  assert.deepEqual(result, { processed: true });
  assert.equal(evaluated.length, 1);
  assert.deepEqual(evaluated[0], {
    type: "group_created",
    userId: "alice",
    source: "group",
    metadata: { groupId: "g1" },
  });
  const stored = db.store.get("group_creation_outbox/g1");
  assert.equal(stored.status, "completed");
  assert.equal(stored.attempts, 1);
  assert.equal(stored.completedAt, "SERVER_TIMESTAMP");
  assert.equal("leaseOwner" in stored, false);
  assert.equal("leaseUntil" in stored, false);
});

test("duplicate trigger delivery does not evaluate or enqueue effects twice", async () => {
  const db = createDb({ "group_creation_outbox/g1": seedEvent({ status: "completed" }) });
  let calls = 0;
  const handler = createGroupCreationOutboxHandler({
    db,
    achievements: { evaluate: async () => { calls += 1; } },
    FieldValue,
    clock: { now: () => 1000 },
    randomUUID: () => "worker-1",
  });

  const result = await handler(eventFor(db));
  assert.equal(result.processed, false);
  assert.equal(calls, 0);
});

test("failed achievement evaluation releases the lease and persists a bounded retry", async () => {
  const db = createDb({ "group_creation_outbox/g1": seedEvent() });
  let now = 1000;
  let calls = 0;
  const handler = createGroupCreationOutboxHandler({
    db,
    achievements: {
      evaluate: async () => {
        calls += 1;
        if (calls === 1) throw new Error("temporary evaluator outage");
      },
    },
    FieldValue,
    clock: { now: () => now },
    randomUUID: () => "worker-1",
    retryDelayMs: 5000,
  });

  await assert.rejects(handler(eventFor(db)), /temporary evaluator outage/);
  const retry = db.store.get("group_creation_outbox/g1");
  assert.equal(retry.status, "retry");
  assert.equal(retry.attempts, 1);
  assert.equal(retry.nextAttemptAt.getTime(), 6000);
  assert.equal(retry.lastError, "temporary evaluator outage");
  assert.equal("leaseOwner" in retry, false);

  now = 6000;
  const result = await handler(eventFor(db));
  assert.equal(result.processed, true);
  assert.equal(calls, 2);
  assert.equal(db.store.get("group_creation_outbox/g1").status, "completed");
});

test("active leases and not-yet-due retries are not processed concurrently", async () => {
  const db = createDb({
    "group_creation_outbox/g1": seedEvent({
      status: "processing",
      leaseOwner: "other-worker",
      leaseUntil: new Date(5000),
    }),
  });
  let calls = 0;
  const handler = createGroupCreationOutboxHandler({
    db,
    achievements: { evaluate: async () => { calls += 1; } },
    FieldValue,
    clock: { now: () => 1000 },
    randomUUID: () => "worker-2",
  });

  await assert.rejects(handler(eventFor(db)), /already leased/);
  assert.equal(calls, 0);
});

test("invalid outbox events are rejected before achievement evaluation", async () => {
  const db = createDb({
    "group_creation_outbox/g1": seedEvent({ userId: "" }),
  });
  let calls = 0;
  const handler = createGroupCreationOutboxHandler({
    db,
    achievements: { evaluate: async () => { calls += 1; } },
    FieldValue,
    clock: { now: () => 1000 },
    randomUUID: () => "worker-1",
  });

  await assert.rejects(handler(eventFor(db)), /Invalid group creation outbox event/);
  assert.equal(calls, 0);
});
