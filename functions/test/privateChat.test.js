"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { pairId } = require("../src/socialGraph");
const { createPrivateChat } = require("../src/privateChat");

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

function createFakeDb(seed = {}) {
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
      };
    },
  });
  return {
    store,
    collection(name) {
      return collection(name);
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
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
        },
        set(ref, data, options) {
          if (options && options.merge) {
            store.set(ref.path, {
              ...(store.get(ref.path) || {}),
              ...clone(data),
            });
            return;
          }
          store.set(ref.path, clone(data));
        },
        update(ref, data) {
          if (!store.has(ref.path)) throw new Error("not-found");
          store.set(ref.path, applyUpdate(store.get(ref.path), data));
        },
      };
      return callback(transaction);
    },
  };
}

function handlers(db) {
  return createPrivateChat({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
  });
}

function seedRelatedUsers({
  aliceToBobRespect = 0,
  bobToAliceRespect = 0,
  friendshipStatus = null,
  whoCanMessageMe = "related",
} = {}) {
  const seed = {
    "users/alice": { username: "Alice", avatarUrl: "", whoCanMessageMe: "related" },
    "users/bob": { username: "Bob", avatarUrl: "", whoCanMessageMe },
  };
  if (aliceToBobRespect > 0) {
    seed["respects/5:alice3:bob"] = {
      fromUserId: "alice",
      toUserId: "bob",
      value: aliceToBobRespect,
    };
  }
  if (bobToAliceRespect > 0) {
    seed["respects/3:bob5:alice"] = {
      fromUserId: "bob",
      toUserId: "alice",
      value: bobToAliceRespect,
    };
  }
  if (friendshipStatus) {
    const [userA, userB] = ["alice", "bob"].sort();
    seed[`friendships/${pairId("alice", "bob")}`] = {
      userA,
      userB,
      userIds: [userA, userB],
      status: friendshipStatus,
      requestedBy: "alice",
      blockedBy: friendshipStatus === "blocked" ? "bob" : null,
    };
  }
  return seed;
}

test("private chat callables reject unauthenticated requests", async () => {
  const chat = handlers(createFakeDb());
  await assert.rejects(
    chat.startPrivateChat({ data: { otherUserId: "bob" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.sendPrivateMessage({
      data: { chatId: "x", messageId: "m1", type: "text", text: "hi" },
    }),
    (error) => error.code === "unauthenticated",
  );
});

test("cannot start a private chat without a Fan or Friend relationship", async () => {
  const db = createFakeDb(seedRelatedUsers());
  const chat = handlers(db);
  await assert.rejects(
    chat.startPrivateChat({
      auth: { uid: "alice" },
      data: { otherUserId: "bob" },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("a Fan relationship is enough when the recipient allows related senders", async () => {
  const db = createFakeDb(seedRelatedUsers({ aliceToBobRespect: 5 }));
  const chat = handlers(db);
  const result = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  assert.equal(result.ok, true);
  assert.equal(result.chatId, pairId("alice", "bob"));
  assert.equal(result.created, true);
  assert.ok(db.store.has(`privateChats/${result.chatId}`));
});

test("friends-only recipients reject a Fan who is not a Friend", async () => {
  const db = createFakeDb(seedRelatedUsers({
    aliceToBobRespect: 7,
    whoCanMessageMe: "friends",
  }));
  const chat = handlers(db);
  await assert.rejects(
    chat.startPrivateChat({
      auth: { uid: "alice" },
      data: { otherUserId: "bob" },
    }),
    (error) => error.code === "permission-denied" &&
      /Friends/.test(error.message),
  );
});

test("an accepted Friend can start a chat with a friends-only recipient", async () => {
  const db = createFakeDb(seedRelatedUsers({
    friendshipStatus: "accepted",
    whoCanMessageMe: "friends",
  }));
  const chat = handlers(db);
  const result = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  assert.equal(result.created, true);
  assert.equal(result.chatId, pairId("alice", "bob"));
});

test("startPrivateChat is idempotent for an existing pair", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const first = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  const second = await chat.startPrivateChat({
    auth: { uid: "bob" },
    data: { otherUserId: "alice" },
  });
  assert.equal(first.chatId, second.chatId);
  assert.equal(first.created, true);
  assert.equal(second.created, false);
});

test("chat ids use length-prefixed pairId and do not collide on underscore UIDs", () => {
  assert.notEqual(pairId("a_b", "c"), pairId("a", "b_c"));
  assert.equal(pairId("alice", "bob"), pairId("bob", "alice"));
  assert.equal(pairId("alice", "bob"), "5:alice3:bob");
});

test("a later Block denies sendPrivateMessage on an existing chat", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  const friendshipPath = `friendships/${started.chatId}`;
  db.store.get(friendshipPath).status = "blocked";
  db.store.get(friendshipPath).blockedBy = "bob";

  await assert.rejects(
    chat.sendPrivateMessage({
      auth: { uid: "alice" },
      data: {
        chatId: started.chatId,
        messageId: "m1",
        type: "text",
        text: "still trying",
      },
    }),
    (error) => error.code === "permission-denied" && /blocked/.test(error.message),
  );
  assert.equal(
    db.store.has(`privateChats/${started.chatId}/messages/m1`),
    false,
  );
});

test("sendPrivateMessage writes aggregate receipts like group chat", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  const sent = await chat.sendPrivateMessage({
    auth: { uid: "alice" },
    data: {
      chatId: started.chatId,
      messageId: "hello-1",
      type: "text",
      text: "Hello Bob",
    },
  });
  assert.equal(sent.ok, true);
  const stored = db.store.get(`privateChats/${started.chatId}/messages/hello-1`);
  assert.equal(stored.senderId, "alice");
  assert.equal(stored.recipientCount, 1);
  assert.equal(stored.deliveredCount, 0);
  assert.equal(stored.readCount, 0);
  assert.equal(stored.senderRole, "");
  const parent = db.store.get(`privateChats/${started.chatId}`);
  assert.equal(parent.lastMessageText, "Hello Bob");
  assert.equal(parent.lastMessageSenderId, "alice");
});

test("a blocked relationship cannot start a private chat", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "blocked" }));
  const chat = handlers(db);
  await assert.rejects(
    chat.startPrivateChat({
      auth: { uid: "alice" },
      data: { otherUserId: "bob" },
    }),
    (error) => error.code === "permission-denied" && /blocked/.test(error.message),
  );
});

test("a stranger cannot send into someone else's chat", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  await assert.rejects(
    chat.sendPrivateMessage({
      auth: { uid: "mallory" },
      data: {
        chatId: started.chatId,
        messageId: "spy-1",
        type: "text",
        text: "hello",
      },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("friends-only policy is re-checked on every send", async () => {
  const db = createFakeDb(seedRelatedUsers({
    aliceToBobRespect: 6,
    whoCanMessageMe: "related",
  }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  db.store.get("users/bob").whoCanMessageMe = "friends";
  await assert.rejects(
    chat.sendPrivateMessage({
      auth: { uid: "alice" },
      data: {
        chatId: started.chatId,
        messageId: "after-policy",
        type: "text",
        text: "still a fan",
      },
    }),
    (error) => error.code === "permission-denied" && /Friends/.test(error.message),
  );
});

test("markMessagesRead updates lastReadAt without N+1 user queries", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  await chat.sendPrivateMessage({
    auth: { uid: "alice" },
    data: {
      chatId: started.chatId,
      messageId: "read-me",
      type: "text",
      text: "Hello",
    },
  });
  const marked = await chat.markMessagesRead({
    auth: { uid: "bob" },
    data: { chatId: started.chatId, messageIds: ["read-me"] },
  });
  assert.equal(marked.ok, true);
  const stored = db.store.get(`privateChats/${started.chatId}/messages/read-me`);
  assert.equal(stored.readBy.bob, true);
  assert.equal(stored.readCount, 1);
  const parent = db.store.get(`privateChats/${started.chatId}`);
  assert.ok(parent.participants.bob.lastReadAt);
});

test("media messages require a processed pipeline document owned by the sender", async () => {
  const db = createFakeDb(seedRelatedUsers({ friendshipStatus: "accepted" }));
  const chat = handlers(db);
  const started = await chat.startPrivateChat({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  await assert.rejects(
    chat.sendPrivateMessage({
      auth: { uid: "alice" },
      data: {
        chatId: started.chatId,
        messageId: "img-1",
        type: "image",
        mediaId: "missing",
      },
    }),
    (error) => error.code === "failed-precondition",
  );
});
