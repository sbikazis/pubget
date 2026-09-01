"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  MAX_DURATION_MS,
  TEMPLATES,
  applyTally,
  assertDuration,
  assertTransition,
  calculateResult,
  createEventsDomain,
  emptyTally,
  validateConfiguration,
  validateResponse,
} = require("../src/eventsDomain");

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
  const collection = (base) => ({
    doc(id) {
      const resolvedId = id || `auto-${store.size + 1}`;
      const resolvedPath = `${base}/${resolvedId}`;
      return {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return collection(`${resolvedPath}/${name}`);
        },
        async set(data) {
          store.set(resolvedPath, clone(data));
        },
        async update(data) {
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath) || {}, data));
        },
      };
    },
  });
  function query(base, filters) {
    const chain = {
      _limit: 25,
      where(field, op, value) {
        return query(base, [...filters, { field, op, value }]);
      },
      limit(n) {
        chain._limit = n;
        return chain;
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
            const val = data[filter.field];
            if (filter.op === "==" && val !== filter.value) ok = false;
            if (filter.op === "<=") {
              const left = val instanceof Date ? val.getTime() : new Date(val).getTime();
              const right = filter.value instanceof Date
                ? filter.value.getTime()
                : new Date(filter.value).getTime();
              if (!(left <= right)) ok = false;
            }
          }
          if (ok) {
            const id = path.slice(prefix.length);
            docs.push({
              id,
              ref: collection(base).doc(id),
              data: () => clone(data),
            });
          }
        }
        return { docs: docs.slice(0, chain._limit) };
      },
    };
    return chain;
  }
  return {
    store,
    collection(name) {
      const api = collection(name);
      api.where = (field, op, value) => query(name, [{ field, op, value }]);
      return api;
    },
    async runTransaction(callback) {
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
    },
  };
}

function seedGroup({ role = "founder" } = {}) {
  return {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "groups/g1": { founderId: "alice", name: "G" },
    "groups/g1/members/alice": { role, userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/roles/founder": { permissions: ["manageEvents"] },
    "groups/g1/roles/member": { permissions: [] },
  };
}

function handlers(db) {
  return createEventsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
  });
}

test("poll configuration requires two to ten options", () => {
  assert.equal(validateConfiguration("poll", { question: "Q", options: ["A"] }), null);
  const ok = validateConfiguration("poll", { question: "Best opening?", options: ["A", "B"] });
  assert.equal(ok.options.length, 2);
});

test("quiz responses must answer every question", () => {
  const config = validateConfiguration("quiz", {
    questions: [{
      prompt: "Who wins?",
      options: ["A", "B"],
      correctIndex: 0,
    }],
  });
  assert.equal(validateResponse("quiz", config, { answers: {} }), null);
  const valid = validateResponse("quiz", config, { answers: { "q-1": "opt-1" } });
  assert.equal(valid.answers["q-1"], "opt-1");
});

test("duration rejects inverted and over-long windows", () => {
  const start = new Date("2026-09-01T00:00:00Z");
  assert.throws(
    () => assertDuration(start, new Date("2026-08-31T00:00:00Z"), TestHttpsError),
    (error) => error.code === "invalid-argument",
  );
  assert.throws(
    () => assertDuration(start, new Date(start.getTime() + MAX_DURATION_MS + 1), TestHttpsError),
    (error) => error.code === "invalid-argument",
  );
  const exact = assertDuration(start, new Date(start.getTime() + MAX_DURATION_MS), TestHttpsError);
  assert.equal(exact.end.getTime() - exact.start.getTime(), MAX_DURATION_MS);
});

test("illegal lifecycle transitions are rejected", () => {
  assert.throws(
    () => assertTransition("archived", "active", TestHttpsError),
    (error) => error.code === "failed-precondition",
  );
  assert.doesNotThrow(() => assertTransition("draft", "active", TestHttpsError));
  assert.doesNotThrow(() => assertTransition("active", "ended", TestHttpsError));
});

test("poll results are deterministic from tallies", () => {
  const config = validateConfiguration("poll", { question: "Q", options: ["A", "B"] });
  let tally = emptyTally(config, "poll");
  tally = applyTally(tally, "poll", config, { optionIds: ["opt-1"] });
  tally = applyTally(tally, "poll", config, { optionIds: ["opt-1"] });
  tally = applyTally(tally, "poll", config, { optionIds: ["opt-2"] });
  const result = calculateResult({ type: "poll", configuration: config, tally });
  assert.deepEqual(result.winnerIds, ["opt-1"]);
  assert.equal(result.votes["opt-1"], 2);
});

test("event templates map to real event types", () => {
  assert.equal(TEMPLATES.animeBattle.type, "versus");
  assert.equal(TEMPLATES.theoryNight.type, "theory");
});

test("unauthenticated event mutations are rejected", async () => {
  const chat = handlers(createFakeDb());
  await assert.rejects(
    chat.saveEventDraft({ data: { type: "poll", title: "Q", options: ["A", "B"], groupId: "g1" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("members without manageEvents cannot create an event", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  await assert.rejects(
    events.saveEventDraft({
      auth: { uid: "bob" },
      data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("founder can draft, publish, and members can submit once", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Best opening",
      groupId: "g1",
      question: "Best opening?",
      options: ["One", "Two"],
    },
  });
  const start = new Date(Date.now() - 1000);
  const end = new Date(Date.now() + 60 * 60 * 1000);
  const published = await events.publishEvent({
    auth: { uid: "alice" },
    data: { eventId: draft.eventId, startAt: start.toISOString(), endAt: end.toISOString() },
  });
  assert.equal(published.status, "active");
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { optionId: "opt-1" } },
  });
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId: draft.eventId, responseData: { optionId: "opt-2" } },
    }),
    (error) => error.code === "already-exists",
  );
  const stored = db.store.get(`events/${draft.eventId}`);
  assert.equal(stored.responsesCount, 1);
  assert.equal(stored.tally.votes["opt-1"], 1);
});

test("join is idempotent and block is not required for group members", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "versus",
      title: "Battle",
      groupId: "g1",
      question: "Who wins?",
      candidates: ["Naruto", "Sasuke"],
    },
  });
  await events.publishEvent({
    auth: { uid: "alice" },
    data: {
      eventId: draft.eventId,
      startAt: new Date(Date.now() - 1000).toISOString(),
      endAt: new Date(Date.now() + 3600000).toISOString(),
    },
  });
  await events.joinEvent({ auth: { uid: "bob" }, data: { eventId: draft.eventId } });
  await events.joinEvent({ auth: { uid: "bob" }, data: { eventId: draft.eventId } });
  assert.equal(db.store.get(`events/${draft.eventId}`).participantsCount, 1);
});

test("responses after ending are rejected", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Q",
      groupId: "g1",
      question: "Q?",
      options: ["A", "B"],
    },
  });
  await events.publishEvent({
    auth: { uid: "alice" },
    data: {
      eventId: draft.eventId,
      startAt: new Date(Date.now() - 1000).toISOString(),
      endAt: new Date(Date.now() + 3600000).toISOString(),
    },
  });
  await events.endEvent({ auth: { uid: "alice" }, data: { eventId: draft.eventId } });
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId: draft.eventId, responseData: { optionId: "opt-1" } },
    }),
    (error) => error.code === "failed-precondition",
  );
  const ended = db.store.get(`events/${draft.eventId}`);
  assert.equal(ended.status, "ended");
  assert.ok(ended.result);
  await events.archiveEvent({ auth: { uid: "alice" }, data: { eventId: draft.eventId } });
  assert.equal(db.store.get(`events/${draft.eventId}`).status, "archived");
});

test("non-members cannot submit or join", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Q",
      groupId: "g1",
      question: "Q?",
      options: ["A", "B"],
    },
  });
  await events.publishEvent({
    auth: { uid: "alice" },
    data: {
      eventId: draft.eventId,
      startAt: new Date(Date.now() - 1000).toISOString(),
      endAt: new Date(Date.now() + 3600000).toISOString(),
    },
  });
  await assert.rejects(
    events.joinEvent({ auth: { uid: "mallory" }, data: { eventId: draft.eventId } }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "mallory" },
      data: { eventId: draft.eventId, responseData: { optionId: "opt-1" } },
    }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    events.cancelEvent({ auth: { uid: "bob" }, data: { eventId: draft.eventId } }),
    (error) => error.code === "permission-denied",
  );
});

test("active events past endAt reject responses", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Q",
      groupId: "g1",
      question: "Q?",
      options: ["A", "B"],
    },
  });
  await events.publishEvent({
    auth: { uid: "alice" },
    data: {
      eventId: draft.eventId,
      startAt: new Date(Date.now() - 2000).toISOString(),
      endAt: new Date(Date.now() + 3600000).toISOString(),
    },
  });
  const stored = db.store.get(`events/${draft.eventId}`);
  stored.endAt = new Date(Date.now() - 1000);
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId: draft.eventId, responseData: { optionId: "opt-1" } },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("scheduler activates scheduled events and expires active ones", async () => {
  const db = createFakeDb({
    ...seedGroup(),
    "events/soon": {
      type: "poll",
      creatorId: "alice",
      groupId: "g1",
      title: "Soon",
      status: "scheduled",
      startAt: new Date(Date.now() - 1000),
      endAt: new Date(Date.now() + 3600000),
      configuration: { question: "Q", options: [{ id: "opt-1", label: "A" }, { id: "opt-2", label: "B" }] },
      tally: { votes: { "opt-1": 0, "opt-2": 0 }, submissions: 0 },
      responsesCount: 0,
    },
    "events/old": {
      type: "poll",
      creatorId: "alice",
      groupId: "g1",
      title: "Old",
      status: "active",
      startAt: new Date(Date.now() - 3600000),
      endAt: new Date(Date.now() - 1000),
      configuration: { question: "Q", options: [{ id: "opt-1", label: "A" }, { id: "opt-2", label: "B" }] },
      tally: { votes: { "opt-1": 2, "opt-2": 1 }, submissions: 3 },
      responsesCount: 3,
    },
  });
  const events = handlers(db);
  await events.processEventLifecycle();
  assert.equal(db.store.get("events/soon").status, "active");
  assert.equal(db.store.get("events/old").status, "ended");
  assert.deepEqual(db.store.get("events/old").result.winnerIds, ["opt-1"]);
});

test("publish is idempotent for an already active event", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Q",
      groupId: "g1",
      question: "Q?",
      options: ["A", "B"],
    },
  });
  const payload = {
    eventId: draft.eventId,
    startAt: new Date(Date.now() - 1000).toISOString(),
    endAt: new Date(Date.now() + 3600000).toISOString(),
  };
  const first = await events.publishEvent({ auth: { uid: "alice" }, data: payload });
  const second = await events.publishEvent({ auth: { uid: "alice" }, data: payload });
  assert.equal(first.status, "active");
  assert.equal(second.status, "active");
});
