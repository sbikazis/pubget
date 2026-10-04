"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createFanWorksSigner,
  buildMediaPath,
  maxBytesFor,
  extensionFor,
  READ_URL_TTL_MS,
  UPLOAD_SESSION_TTL_MS,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
} = require("../src/fanWorksStorage");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FIXED_NOW = 1_700_000_000_000;

/**
 * A fake bucket that records exactly what the signer asked GCS for. This is
 * what makes the security assertions possible with no credentials: the test
 * checks the options object, not the network.
 */
function fakeBucket({ signedUrl = "https://storage.test/signed" } = {}) {
  const calls = { resumable: [], signed: [] };
  return {
    calls,
    file(path) {
      return {
        path,
        async createResumableUpload(options) {
          calls.resumable.push({ path, options });
          return [`https://storage.test/upload/session/${path}`, { ok: true }];
        },
        async getSignedUrl(options) {
          calls.signed.push({ path, options });
          return [signedUrl];
        },
      };
    },
  };
}

function makeSigner(bucket, now = FIXED_NOW) {
  return createFanWorksSigner({
    bucket,
    HttpsError: TestHttpsError,
    now: () => now,
  });
}

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

test("resumable upload is signed per object and never made public", async () => {
  const bucket = fakeBucket();
  const signer = makeSigner(bucket);
  const ticket = await signer.signResumableUpload({
    userId: "u1",
    workId: "w1",
    mediaId: "m1",
    mime: "application/pdf",
    nonce: "n1",
  });
  assert.ok(ticket.sessionUri.startsWith("https://storage.test/upload/session/"));
  assert.equal(ticket.path, "fan_works/u1/w1/n1_m1.pdf");
  assert.equal(ticket.maxBytes, DOCUMENT_MAX_BYTES);
  assert.equal(ticket.expiresAt, FIXED_NOW + UPLOAD_SESSION_TTL_MS);
  const [call] = bucket.calls.resumable;
  assert.equal(call.options.metadata.contentType, "application/pdf");
  assert.equal(
    call.options.predefinedAcl,
    undefined,
    "a public ACL would expose the pdf to anyone with the url",
  );
});

test("resumable upload rejects a non-pdf, non-image mime", async () => {
  const signer = makeSigner(fakeBucket());
  await assert.rejects(
    signer.signResumableUpload({
      userId: "u",
      workId: "w",
      mediaId: "m",
      mime: "application/zip",
      nonce: "n",
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("read url is v4, read-only, inline, and short lived", async () => {
  const bucket = fakeBucket();
  const signer = makeSigner(bucket);
  const signed = await signer.signReadUrl({
    path: "fan_works/u1/w1/n1_m1.pdf",
  });
  assert.equal(signed.url, "https://storage.test/signed");
  assert.equal(signed.expiresAt, FIXED_NOW + READ_URL_TTL_MS);
  const [call] = bucket.calls.signed;
  assert.equal(call.options.version, "v4");
  assert.equal(call.options.action, "read");
  assert.equal(call.options.responseDisposition, "inline");
  assert.equal(call.options.responseType, "application/pdf");
  assert.equal(
    call.options.expires.getTime(),
    FIXED_NOW + READ_URL_TTL_MS,
    "read urls must expire in minutes, not days",
  );
});

test("a read url can be forced to attachment for an explicit export", async () => {
  const bucket = fakeBucket();
  const signer = makeSigner(bucket);
  await signer.signReadUrl({ path: "fan_works/u1/w1/n1_m1.pdf", inline: false });
  assert.equal(bucket.calls.signed[0].options.responseDisposition, "attachment");
});

test("signing refuses paths outside the fanWorks tree or with traversal", async () => {
  const signer = makeSigner(fakeBucket());
  for (const path of [
    "otherApp/secret.pdf",
    "fan_works/../../etc/passwd",
    "fan_works/u1/w1/../../../../root.pdf",
    "",
  ]) {
    await assert.rejects(
      signer.signReadUrl({ path }),
      (error) => error.code === "permission-denied",
      path,
    );
  }
});

test("a stored path carrying a permanent download token is refused outright", async () => {
  const signer = makeSigner(fakeBucket());
  await assert.rejects(
    signer.signReadUrl({
      path: "fan_works/u1/w1/n1_m1.pdf?token=abc:XYZ",
    }),
    (error) =>
      error.code === "failed-precondition" && /download token/.test(error.message),
  );
});

test("write url is a bounded signed PUT, not a public object", async () => {
  const bucket = fakeBucket();
  const signer = makeSigner(bucket);
  const ticket = await signer.signWriteUrl({
    userId: "u1",
    workId: "w1",
    mediaId: "m1",
    mime: "image/png",
    nonce: "n1",
  });
  assert.equal(ticket.path, "fan_works/u1/w1/n1_m1.png");
  const [call] = bucket.calls.signed;
  assert.equal(call.options.version, "v4");
  assert.equal(call.options.action, "write");
  assert.equal(call.options.contentType, "image/png");
  assert.equal(call.options.extensionHeaders["x-goog-content-length-range"], `1,${IMAGE_MAX_BYTES}`);
  assert.equal(call.options.responseDisposition, undefined);
});

test("the write url refuses pdf, which must go through a resumable session", async () => {
  const signer = makeSigner(fakeBucket());
  await assert.rejects(
    signer.signWriteUrl({
      userId: "u",
      workId: "w",
      mediaId: "m",
      mime: "application/pdf",
      nonce: "n",
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("a malformed storage response surfaces as internal, not a raw crash", async () => {
  const bucket = {
    file: () => ({
      async createResumableUpload() {
        return "not-a-url";
      },
    }),
  };
  const signer = makeSigner(bucket);
  await assert.rejects(
    signer.signResumableUpload({
      userId: "u",
      workId: "w",
      mediaId: "m",
      mime: "image/png",
      nonce: "n",
    }),
    (error) => error.code === "internal",
  );
});

test("the signer resolves a bare-string resumable response too", async () => {
  const bucket = {
    file: () => ({
      async createResumableUpload() {
        return "https://storage.test/upload/session/bare";
      },
    }),
  };
  const signer = makeSigner(bucket);
  const ticket = await signer.signResumableUpload({
    userId: "u",
    workId: "w",
    mediaId: "m",
    mime: "image/png",
    nonce: "n",
  });
  assert.equal(ticket.sessionUri, "https://storage.test/upload/session/bare");
});

test("the signer refuses to be constructed without a bucket", () => {
  assert.throws(
    () => createFanWorksSigner({ HttpsError: TestHttpsError }),
    /requires a bucket/,
  );
});
