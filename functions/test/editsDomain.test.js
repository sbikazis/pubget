"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createEditsDomain } = require("../src/editsDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function handlers() {
  return createEditsDomain({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
}

test("edit mutations reject unauthenticated requests before database access", async () => {
  for (const [handler, data] of [
    ["startUpload", {}],
    ["repost", { editId: "e1" }],
    ["deleteEdit", { editId: "e1" }],
    ["like", { editId: "e1" }],
    ["comment", { editId: "e1", text: "hello" }],
    ["recordView", { editId: "e1", watchPercent: 50, watchSeconds: 3 }],
    ["signal", { editId: "e1", type: "share" }],
    ["commentAction", { editId: "e1", commentId: "c1", action: "like" }],
  ]) {
    await assert.rejects(
      handlers()[handler]({ data }),
      (error) => error.code === "unauthenticated",
    );
  }
});

test("view and signal validation rejects client-controlled invalid values", async () => {
  await assert.rejects(
    handlers().recordView({
      auth: { uid: "alice" },
      data: { editId: "e1", watchPercent: 200, watchSeconds: 3 },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers().signal({
      auth: { uid: "alice" },
      data: { editId: "e1", type: "invented" },
    }),
    (error) => error.code === "invalid-argument",
  );
});