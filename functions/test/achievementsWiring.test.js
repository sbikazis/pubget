"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createGroupsDomain } = require("../src/groupsDomain");
const { createGroupChat } = require("../src/groupChat");

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
            return { exists: data !== undefined, data: () => clone(data), id: ref.id };
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
          update(ref, data) {
            if (!store.has(ref.path)) throw new Error("not-found");
            store.set(ref.path, { ...store.get(ref.path), ...clone(data) });
          },
          delete(ref) {
            store.delete(ref.path);
          },
        };
        return callback(transaction);
      });
      chain = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

test("joinGroup evaluates group_joined for achievements", async () => {
  const events = [];
  const db = createFakeDb({
    "groups/g1": {
      founderId: "alice",
      name: "G",
      type: "public",
      joinPolicy: "open",
      membersCount: 1,
      maxMembers: 100,
    },
    "groups/g1/members/alice": {
      uid: "alice",
      role: "founder",
      displayName: "Alice",
      realUserName: "Alice",
      realUserImageUrl: "",
      isPremium: false,
    },
  });
  const domain = createGroupsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    randomUUID: () => "id",
    achievements: {
      async evaluate(event) {
        events.push(event);
      },
    },
  });

  await domain.joinGroup({
    auth: { uid: "bob" },
    data: { groupId: "g1" },
  });

  assert.equal(events.length, 1);
  assert.equal(events[0].type, "group_joined");
  assert.equal(events[0].userId, "bob");
  assert.equal(events[0].metadata.groupId, "g1");
  assert.ok(db.store.has("groups/g1/members/bob"));
});

test("sendMessage evaluates message_sent for achievements", async () => {
  const events = [];
  const db = createFakeDb({
    "groups/g1": {
      founderId: "alice",
      name: "G",
      membersCount: 2,
      maxMembers: 100,
    },
    "groups/g1/members/alice": {
      uid: "alice",
      role: "founder",
      displayName: "Alice",
      realUserName: "Alice",
      realUserImageUrl: "",
      isPremium: false,
    },
  });
  const chat = createGroupChat({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    randomUUID: () => "uuid",
    achievements: {
      async evaluate(event) {
        events.push(event);
      },
    },
  });

  await chat.sendMessage({
    auth: { uid: "alice" },
    data: {
      groupId: "g1",
      messageId: "m1",
      type: "text",
      text: "hello achievements",
    },
  });

  assert.equal(events.length, 1);
  assert.equal(events[0].type, "message_sent");
  assert.equal(events[0].userId, "alice");
  assert.equal(events[0].metadata.groupId, "g1");
  assert.equal(events[0].metadata.messageId, "m1");
});
