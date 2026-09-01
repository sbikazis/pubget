"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { ORIGINAL_PATTERN } = require("../src/groupMediaPipeline");

test("media pipeline processes original group uploads only", () => {
  assert.deepEqual(
    ORIGINAL_PATTERN.exec("groups/g1/media/m1_original.jpg").slice(1),
    ["g1", "m1", "jpg"],
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/media/m1_thumb.jpg"),
    false,
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/chat/m1_original.jpg"),
    false,
  );
});