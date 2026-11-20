"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createAchievementEventProcessor,
} = require("../src/achievementEvents");

const FieldValue = { serverTimestamp: () => ({ _serverTimestamp: true }) };

function createFakeDb(initialClaims = []) {
  const claims = new Set(initialClaims);
  const writes = [];
  const db = {
    claims,
    writes,
    collection(name) {
      assert.equal(name, "achievementEventClaims");
      return {
        doc(id) {
          return {
            id,
            async get() {
              return { exists: claims.has(id) };
            },
            create(data) {
              writes.push({ type: "create", id, data });
              claims.add(id);
            },
            async delete() {
              await Promise.resolve();
              claims.delete(id);
              writes.push({ type: "delete", id });
            },
          };
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          return { exists: claims.has(ref.id) };
        },
        create(ref, data) {
          writes.push({ type: "create", id: ref.id, data });
          claims.add(ref.id);
        },
      };
      return callback(transaction);
    },
  };
  return db;
}

function createEvent(payload, eventId = "event-1") {
  const marks = [];
  return {
    marks,
    event: {
      params: { eventId },
      data: {
        data: () => payload,
        ref: {
          async set(data, options) {
            marks.push({ data, options });
          },
        },
      },
    },
  };
}

test("group_created event evaluates achievements exactly once and is marked processed", async () => {
  const db = createFakeDb();
  const evaluated = [];
  const processor = createAchievementEventProcessor({
    db,
    FieldValue,
    achievements: {
      async evaluate(event) {
        evaluated.push(event);
      },
    },
  });
  const { event, marks } = createEvent({
    type: "group_created",
    userId: "founder-1",
    source: "group",
    metadata: { groupId: "group-1" },
    status: "pending",
  });

  assert.equal(await processor.handleEvent(event), null);
  assert.equal(evaluated.length, 1);
  assert.deepEqual(evaluated[0], {
    type: "group_created",
    userId: "founder-1",
    source: "group",
    metadata: { groupId: "group-1" },
  });
  assert.equal(marks.length, 1);
  assert.ok(marks[0].data.processedAt);
  assert.equal(marks[0].options.merge, true);
  assert.equal(db.claims.has("event-1"), true);
});

test("redelivered event with an existing claim is a no-op", async () => {
  const db = createFakeDb(["event-1"]);
  let calls = 0;
  const processor = createAchievementEventProcessor({
    db,
    FieldValue,
    achievements: {
      async evaluate() {
        calls += 1;
      },
    },
  });
  const { event, marks } = createEvent({
    type: "group_created",
    userId: "founder-1",
  });

  await processor.handleEvent(event);
  assert.equal(calls, 0);
  assert.equal(marks.length, 0);
});

test("unrelated achievement events are ignored without claiming", async () => {
  const db = createFakeDb();
  let calls = 0;
  const processor = createAchievementEventProcessor({
    db,
    FieldValue,
    achievements: {
      async evaluate() {
        calls += 1;
      },
    },
  });
  const { event } = createEvent({ type: "fan_gained", userId: "fan-1" });

  await processor.handleEvent(event);
  assert.equal(calls, 0);
  assert.equal(db.claims.size, 0);
});

test("a failed evaluation releases the claim so the trigger can retry", async () => {
  const db = createFakeDb();
  const processor = createAchievementEventProcessor({
    db,
    FieldValue,
    achievements: {
      async evaluate() {
        throw new Error("stats write failed");
      },
    },
  });
  const { event } = createEvent({
    type: "group_created",
    userId: "founder-1",
  });

  await assert.rejects(processor.handleEvent(event), /stats write failed/);
  assert.equal(db.claims.size, 0);
  assert.equal(db.writes[db.writes.length - 1].type, "delete");
});
