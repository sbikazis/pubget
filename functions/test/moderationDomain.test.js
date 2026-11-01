"use strict";

// Phase 10 — moderation domain tests.
//
// These cover the properties that make the surface safe rather than the ones
// that make it pretty: staff gating from custom claims, takedown/restore
// symmetry, resolve idempotency, and the audit trail.

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createModerationDomain,
  REMOVABLE_KINDS,
  REVIEW_KINDS,
} = require("../src/moderationDomain");
const { moderationCaseId, enqueueModerationCase } = require("../src/moderationQueue");

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

function applyPatch(current, patch) {
  const next = clone(current || {});
  for (const [key, value] of Object.entries(patch)) {
    if (value && value._increment != null) {
      next[key] = (Number(next[key]) || 0) + value._increment;
      continue;
    }
    next[key] = clone(value);
  }
  return next;
}

function segments(path) {
  return path.split("/");
}

function docRef(path) {
  const parts = segments(path);
  const id = parts[parts.length - 1];
  const coll = parts[parts.length - 2];
  const grandParent = parts.length >= 4 ? parts[parts.length - 3] : null;
  return {
    path,
    id,
    parent: { id: coll, parent: { id: grandParent } },
  };
}

function makeDoc(path, getData) {
  return {
    id: docRef(path).id,
    ref: docRef(path),
    data: () => (getData() === undefined ? undefined : clone(getData())),
  };
}

function matchesFilters(data, filters) {
  return filters.every(({ field, op, value }) => {
    const actual = data ? data[field] : undefined;
    if (op === "==") return actual === value;
    if (op === "in") return Array.isArray(value) && value.includes(actual);
    return true;
  });
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  let autoInc = 0;

  function selectDocs({ collection = null, group = null, filters = [], limit = null }) {
    const out = [];
    for (const [path, data] of store) {
      const parts = segments(path);
      let collName;
      let rest;
      if (group) {
        const index = parts.indexOf(group);
        if (index === -1) continue;
        collName = group;
        rest = parts.slice(index + 1);
      } else {
        if (parts[parts.length - 2] !== collection) continue;
        collName = collection;
        rest = [parts[parts.length - 1]];
      }
      if (rest.length !== 1) continue;
      if (!matchesFilters(data, filters)) continue;
      out.push(makeDoc(path, () => store.get(path)));
    }
    if (limit != null) return out.slice(0, limit);
    return out;
  }

  function query(options) {
    return {
      where(field, op, value) {
        return query({ ...options, filters: [...options.filters, { field, op, value }] });
      },
      orderBy() {
        return query({ ...options, ordered: true });
      },
      limit(value) {
        return query({ ...options, limit: value });
      },
      async get() {
        return { docs: selectDocs(options), empty: selectDocs(options).length === 0 };
      },
      async count() {
        return { data: () => ({ count: selectDocs(options).length }) };
      },
    };
  }

  function collection(name) {
    const base = name;
    return {
      doc(id) {
        const resolvedId = id || `auto-${++autoInc}`;
        const path = `${base}/${resolvedId}`;
        const ref = {
          ...docRef(path),
          collection(child) {
            return collection(`${path}/${child}`);
          },
          async get() {
            const data = store.get(path);
            return { exists: data !== undefined, id: resolvedId, ref, data: () => (data === undefined ? undefined : clone(data)) };
          },
          async set(data, options) {
            const merge = options && options.merge;
            store.set(path, merge ? applyPatch(store.get(path), data) : clone(data));
          },
          async update(data) {
            store.set(path, applyPatch(store.get(path) || {}, data));
          },
          async add() {
            throw new Error("doc().add is not used by the moderation domain");
          },
        };
        return ref;
      },
      where(field, op, value) {
        return query({ collection: base.split("/").pop(), filters: [{ field, op, value }], limit: null });
      },
      orderBy() {
        return query({ collection: base.split("/").pop(), filters: [], limit: null });
      },
      async add(data) {
        const id = `auto-${++autoInc}`;
        store.set(`${base}/${id}`, clone(data));
        return { id };
      },
      async get() {
        return { docs: selectDocs({ collection: base.split("/").pop(), filters: [], limit: null }) };
      },
    };
  }

  return {
    store,
    collection,
    collectionGroup(name) {
      return query({ group: name, filters: [], limit: null });
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          const data = store.get(ref.path);
          return { exists: data !== undefined, ref, data: () => (data === undefined ? undefined : clone(data)) };
        },
        set(ref, data) {
          store.set(ref.path, clone(data));
        },
        update(ref, data) {
          if (!store.has(ref.path)) throw new Error(`not-found: ${ref.path}`);
          store.set(ref.path, applyPatch(store.get(ref.path), data));
        },
        delete(ref) {
          store.delete(ref.path);
        },
      };
      return callback(transaction);
    },
  };
}

function handlers({ db = createFakeDb(), syncModeratorClaim = null } = {}) {
  const domain = createModerationDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    syncModeratorClaim,
  });
  return { domain, db };
}

const staff = (uid = "mod1") => ({ auth: { uid, token: { moderator: true } } });
const admin = (uid = "admin1") => ({ auth: { uid, token: { admin: true } } });
const member = (uid = "alice") => ({ auth: { uid, token: {} } });

function seedReport() {
  return {
    "edits/e1": {
      creatorId: "creator",
      status: "published",
      moderationStatus: "flagged",
      caption: "hi",
      text: null,
    },
    "fanWorks/w1": {
      creatorId: "creator",
      status: "published",
      moderationStatus: "flagged",
      visibility: "public",
    },
    "anime_stats/16498/reviews/reviewer": {
      userId: "reviewer",
      moderationStatus: "flagged",
      text: "review body",
    },
    "moderation_cases/case-1": {
      type: "edit",
      targetId: "e1",
      reporterId: "alice",
      status: "open",
      reason: "spam",
    },
  };
}

test("every callable rejects an unauthenticated caller", async () => {
  const { domain } = handlers();
  for (const callable of [
    () => domain.listCases({ data: {} }),
    () => domain.getCase({ data: { caseId: "c" } }),
    () => domain.listNeedsReview({ data: { kind: "edit" } }),
    () => domain.removeContent({ data: { kind: "edit", targetId: "e1" } }),
    () => domain.restoreContent({ data: { kind: "edit", targetId: "e1" } }),
    () => domain.resolveCase({ data: { caseId: "c", resolution: "dismiss" } }),
    () => domain.restrictUser({ data: { userId: "bob" } }),
    () => domain.unrestrictUser({ data: { userId: "bob" } }),
    () => domain.getModerationSummary({ data: {} }),
  ]) {
    await assert.rejects(callable(), (error) => error.code === "unauthenticated");
  }
});

test("a plain account cannot reach any moderation callable", async () => {
  const { domain } = handlers({ db: createFakeDb(seedReport()) });
  await assert.rejects(
    domain.removeContent({ ...member(), data: { kind: "edit", targetId: "e1" } }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    domain.listCases({ ...member(), data: {} }),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    domain.resolveCase({
      ...member(),
      data: { caseId: "case-1", resolution: "dismiss" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("admin implies moderator, and a string claim works like a boolean one", async () => {
  const { domain } = handlers({ db: createFakeDb(seedReport()) });
  const result = await domain.listCases({ ...admin(), data: {} });
  assert.equal(result.status, "open");
  const viaString = await domain.listCases({
    auth: { uid: "mod1", token: { moderator: "true" } },
    data: {},
  });
  assert.equal(viaString.cases.length >= 1, true);
});

test("only an admin may change someone's moderator claim", async () => {
  const calls = [];
  const { domain } = handlers({
    db: createFakeDb(seedReport()),
    syncModeratorClaim: async (payload) => calls.push(payload),
  });
  await assert.rejects(
    domain.setModeratorRole({ ...staff(), data: { userId: "bob", moderator: true } }),
    (error) => error.code === "permission-denied",
  );
  const result = await domain.setModeratorRole({
    ...admin(),
    data: { userId: "bob", moderator: true },
  });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, [{ uid: "bob", moderator: true }]);
});

test("a takedown flips moderationStatus to removed and writes an audit row", async () => {
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  const result = await domain.removeContent({
    ...staff(),
    data: { kind: "edit", targetId: "e1", reason: "copyright" },
  });
  assert.equal(result.ok, true);
  const stored = db.store.get("edits/e1");
  assert.equal(stored.moderationStatus, "removed");
  assert.equal(stored.moderationReason, "copyright");
  assert.equal(stored.moderatedBy, "mod1");

  const audits = [...db.store.entries()].filter(([path]) => path.startsWith("moderation_audit/"));
  assert.equal(audits.length, 1);
  assert.equal(audits[0][1].action, "content_removed");
  assert.equal(audits[0][1].actorId, "mod1");
});

test("takedown is idempotent and restore returns content to approved", async () => {
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  await domain.removeContent({ ...staff(), data: { kind: "edit", targetId: "e1" } });
  const again = await domain.removeContent({
    ...staff(),
    data: { kind: "edit", targetId: "e1" },
  });
  assert.equal(again.alreadyRemoved, true);

  const restored = await domain.restoreContent({
    ...staff(),
    data: { kind: "edit", targetId: "e1", previous: { moderationStatus: "approved" } },
  });
  assert.equal(restored.restoredTo, "approved");
  assert.equal(db.store.get("edits/e1").moderationStatus, "approved");
});

test("restoring without a snapshot never resurrects unapproved content", async () => {
  // Falling back to the old status verbatim could restore to "pending", which
  // the read rules treat as invisible — the content would look restored to the
  // moderator and stay hidden from everyone else.
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  await domain.removeContent({ ...staff(), data: { kind: "fanWork", targetId: "w1" } });
  await domain.restoreContent({ ...staff(), data: { kind: "fanWork", targetId: "w1" } });
  assert.equal(db.store.get("fanWorks/w1").moderationStatus, "approved");
});

test("a removed message stops carrying its payload", async () => {
  const db = createFakeDb({
    "groups/g1/messages/m1": {
      senderId: "bob",
      text: "harmful text",
      mediaUrl: "https://example.com/a.jpg",
      thumbnailUrl: "https://example.com/t.jpg",
    },
  });
  const { domain } = handlers({ db });
  await domain.removeContent({
    ...staff(),
    data: { kind: "groupMessage", targetId: "m1", targetParentId: "g1" },
  });
  const stored = db.store.get("groups/g1/messages/m1");
  assert.equal(stored.text, null);
  assert.equal(stored.mediaUrl, null);
  assert.equal(stored.moderationStatus, "removed");
});

test("an anime review takedown addresses the nested document", async () => {
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  const result = await domain.removeContent({
    ...staff(),
    data: { kind: "animeReview", targetId: "reviewer", targetParentId: "16498" },
  });
  assert.equal(result.ok, true);
  assert.equal(
    db.store.get("anime_stats/16498/reviews/reviewer").moderationStatus,
    "removed",
  );
});

test("an anime review takedown without its anime id is refused, not guessed", async () => {
  const { domain } = handlers({ db: createFakeDb(seedReport()) });
  await assert.rejects(
    domain.removeContent({ ...staff(), data: { kind: "animeReview", targetId: "reviewer" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("resolving a case is one-way and idempotent", async () => {
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  const first = await domain.resolveCase({
    ...staff(),
    data: { caseId: "case-1", resolution: "action_taken", note: "removed the Reel" },
  });
  assert.equal(first.status, "resolved");
  const stored = db.store.get("moderation_cases/case-1");
  assert.equal(stored.resolution, "action_taken");
  assert.equal(stored.resolvedBy, "mod1");

  const second = await domain.resolveCase({
    ...staff(),
    data: { caseId: "case-1", resolution: "dismiss" },
  });
  assert.equal(second.alreadyResolved, true);
  assert.equal(db.store.get("moderation_cases/case-1").resolution, "action_taken");
});

test("dismiss sets dismissed, not resolved", async () => {
  const { domain, db } = handlers({ db: createFakeDb(seedReport()) });
  await domain.resolveCase({ ...staff(), data: { caseId: "case-1", resolution: "dismiss" } });
  assert.equal(db.store.get("moderation_cases/case-1").status, "dismissed");
});

test("an invalid resolution is rejected", async () => {
  const { domain } = handlers({ db: createFakeDb(seedReport()) });
  await assert.rejects(
    domain.resolveCase({ ...staff(), data: { caseId: "case-1", resolution: "ban_forever" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("a moderator cannot restrict their own account", async () => {
  const { domain } = handlers({
    db: createFakeDb({ "users/mod1": { username: "Mod" } }),
  });
  await assert.rejects(
    domain.restrictUser({ ...staff("mod1"), data: { userId: "mod1" } }),
    (error) => error.code === "failed-precondition",
  );
});

test("restrict then unrestrict tracks both states in the audit trail", async () => {
  const { domain, db } = handlers({
    db: createFakeDb({ "users/bob": { username: "Bob" } }),
  });
  await domain.restrictUser({
    ...staff(),
    data: { userId: "bob", reason: "harassment", hours: 24 },
  });
  assert.equal(db.store.get("users/bob").moderationState, "restricted");
  assert.equal(typeof db.store.get("users/bob").restrictedUntil, "object");

  await domain.unrestrictUser({ ...staff(), data: { userId: "bob" } });
  const stored = db.store.get("users/bob");
  assert.equal(stored.moderationState, "clear");
  assert.equal(stored.restrictedUntil, null);

  const actions = [...db.store.entries()]
    .filter(([path]) => path.startsWith("moderation_audit/"))
    .map(([, data]) => data.action)
    .sort();
  assert.deepEqual(actions, ["user_restricted", "user_unrestricted"]);
});

test("the needs_review sweep refuses an unknown kind instead of scanning everything", async () => {
  const { domain } = handlers();
  await assert.rejects(
    domain.listNeedsReview({ ...staff(), data: { kind: "users" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("the queue enqueuer is idempotent per reporter and target", async () => {
  const db = createFakeDb();
  const first = await enqueueModerationCase({
    db,
    FieldValue,
    type: "edit",
    targetId: "e1",
    reporterId: "alice",
    creatorId: "creator",
    reason: "spam",
  });
  assert.equal(first.alreadyReported, false);

  const second = await enqueueModerationCase({
    db,
    FieldValue,
    type: "edit",
    targetId: "e1",
    reporterId: "alice",
    creatorId: "creator",
    reason: "harassment",
  });
  assert.equal(second.alreadyReported, true);
  assert.equal(first.caseId, second.caseId);

  const stored = db.store.get(`moderation_cases/${first.caseId}`);
  assert.equal(stored.status, "open");
  assert.equal(stored.reason, "harassment");
  assert.equal(stored.repeatCount, 2);
});

test("the enqueuer refuses an unknown case type rather than writing a mystery row", async () => {
  const db = createFakeDb();
  await assert.rejects(
    enqueueModerationCase({
      db,
      FieldValue,
      type: "notAThing",
      targetId: "x",
      reporterId: "alice",
      reason: "spam",
    }),
    /Unknown moderation case type/,
  );
  assert.equal(db.store.size, 0);
});

test("case ids are filesystem-safe for hostile target ids", () => {
  const id = moderationCaseId({
    type: "edit",
    targetId: "../../etc/passwd",
    reporterId: "alice",
  });
  assert.equal(/^[A-Za-z0-9_-]+$/.test(id), true);
  assert.equal(id.includes("/"), false);
});

test("the exposed kind lists stay in sync with the supported set", () => {
  assert.deepEqual([...REMOVABLE_KINDS].sort(), [
    "animeReview",
    "edit",
    "event",
    "fanWork",
    "groupMessage",
    "privateMessage",
  ]);
  assert.deepEqual([...REVIEW_KINDS].sort(), ["animeReview", "edit", "fanWork"]);
});
