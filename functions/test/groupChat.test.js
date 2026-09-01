"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createGroupChat } = require("../src/groupChat");

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