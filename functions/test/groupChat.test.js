"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createGroupChat,
  expectedMediaType,
  validateMessage,
} = require("../src/groupChat");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function handlers() {
  return createGroupChat({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
}

test("chat callables reject unauthenticated requests before database access", async () => {
  await assert.rejects(
    handlers().sendMessage({
      data: { groupId: "g1", messageId: "m1", type: "text", text: "hello" },
    }),
    (error) => error.code === "unauthenticated",
  );
});

test("users cannot publish server-owned event and game messages", async () => {
  await assert.rejects(
    handlers().sendMessage({
      auth: { uid: "alice" },
      data: { groupId: "g1", messageId: "m1", type: "event", text: "event" },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers().sendMessage({
      auth: { uid: "alice" },
      data: { groupId: "g1", messageId: "m2", type: "game", text: "game" },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("media messages require a pipeline media identifier", async () => {
  await assert.rejects(
    handlers().sendMessage({
      auth: { uid: "alice" },
      data: {
        groupId: "g1",
        messageId: "m1",
        type: "image",
        mediaUrl: "https://example.com/raw.jpg",
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("catalog stickers do not require mediaId; unknown keys do", () => {
  validateMessage({ type: "sticker", stickerKey: "reactions/heart" }, TestHttpsError);
  assert.throws(
    () => validateMessage({ type: "sticker", stickerKey: "stolen/pack" }, TestHttpsError),
    (error) => error.code === "invalid-argument",
  );
});

test("expected media types map gif/sticker to image and audio to audio", () => {
  assert.equal(expectedMediaType("gif"), "image");
  assert.equal(expectedMediaType("sticker"), "image");
  assert.equal(expectedMediaType("audio"), "audio");
  assert.equal(expectedMediaType("video"), "video");
  assert.equal(expectedMediaType("image"), "image");
});

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
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
        async get() {
          const data = store.get(path);
          return {
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
        set(ref, data) {
          store.set(ref.path, clone(data));
        },
        update(ref, data) {
          if (!store.has(ref.path)) throw new Error("not-found");
          store.set(ref.path, { ...store.get(ref.path), ...clone(data) });
        },
      };
      return callback(transaction);
    },
  };
}

const FieldValue = { serverTimestamp: () => ({ _serverTimestamp: true }) };

function seedChat({ destMember = true } = {}) {
  const seed = {
    "groups/g1": { founderId: "alice", membersCount: 2 },
    "groups/g1/members/alice": { userId: "alice", role: "member", displayName: "Alice" },
    "groups/g1/members/bob": { userId: "bob", role: "member", displayName: "Bob" },
    "groups/g1/messages/m-text": {
      senderId: "bob", type: "text", text: "hello from bob", deletedAt: null,
    },
    "groups/g1/media/ready-audio": {
      status: "ready",
      uploaderId: "alice",
      mediaType: "audio",
      originalPath: "groups/g1/media/ready-audio_original.m4a",
    },
    "groups/g1/media/ready-gif": {
      status: "ready",
      uploaderId: "alice",
      mediaType: "image",
      originalPath: "groups/g1/media/ready-gif_original.gif",
      thumbnailPath: "groups/g1/media/ready-gif_thumb.jpg",
      mediumPath: "groups/g1/media/ready-gif_medium.jpg",
    },
    "groups/g2": { founderId: "alice", membersCount: 2 },
    "privateChats/c1": { participantIds: ["alice", "dana"] },
    "users/alice": { displayName: "Alice", avatarUrl: "" },
  };
  if (destMember) {
    seed["groups/g2/members/alice"] = {
      userId: "alice", role: "member", displayName: "Alice",
    };
  }
  return seed;
}

function chatHandlers(db) {
  return createGroupChat({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    randomUUID: () => "fwd-1",
  });
}

test("catalog sticker send stores stickerKey without media", async () => {
  const db = createFakeDb(seedChat());
  const result = await chatHandlers(db).sendMessage({
    auth: { uid: "alice" },
    data: {
      groupId: "g1",
      messageId: "m-sticker",
      type: "sticker",
      stickerKey: "reactions/heart",
    },
  });
  assert.equal(result.ok, true);
  const stored = db.store.get("groups/g1/messages/m-sticker");
  assert.equal(stored.stickerKey, "reactions/heart");
  assert.equal(stored.mediaId, null);
  assert.equal(stored.type, "sticker");
  assert.equal(stored.stickerCreatorId, "pubget");
  assert.equal(stored.stickerCreatorName, "Pubget");
});

test("custom sticker preserves original creator across resend", async () => {
  const db = createFakeDb(seedChat());
  const result = await chatHandlers(db).sendMessage({
    auth: { uid: "alice" },
    data: {
      groupId: "g1",
      messageId: "m-custom-sticker",
      type: "sticker",
      mediaId: "ready-gif",
      stickerCreatorId: "original-creator",
      stickerCreatorName: "Original Creator",
    },
  });
  assert.equal(result.ok, true);
  const stored = db.store.get("groups/g1/messages/m-custom-sticker");
  assert.equal(stored.type, "sticker");
  assert.equal(stored.stickerKey, null);
  assert.equal(stored.stickerCreatorId, "original-creator");
  assert.equal(stored.stickerCreatorName, "Original Creator");
});

test("audio and gif sends require matching ready media types", async () => {
  const db = createFakeDb(seedChat());
  const chat = chatHandlers(db);
  const audio = await chat.sendMessage({
    auth: { uid: "alice" },
    data: { groupId: "g1", messageId: "m-audio", type: "audio", mediaId: "ready-audio" },
  });
  assert.equal(audio.ok, true);
  assert.equal(db.store.get("groups/g1/messages/m-audio").type, "audio");
  const gif = await chat.sendMessage({
    auth: { uid: "alice" },
    data: { groupId: "g1", messageId: "m-gif", type: "gif", mediaId: "ready-gif" },
  });
  assert.equal(gif.ok, true);
  assert.equal(db.store.get("groups/g1/messages/m-gif").type, "gif");
  await assert.rejects(
    chat.sendMessage({
      auth: { uid: "alice" },
      data: { groupId: "g1", messageId: "m-bad", type: "audio", mediaId: "ready-gif" },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("reply stores a server-derived preview", async () => {
  const db = createFakeDb(seedChat());
  await chatHandlers(db).sendMessage({
    auth: { uid: "alice" },
    data: {
      groupId: "g1",
      messageId: "m-reply",
      type: "text",
      text: "quoted",
      replyToMessageId: "m-text",
    },
  });
  const stored = db.store.get("groups/g1/messages/m-reply");
  assert.equal(stored.replyToMessageId, "m-text");
  assert.equal(stored.replyPreview, "hello from bob");
});

test("forward requires destination membership and writes forwardedFrom", async () => {
  const allowed = createFakeDb(seedChat());
  const ok = await chatHandlers(allowed).forwardMessage({
    auth: { uid: "alice" },
    data: {
      sourceGroupId: "g1",
      messageId: "m-text",
      destinationGroupId: "g2",
    },
  });
  assert.equal(ok.ok, true);
  const dest = allowed.store.get("groups/g2/messages/fwd-1");
  assert.equal(dest.text, "hello from bob");
  assert.equal(dest.forwardedFrom.groupId, "g1");
  assert.equal(dest.forwardedFrom.messageId, "m-text");

  const denied = createFakeDb(seedChat({ destMember: false }));
  await assert.rejects(
    chatHandlers(denied).forwardMessage({
      auth: { uid: "alice" },
      data: {
        sourceGroupId: "g1",
        messageId: "m-text",
        destinationGroupId: "g2",
      },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("forward into a private chat checks participantIds", async () => {
  const db = createFakeDb(seedChat());
  const ok = await chatHandlers(db).forwardMessage({
    auth: { uid: "alice" },
    data: {
      sourceGroupId: "g1",
      messageId: "m-text",
      destinationChatId: "c1",
    },
  });
  assert.equal(ok.ok, true);
  assert.equal(db.store.get("privateChats/c1/messages/fwd-1").senderId, "alice");
  await assert.rejects(
    chatHandlers(db).forwardMessage({
      auth: { uid: "bob" },
      data: {
        sourceGroupId: "g1",
        messageId: "m-text",
        destinationChatId: "c1",
      },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("report identity is server-derived and cannot target self", async () => {
  const db = createFakeDb(seedChat());
  const chat = chatHandlers(db);
  await assert.rejects(
    chat.reportMessage({
      data: { groupId: "g1", messageId: "m-text", reason: "spam", reporterId: "forged" },
    }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    chat.reportMessage({
      auth: { uid: "bob" },
      data: { groupId: "g1", messageId: "m-text", reason: "spam" },
    }),
    (error) => error.code === "failed-precondition",
  );
  const ok = await chat.reportMessage({
    auth: { uid: "alice" },
    data: { groupId: "g1", messageId: "m-text", reason: "spam", reporterId: "forged" },
  });
  assert.equal(ok.ok, true);
  const report = db.store.get("groups/g1/messageReports/m-text_alice");
  assert.equal(report.reporterId, "alice");
  assert.equal(report.reason, "spam");
  assert.equal(report.status, "open");
});

test("edit enforces the server-side fifteen minute window", async () => {
  const db = createFakeDb(seedChat());
  db.store.get("groups/g1/messages/m-text").createdAt =
    new Date(Date.now() - 14 * 60 * 1000).toISOString();
  const ok = await chatHandlers(db).editMessage({
    auth: { uid: "bob" },
    data: { groupId: "g1", messageId: "m-text", text: "updated" },
  });
  assert.equal(ok.ok, true);
  assert.equal(db.store.get("groups/g1/messages/m-text").text, "updated");

  db.store.get("groups/g1/messages/m-text").createdAt =
    new Date(Date.now() - 16 * 60 * 1000).toISOString();
  await assert.rejects(
    chatHandlers(db).editMessage({
      auth: { uid: "bob" },
      data: { groupId: "g1", messageId: "m-text", text: "too late" },
    }),
    (error) => error.code === "failed-precondition",
  );
});