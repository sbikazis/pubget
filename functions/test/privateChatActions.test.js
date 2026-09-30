"use strict";

// Covers the private-chat message actions (edit / pin / react / report /
// delete) and the forwarded-provenance contract, which is what the client
// action sheet depends on.

const assert = require("node:assert/strict");
const test = require("node:test");
const { createPrivateChat } = require("../src/privateChat");
const { createGroupChat } = require("../src/groupChat");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
  delete: () => ({ _delete: true }),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

function applyUpdate(current, data) {
  const next = clone(current);
  for (const [key, value] of Object.entries(data)) {
    const parts = key.split(".");
    if (value && value._delete) {
      let cursor = next;
      for (let index = 0; index < parts.length - 1; index += 1) {
        if (!cursor[parts[index]] || typeof cursor[parts[index]] !== "object") {
          cursor = null;
          break;
        }
        cursor = cursor[parts[index]];
      }
      if (cursor) delete cursor[parts[parts.length - 1]];
      continue;
    }
    let cursor = next;
    for (let index = 0; index < parts.length - 1; index += 1) {
      if (!cursor[parts[index]] || typeof cursor[parts[index]] !== "object") {
        cursor[parts[index]] = {};
      }
      cursor = cursor[parts[index]];
    }
    cursor[parts[parts.length - 1]] = clone(value);
  }
  return next;
}

// `strictOrder` makes the fake behave like real Firestore: once a transaction
// writes, any further read throws. That is the invariant these callables must
// respect, so the tests fail loudly if one regresses to read-after-write.
function createFakeDb(seed = {}, { strictOrder = false } = {}) {
  const store = new Map(Object.entries(clone(seed)));
  const collection = (base) => ({
    doc(id) {
      const path = `${base}/${id}`;
      return {
        path,
        id,
        collection(name) {
          return collection(`${path}/${name}`);
        },
        async get() {
          const data = store.get(path);
          return {
            path,
            exists: data !== undefined,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
      };
    },
  });
  return {
    store,
    collection(name) {
      return collection(name);
    },
    async runTransaction(callback) {
      let wrote = false;
      const assertReadable = () => {
        if (strictOrder && wrote) {
          const error = new Error("reads must all come before writes");
          error.code = "read-after-write";
          throw error;
        }
      };
      const markWritten = () => {
        wrote = true;
      };
      const transaction = {
        async get(ref) {
          assertReadable();
          const data = store.get(ref.path);
          return {
            exists: data !== undefined,
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
          markWritten();
        },
        set(ref, data, options) {
          if (options && options.merge) {
            store.set(ref.path, {
              ...(store.get(ref.path) || {}),
              ...clone(data),
            });
            markWritten();
            return;
          }
          store.set(ref.path, clone(data));
          markWritten();
        },
        update(ref, data) {
          if (!store.has(ref.path)) throw new Error("not-found");
          store.set(ref.path, applyUpdate(store.get(ref.path), data));
          markWritten();
        },
      };
      return callback(transaction);
    },
  };
}

function privateHandlers(db) {
  return createPrivateChat({ db, FieldValue, HttpsError: TestHttpsError });
}

function groupHandlers(db) {
  return createGroupChat({ db, FieldValue, HttpsError: TestHttpsError });
}

const CHAT = "privateChats/chat-alice-bob";

function seedPrivateChat(overrides = {}) {
  return {
    [CHAT]: {
      userA: "alice",
      userB: "bob",
      participantIds: ["alice", "bob"],
      lastMessageId: "m1",
      lastMessageText: "original",
      ...(overrides.chat || {}),
    },
    [`${CHAT}/messages/m1`]: {
      senderId: "alice",
      type: "text",
      text: "original",
      createdAt: new Date().toISOString(),
      ...(overrides.message || {}),
    },
  };
}

function auth(uid) {
  return { auth: { uid } };
}

test("editing a private message keeps the original createdAt", async () => {
  const seed = seedPrivateChat();
  const seededCreatedAt = seed[`${CHAT}/messages/m1`].createdAt;
  const db = createFakeDb(seed, { strictOrder: true });
  const chat = privateHandlers(db);
  const result = await chat.editMessage({
    ...auth("alice"),
    data: { chatId: "chat-alice-bob", messageId: "m1", text: "  corrected  " },
  });

  assert.equal(result.ok, true);
  assert.equal(result.message.text, "corrected");
  // Message ordering depends on createdAt, so an edit must never rewrite it.
  assert.equal(result.message.createdAt, seededCreatedAt);
  assert.equal(db.store.get(`${CHAT}/messages/m1`).createdAt, seededCreatedAt);
  // The edit itself is still recorded.
  assert.ok(db.store.get(`${CHAT}/messages/m1`).editedAt);
  // The newest-message preview has to follow the edit.
  assert.equal(db.store.get(CHAT).lastMessageText, "corrected");
});

test("editing a private message is rejected after the 15 minute window", async () => {
  const stale = new Date(Date.now() - 16 * 60 * 1000).toISOString();
  const db = createFakeDb(seedPrivateChat({ message: { createdAt: stale } }));
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.editMessage({
      ...auth("alice"),
      data: { chatId: "chat-alice-bob", messageId: "m1", text: "too late" },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("editing someone else's private message is rejected", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.editMessage({
      ...auth("bob"),
      data: { chatId: "chat-alice-bob", messageId: "m1", text: "not yours" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("editing a media private message is rejected", async () => {
  const db = createFakeDb(
    seedPrivateChat({ message: { type: "image", text: null } }),
  );
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.editMessage({
      ...auth("alice"),
      data: { chatId: "chat-alice-bob", messageId: "m1", text: "caption" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("deleting a private message tombstones it and clears the preview", async () => {
  const db = createFakeDb(seedPrivateChat(), { strictOrder: true });
  const chat = privateHandlers(db);
  const result = await chat.deleteMessage({
    ...auth("alice"),
    data: { chatId: "chat-alice-bob", messageId: "m1" },
  });

  assert.deepEqual(result, { ok: true });
  const stored = db.store.get(`${CHAT}/messages/m1`);
  assert.ok(stored.deletedAt, "message must be tombstoned");
  assert.equal(stored.text, null);
  assert.equal(stored.mediaUrl, null);
  assert.equal(stored.mediaWidth, null);
  assert.equal(db.store.get(CHAT).lastMessageText, "[deleted]");
});

test("deleting a private message you did not send is rejected", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.deleteMessage({
      ...auth("bob"),
      data: { chatId: "chat-alice-bob", messageId: "m1" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("only the sender can pin a private message, and unpinning clears it", async () => {
  const db = createFakeDb(seedPrivateChat(), { strictOrder: true });
  const chat = privateHandlers(db);

  await assert.rejects(
    chat.pinMessage({
      ...auth("bob"),
      data: { chatId: "chat-alice-bob", messageId: "m1", pinned: true },
    }),
    (error) => error.code === "permission-denied",
  );

  await chat.pinMessage({
    ...auth("alice"),
    data: { chatId: "chat-alice-bob", messageId: "m1", pinned: true },
  });
  assert.ok(db.store.get(`${CHAT}/messages/m1`).pinnedAt);

  await chat.pinMessage({
    ...auth("alice"),
    data: { chatId: "chat-alice-bob", messageId: "m1", pinned: false },
  });
  assert.equal(db.store.get(`${CHAT}/messages/m1`).pinnedAt, null);
});

test("a private reaction toggles per user and keeps counts in sync", async () => {
  const db = createFakeDb(seedPrivateChat(), { strictOrder: true });
  const chat = privateHandlers(db);

  await chat.addReaction({
    ...auth("bob"),
    data: { chatId: "chat-alice-bob", messageId: "m1", reaction: "❤️" },
  });
  let stored = db.store.get(`${CHAT}/messages/m1`);
  assert.equal(stored.reactions["❤️"], 1);
  assert.equal(Object.keys(stored.reactionUsers["❤️"]).length, 1);

  await chat.addReaction({
    ...auth("alice"),
    data: { chatId: "chat-alice-bob", messageId: "m1", reaction: "❤️" },
  });
  stored = db.store.get(`${CHAT}/messages/m1`);
  assert.equal(stored.reactions["❤️"], 2);

  // Bob reacting again removes his own reaction instead of double counting.
  await chat.addReaction({
    ...auth("bob"),
    data: { chatId: "chat-alice-bob", messageId: "m1", reaction: "❤️" },
  });
  stored = db.store.get(`${CHAT}/messages/m1`);
  assert.equal(stored.reactions["❤️"], 1);
  assert.equal(stored.reactionUsers["❤️"].alice, true);
});

test("a reaction cannot be added to a deleted private message", async () => {
  const db = createFakeDb(
    seedPrivateChat({ message: { deletedAt: new Date().toISOString() } }),
  );
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.addReaction({
      ...auth("bob"),
      data: { chatId: "chat-alice-bob", messageId: "m1", reaction: "❤️" },
    }),
    (error) => error.code === "not-found",
  );
});

test("reporting a private message needs a structured reason", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.reportMessage({
      ...auth("bob"),
      data: { chatId: "chat-alice-bob", messageId: "m1", reason: "because" },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("you cannot report your own private message", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  await assert.rejects(
    chat.reportMessage({
      ...auth("alice"),
      data: { chatId: "chat-alice-bob", messageId: "m1", reason: "spam" },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("reporting a private message stores one open report per reporter", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  const first = await chat.reportMessage({
    ...auth("bob"),
    data: { chatId: "chat-alice-bob", messageId: "m1", reason: "spam" },
  });
  assert.equal(first.ok, true);
  const reportPath = `${CHAT}/messageReports/m1_bob`;
  assert.equal(db.store.get(reportPath).status, "open");
  assert.equal(db.store.get(reportPath).reporterId, "bob");

  // Re-reporting is idempotent rather than duplicating the report row.
  await chat.reportMessage({
    ...auth("bob"),
    data: { chatId: "chat-alice-bob", messageId: "m1", reason: "spam" },
  });
  assert.equal(db.store.get(reportPath).reason, "spam");
});

test("private actions reject a non-participant", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  for (const call of [
    () => chat.pinMessage({
      ...auth("carol"),
      data: { chatId: "chat-alice-bob", messageId: "m1", pinned: true },
    }),
    () => chat.addReaction({
      ...auth("carol"),
      data: { chatId: "chat-alice-bob", messageId: "m1", reaction: "❤️" },
    }),
    () => chat.deleteMessage({
      ...auth("carol"),
      data: { chatId: "chat-alice-bob", messageId: "m1" },
    }),
  ]) {
    await assert.rejects(call(), (error) => error.code === "permission-denied");
  }
});

test("private actions reject unauthenticated callers", async () => {
  const db = createFakeDb(seedPrivateChat());
  const chat = privateHandlers(db);
  const base = { chatId: "chat-alice-bob", messageId: "m1" };
  await assert.rejects(
    chat.editMessage({ data: { ...base, text: "x" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.deleteMessage({ data: base }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.pinMessage({ data: { ...base, pinned: true } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.addReaction({ data: { ...base, reaction: "❤️" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.reportMessage({ data: { ...base, reason: "spam" } }),
    (error) => error.code === "unauthenticated",
  );
});

// --- forwarded provenance -------------------------------------------------

const GROUP = "groups/club";
const PRIVATE = "privateChats/chat-alice-bob";

function seedForwardFixtures({ sourceInGroup, sourceInPrivate }) {
  const seed = {
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
    "users/carol": { username: "Carol" },
    [GROUP]: {
      name: "Club",
      membersCount: 3,
      memberIds: ["alice", "bob", "carol"],
      lastMessageId: "g1",
    },
    [`${GROUP}/members/alice`]: { role: "member" },
    [`${GROUP}/members/bob`]: { role: "member" },
    [`${GROUP}/members/carol`]: { role: "member" },
    [PRIVATE]: {
      userA: "alice",
      userB: "bob",
      participantIds: ["alice", "bob"],
    },
  };
  if (sourceInGroup) {
    seed[`${GROUP}/messages/g1`] = {
      senderId: "bob",
      type: "text",
      text: "group source",
      createdAt: new Date().toISOString(),
    };
  }
  if (sourceInPrivate) {
    seed[`${PRIVATE}/messages/p1`] = {
      senderId: "bob",
      type: "text",
      text: "private source",
      createdAt: new Date().toISOString(),
    };
  }
  return seed;
}

test("forwarding from a private chat to a group records chat provenance", async () => {
  const db = createFakeDb(seedForwardFixtures({ sourceInPrivate: true }));
  const chat = groupHandlers(db);
  const result = await chat.forwardMessage({
    ...auth("alice"),
    data: {
      sourceChatId: "chat-alice-bob",
      messageId: "p1",
      destinationGroupId: "club",
    },
  });

  assert.equal(result.ok, true);
  const created = db.store.get(`${GROUP}/messages/${result.messageId}`);
  // A private source must be labelled `chatId`, never `groupId`.
  assert.equal(created.forwardedFrom.chatId, "chat-alice-bob");
  assert.equal(created.forwardedFrom.groupId, undefined);
  assert.equal(created.forwardedFrom.messageId, "p1");
  assert.equal(created.text, "private source");
});

test("forwarding from a group to a private chat records group provenance", async () => {
  const db = createFakeDb(seedForwardFixtures({ sourceInGroup: true }));
  const chat = groupHandlers(db);
  const result = await chat.forwardMessage({
    ...auth("alice"),
    data: {
      sourceGroupId: "club",
      messageId: "g1",
      destinationChatId: "chat-alice-bob",
    },
  });

  assert.equal(result.ok, true);
  const created = db.store.get(`${PRIVATE}/messages/${result.messageId}`);
  assert.equal(created.forwardedFrom.groupId, "club");
  assert.equal(created.forwardedFrom.chatId, undefined);
  assert.equal(created.forwardedFrom.messageId, "g1");
});

test("forwarding requires exactly one source and one destination", async () => {
  const db = createFakeDb(seedForwardFixtures({ sourceInGroup: true }));
  const chat = groupHandlers(db);
  const rejections = [
    { messageId: "g1", destinationChatId: "chat-alice-bob" },
    {
      sourceGroupId: "club",
      sourceChatId: "chat-alice-bob",
      messageId: "g1",
      destinationChatId: "chat-alice-bob",
    },
    { sourceGroupId: "club", messageId: "g1" },
    {
      sourceGroupId: "club",
      messageId: "g1",
      destinationGroupId: "club",
      destinationChatId: "chat-alice-bob",
    },
  ];
  for (const data of rejections) {
    await assert.rejects(
      chat.forwardMessage({ ...auth("alice"), data }),
      (error) => error.code === "invalid-argument",
    );
  }
});

test("a non-member cannot forward out of a group", async () => {
  const db = createFakeDb(seedForwardFixtures({ sourceInGroup: true }));
  const chat = groupHandlers(db);
  await assert.rejects(
    chat.forwardMessage({
      ...auth("carol"),
      data: {
        sourceGroupId: "club",
        messageId: "g1",
        destinationChatId: "chat-alice-bob",
      },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("a deleted private message cannot be forwarded", async () => {
  const seed = seedForwardFixtures({ sourceInPrivate: true });
  seed[`${PRIVATE}/messages/p1`].deletedAt = new Date().toISOString();
  const db = createFakeDb(seed);
  const chat = groupHandlers(db);
  await assert.rejects(
    chat.forwardMessage({
      ...auth("alice"),
      data: {
        sourceChatId: "chat-alice-bob",
        messageId: "p1",
        destinationGroupId: "club",
      },
    }),
    (error) => error.code === "failed-precondition",
  );
});
