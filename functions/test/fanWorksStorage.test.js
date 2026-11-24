"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const storageContract = require("../src/fanWorksStorage");

const {
  buildMediaPath,
  maxBytesFor,
  extensionFor,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
} = storageContract;

test("the removed GCS signer is not exported", () => {
  assert.equal(storageContract.createFanWorksSigner, undefined);
});

test("buildMediaPath keeps the uid segment that storage.rules gates on", () => {
  const path = buildMediaPath({
    userId: "u1",
    workId: "w1",
    mediaId: "m1",
    mime: "application/pdf",
    nonce: "abc123",
  });
  assert.equal(path, "fan_works/u1/w1/abc123_m1.pdf");
  assert.ok(path.startsWith("fan_works/u1/"));
  assert.ok(!path.includes(".."));
});

test("buildMediaPath strips path traversal out of every component", () => {
  const path = buildMediaPath({
    userId: "../../etc",
    workId: "../w2",
    mediaId: "../passwd",
    mime: "image/png",
    nonce: "n1",
  });
  assert.equal(path, "fan_works/etc/w2/n1_passwd.png");
  assert.ok(!path.includes(".."));
});

test("buildMediaPath refuses unknown mime and empty components", () => {
  assert.equal(
    buildMediaPath({
      userId: "u",
      workId: "w",
      mediaId: "m",
      mime: "text/html",
      nonce: "n",
    }),
    null,
  );
  assert.equal(
    buildMediaPath({
      userId: "u",
      workId: "",
      mediaId: "m",
      mime: "image/png",
      nonce: "n",
    }),
    null,
  );
});

test("extensionFor only knows the four image types and pdf", () => {
  assert.equal(extensionFor("image/jpeg"), "jpg");
  assert.equal(extensionFor("image/png"), "png");
  assert.equal(extensionFor("image/webp"), "webp");
  assert.equal(extensionFor("image/gif"), "gif");
  assert.equal(extensionFor("application/pdf"), "pdf");
  assert.equal(extensionFor("application/zip"), null);
  assert.equal(extensionFor("text/html"), null);
});

test("pdf ceiling is 50 MB and images are 12 MB", () => {
  assert.equal(maxBytesFor("application/pdf"), DOCUMENT_MAX_BYTES);
  assert.equal(maxBytesFor("image/png"), IMAGE_MAX_BYTES);
  assert.equal(DOCUMENT_MAX_BYTES, 50 * 1024 * 1024);
  assert.equal(IMAGE_MAX_BYTES, 12 * 1024 * 1024);
});
