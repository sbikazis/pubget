"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { ORIGINAL_PATTERN } = require("../src/groupMediaPipeline");

test("media pipeline processes original group and private-chat uploads only", () => {
  assert.deepEqual(
    ORIGINAL_PATTERN.exec("groups/g1/media/m1_original.jpg").slice(1),
    ["groups", "g1", "m1", "jpg"],
  );
  assert.deepEqual(
    ORIGINAL_PATTERN.exec("privateChats/5:alice3:bob/media/m1_original.png")
      .slice(1),
    ["privateChats", "5:alice3:bob", "m1", "png"],
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/media/m1_thumb.jpg"),
    false,
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/chat/m1_original.jpg"),
    false,
  );
  assert.equal(
    ORIGINAL_PATTERN.test("privateChats/c1/media/m1_medium.jpg"),
    false,
  );
});