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
  let txQueue = Promise.resolve();
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
              ref: makeCollection(base).doc(id),
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
      return makeCollection(name);
    },
    async runTransaction(callback) {
      const run = txQueue.then(async () => {
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
            if (store.has(ref.path)) {
              const error = new Error("already-exists");
              error.code = "already-exists";
              throw error;
            }
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
      txQueue = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

function seedGroup({ role = "founder", extra = {} } = {}) {
  return {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "users/charlie": { username: "Charlie" },
    "groups/g1": { founderId: "alice", name: "G" },
    "groups/g1/members/alice": { role, userId: "alice" },
    "groups/g1/members/bob": { role: "member", userId: "bob" },
    "groups/g1/roles/founder": { permissions: ["manageEvents"] },
    "groups/g1/roles/member": { permissions: [] },
    ...extra,
  };
}

function handlers(db, notificationBuilder) {
  return createEventsDomain({
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

test("allowUpdate decrements the previous tally before applying the new one", async () => {
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
      configuration: { allowUpdate: true, question: "Q?", options: ["A", "B"] },
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
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { optionId: "opt-1" } },
  });
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { optionId: "opt-2" } },
  });
  const stored = db.store.get(`events/${draft.eventId}`);
  assert.equal(stored.responsesCount, 1);
  assert.equal(stored.tally.submissions, 1);
  assert.equal(stored.tally.votes["opt-1"], 0);
  assert.equal(stored.tally.votes["opt-2"], 1);
});

test("event start notifies group members, not only the creator", async () => {
  const db = createFakeDb(seedGroup());
  const recorder = recordingBuilder();
  const events = handlers(db, recorder);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Live vote",
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
  const start = recorder.sent.find((item) => item.type === "event_starting");
  assert.ok(start);
  assert.ok(start.recipientIds.includes("alice"));
  assert.ok(start.recipientIds.includes("bob"));
  assert.equal(start.recipientIds.includes("charlie"), false);
  assert.equal(start.pushWorthy, true);
  assert.equal(start.destination, `/event/${draft.eventId}`);
  assert.equal(start.id, `event-start-${draft.eventId}`);
  assert.equal(new Set(start.recipientIds).size, start.recipientIds.length);
});

test("event end notifies participants who joined", async () => {
  const db = createFakeDb({
    ...seedGroup(),
    "events/old": {
      type: "poll",
      creatorId: "alice",
      groupId: "g1",
      title: "Old",
      status: "active",
      startAt: new Date(Date.now() - 3600000),
      endAt: new Date(Date.now() - 1000),
      configuration: {
        question: "Q",
        options: [{ id: "opt-1", label: "A" }, { id: "opt-2", label: "B" }],
      },
      tally: { votes: { "opt-1": 1, "opt-2": 0 }, submissions: 1 },
      responsesCount: 1,
    },
    "events/old/participants/bob": { userId: "bob", leftAt: null },
    "events/old/participants/gone": { userId: "gone", leftAt: new Date() },
  });
  const recorder = recordingBuilder();
  const events = handlers(db, recorder);
  await events.processEventLifecycle();
  const ended = recorder.sent.find((item) => item.type === "event_ended");
  assert.ok(ended);
  assert.ok(ended.recipientIds.includes("bob"));
  assert.ok(ended.recipientIds.includes("alice"));
  assert.equal(ended.recipientIds.includes("gone"), false);
  assert.equal(ended.pushWorthy, false);
  assert.equal(ended.destination, "/event/old");
  assert.equal(ended.id, "event-end-old");
  await events.processEventLifecycle();
  assert.equal(recorder.sent.filter((item) => item.type === "event_ended").length, 1);
});

async function publishPoll(events, { allowUpdate = false, extraOptions } = {}) {
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "poll",
      title: "Q",
      groupId: "g1",
      question: "Q?",
      options: extraOptions || ["A", "B"],
      configuration: {
        allowUpdate,
        question: "Q?",
        options: extraOptions || ["A", "B"],
      },
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
  return draft.eventId;
}

test("first submission increments the tally once", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const eventId = await publishPoll(events);
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId, responseData: { optionId: "opt-1" } },
  });
  const stored = db.store.get(`events/${eventId}`);
  assert.equal(stored.responsesCount, 1);
  assert.equal(stored.tally.submissions, 1);
  assert.equal(stored.tally.votes["opt-1"], 1);
  assert.equal(stored.tally.votes["opt-2"], 0);
});

test("duplicate submission is rejected when updates are disallowed", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const eventId = await publishPoll(events, { allowUpdate: false });
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId, responseData: { optionId: "opt-1" } },
  });
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId, responseData: { optionId: "opt-2" } },
    }),
    (error) => error.code === "already-exists",
  );
  const stored = db.store.get(`events/${eventId}`);
  assert.equal(stored.responsesCount, 1);
  assert.equal(stored.tally.votes["opt-1"], 1);
  assert.equal(stored.tally.votes["opt-2"], 0);
});

test("concurrent in-flight updates keep a single consistent tally", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const eventId = await publishPoll(events, { allowUpdate: true });
  await Promise.all([
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId, responseData: { optionId: "opt-1" } },
    }),
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId, responseData: { optionId: "opt-2" } },
    }),
  ]);
  const stored = db.store.get(`events/${eventId}`);
  assert.equal(stored.responsesCount, 1);
  assert.equal(stored.tally.submissions, 1);
  const votes = stored.tally.votes;
  assert.equal((votes["opt-1"] || 0) + (votes["opt-2"] || 0), 1);
  assert.ok((votes["opt-1"] === 1 && votes["opt-2"] === 0) ||
    (votes["opt-1"] === 0 && votes["opt-2"] === 1));
});

test("concurrent first submissions from two members both count", async () => {
  const db = createFakeDb(seedGroup({
    extra: {
      "users/carol": { username: "Carol" },
      "groups/g1/members/carol": { role: "member", userId: "carol" },
    },
  }));
  const events = handlers(db);
  const eventId = await publishPoll(events);
  await Promise.all([
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId, responseData: { optionId: "opt-1" } },
    }),
    events.submitEventResponse({
      auth: { uid: "carol" },
      data: { eventId, responseData: { optionId: "opt-1" } },
    }),
  ]);
  const stored = db.store.get(`events/${eventId}`);
  assert.equal(stored.responsesCount, 2);
  assert.equal(stored.tally.submissions, 2);
  assert.equal(stored.tally.votes["opt-1"], 2);
});

test("captain default role can create an event", async () => {
  const db = createFakeDb(seedGroup({ role: "captain" }));
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
  });
  assert.ok(draft.eventId);
});

test("custom role with manageEvents can create an event", async () => {
  const db = createFakeDb(seedGroup({
    extra: {
      "groups/g1/members/bob": { role: "member", userId: "bob", customRoleId: "moderator" },
      "groups/g1/roles/moderator": { permissions: ["manageEvents"] },
    },
  }));
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "bob" },
    data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
  });
  assert.ok(draft.eventId);
});

test("custom role without manageEvents cannot create an event", async () => {
  const db = createFakeDb(seedGroup({
    extra: {
      "groups/g1/roles/captain": { permissions: ["invite"] },
    },
    role: "captain",
  }));
  const events = handlers(db);
  await assert.rejects(
    events.saveEventDraft({
      auth: { uid: "alice" },
      data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("non-members cannot create an event", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  await assert.rejects(
    events.saveEventDraft({
      auth: { uid: "charlie" },
      data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("founder can create even when the role document has no permissions", async () => {
  const db = createFakeDb(seedGroup({
    extra: { "groups/g1/roles/founder": { permissions: [] } },
  }));
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: { type: "poll", title: "Vote", groupId: "g1", options: ["A", "B"], question: "Q" },
  });
  assert.ok(draft.eventId);
});

test("quiz configuration accepts multiple ordered questions", () => {
  const config = validateConfiguration("quiz", {
    questions: [
      { id: "q-a", prompt: "First?", options: ["A", "B"], correctIndex: 0 },
      { id: "q-b", prompt: "Second?", options: ["C", "D", "E"], correctOptionId: "opt-2" },
    ],
  });
  assert.equal(config.questions.length, 2);
  assert.equal(config.questions[0].id, "q-a");
  assert.equal(config.questions[1].correctOptionId, "opt-2");
  assert.equal(config.allowUpdate, false);
});

test("character comparison requires catalog IDs and rejects duplicates", () => {
  const valid = validateConfiguration("characterComparison", {
    criterion: "Who would win?",
    candidates: [{ characterId: "luffy" }, { characterId: "naruto" }],
  });
  assert.ok(valid);
  assert.equal(valid.comparisonType, "character");
  assert.equal(valid.options[0].characterId, "luffy");
  assert.equal(valid.options[0].label, "Monkey D. Luffy");
  assert.equal(
    validateConfiguration("characterComparison", {
      criterion: "Who would win?",
      candidates: [{ characterId: "not-a-character" }, { characterId: "luffy" }],
    }),
    null,
  );
  assert.equal(
    validateConfiguration("characterComparison", {
      criterion: "Who would win?",
      candidates: [{ characterId: "luffy" }, { characterId: "luffy" }],
    }),
    null,
  );
});

test("anime comparison requires catalog titles and image comparison needs metadata", () => {
  const anime = validateConfiguration("animeComparison", {
    criterion: "Best worldbuilding?",
    candidates: [{ animeId: "one_piece" }, { animeId: "naruto" }],
  });
  assert.ok(anime);
  assert.equal(anime.options[0].label, "One Piece");
  assert.equal(
    validateConfiguration("animeComparison", {
      criterion: "Best?",
      candidates: [{ animeId: "missing" }, { animeId: "naruto" }],
    }),
    null,
  );
  const image = validateConfiguration("imageComparison", {
    criterion: "Better composition?",
    candidates: [
      {
        imageUrl: "https://cdn.pubget.test/a.jpg",
        mimeType: "image/jpeg",
        license: "cc0",
        attribution: "Pubget fixture A",
      },
      {
        imageUrl: "https://cdn.pubget.test/b.png",
        mimeType: "image/png",
        license: "cc-by",
        attribution: "Pubget fixture B",
      },
    ],
  });
  assert.ok(image);
  assert.equal(image.comparisonType, "image");
  assert.equal(
    validateConfiguration("imageComparison", {
      criterion: "Better?",
      candidates: [
        { imageUrl: "http://insecure.test/a.jpg", mimeType: "image/jpeg", license: "cc0", attribution: "A" },
        { imageUrl: "https://cdn.pubget.test/b.png", mimeType: "image/png", license: "cc-by", attribution: "B" },
      ],
    }),
    null,
  );
});

test("comparison result calculation is type-aware and archival", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "characterComparison",
      title: "Best captain",
      groupId: "g1",
      criterion: "Who is the better captain?",
      candidates: [{ characterId: "luffy" }, { characterId: "levi" }],
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
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { optionId: "luffy" } },
  });
  await events.endEvent({ auth: { uid: "alice" }, data: { eventId: draft.eventId } });
  const ended = db.store.get(`events/${draft.eventId}`);
  assert.equal(ended.result.kind, "characterComparison");
  assert.equal(ended.result.criterion, "Who is the better captain?");
  assert.deepEqual(ended.result.winnerIds, ["luffy"]);
  assert.equal(ended.result.winners[0].characterId, "luffy");
  await events.archiveEvent({ auth: { uid: "alice" }, data: { eventId: draft.eventId } });
  assert.equal(db.store.get(`events/${draft.eventId}`).status, "archived");
  assert.ok(db.store.get(`events/${draft.eventId}`).result);
});

test("challenge completion ignores completed=true and verifies server evidence", async () => {
  const db = createFakeDb(seedGroup({
    extra: {
      "user_achievements/bob/items/community_milestone": {
        achievementId: "community_milestone",
      },
    },
  }));
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "challenge",
      title: "Finish a match",
      groupId: "g1",
      prompt: "Finish any Pubget game.",
      challengeKind: "finish_game",
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
    events.submitEventResponse({
      auth: { uid: "alice" },
      data: { eventId: draft.eventId, responseData: { completed: true } },
    }),
    (error) => error.code === "failed-precondition",
  );
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { completed: true } },
  });
  const stored = db.store.get(`events/${draft.eventId}/responses/bob`);
  assert.equal(stored.responseData.verified, true);
  assert.equal(stored.responseData.completed, undefined);
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId: draft.eventId, responseData: { completed: true } },
    }),
    (error) => error.code === "already-exists",
  );
});

test("wrong user, expired challenge, and self-report stay honest", async () => {
  const db = createFakeDb(seedGroup());
  const events = handlers(db);
  const draft = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "challenge",
      title: "Emoji night",
      groupId: "g1",
      prompt: "Post an emoji in real life.",
      challengeKind: "self_report",
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
  await events.submitEventResponse({
    auth: { uid: "bob" },
    data: { eventId: draft.eventId, responseData: { text: "done", completed: true } },
  });
  const stored = db.store.get(`events/${draft.eventId}/responses/bob`);
  assert.equal(stored.responseData.verified, false);
  assert.equal(stored.responseData.verification, "self_reported");
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "charlie" },
      data: { eventId: draft.eventId, responseData: { text: "hi" } },
    }),
    (error) => error.code === "permission-denied",
  );
  const other = await events.saveEventDraft({
    auth: { uid: "alice" },
    data: {
      type: "challenge",
      title: "Late",
      groupId: "g1",
      prompt: "Finish a game",
      challengeKind: "finish_game",
    },
  });
  await events.publishEvent({
    auth: { uid: "alice" },
    data: {
      eventId: other.eventId,
      startAt: new Date(Date.now() - 2000).toISOString(),
      endAt: new Date(Date.now() + 3600000).toISOString(),
    },
  });
  await events.endEvent({ auth: { uid: "alice" }, data: { eventId: other.eventId } });
  await assert.rejects(
    events.submitEventResponse({
      auth: { uid: "bob" },
      data: { eventId: other.eventId, responseData: {} },
    }),
    (error) => error.code === "failed-precondition",
  );
});
