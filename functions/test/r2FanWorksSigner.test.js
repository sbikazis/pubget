"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createR2FanWorksSigner } = require("../src/r2FanWorksSigner");

function fakeFetch(handler) {
  return async (url, options) => handler(String(url), options);
}

function bearer() {
  return "header.payload.signature";
}

test("signResumableUpload asks the Worker for a PDF session", async () => {
  const seen = [];
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev/",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch((url, options) => {
      seen.push({ url, body: JSON.parse(options.body) });
      return Promise.resolve({
        ok: true,
        status: 200,
        json: async () => ({
          sessionUrl: "https://media.example.workers.dev/fanworks/session/k?x=1",
          expiresAt: 123456,
        }),
      });
    }),
  });

  const ticket = await signer.signResumableUpload({
    userId: "alice",
    workId: "work1",
    mediaId: "media1",
    mime: "application/pdf",
    nonce: "abc123",
  });

  assert.equal(seen.length, 1);
  assert.equal(seen[0].url, "https://media.example.workers.dev/_internal/fanworks/sign");
  assert.equal(seen[0].body.op, "upload");
  assert.match(seen[0].body.key, /^fan_works\/alice\/work1\/abc123_media1\.pdf$/);
  assert.equal(ticket.sessionUri, "https://media.example.workers.dev/fanworks/session/k?x=1");
  assert.equal(ticket.mime, "application/pdf");
  assert.equal(ticket.maxBytes, 50 * 1024 * 1024);
  assert.equal(ticket.expiresAt, 123456);
});

test("signWriteUrl returns the one-shot image URL and exact ticket shape", async () => {
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch(() => Promise.resolve({
      ok: true,
      status: 200,
      json: async () => ({
        uploadUrl: "https://media.example.workers.dev/fanworks/upload/k",
        expiresAt: 777,
      }),
    })),
  });

  const ticket = await signer.signWriteUrl({
    userId: "alice",
    workId: "work1",
    mediaId: "media2",
    mime: "image/jpeg",
    nonce: "def456",
  });
  assert.equal(ticket.url, "https://media.example.workers.dev/fanworks/upload/k");
  assert.match(ticket.path, /^fan_works\/alice\/work1\/def456_media2\.jpg$/);
  assert.equal(ticket.maxBytes, 12 * 1024 * 1024);
  assert.equal(ticket.expiresAt, 777);
});

test("signReadUrl passes inline disposition and exposes the reader URL", async () => {
  let body;
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch((_url, options) => {
      body = JSON.parse(options.body);
      return Promise.resolve({
        ok: true,
        status: 200,
        json: async () => ({
          url: "https://media.example.workers.dev/fanworks/read/k",
          expiresAt: 999,
        }),
      });
    }),
  });

  const result = await signer.signReadUrl({
    path: "fan_works/alice/work1/abc123_media1.pdf",
    inline: true,
  });
  assert.equal(body.op, "read");
  assert.equal(body.disposition, "inline");
  assert.equal(result.url, "https://media.example.workers.dev/fanworks/read/k");
  assert.equal(result.expiresAt, 999);
});

test("metadata reads size and MIME from the internal HEAD bridge", async () => {
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch(() => Promise.resolve({
      ok: true,
      status: 200,
      json: async () => ({ size: 2048, contentType: "application/pdf" }),
    })),
  });
  const meta = await signer.metadata("fan_works/alice/work1/abc123_media1.pdf");
  assert.deepEqual(meta, { contentType: "application/pdf", size: 2048 });
});

test("metadata fails closed when the object is missing", async () => {
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch(() => Promise.resolve({ ok: false, status: 404 })),
  });
  assert.equal(await signer.metadata("fan_works/alice/work1/x_media.pdf"), null);
});

test("rejects paths outside the Fan Works namespace", async () => {
  const signer = createR2FanWorksSigner({
    workerUrl: "https://media.example.workers.dev",
    tokenProvider: async () => bearer(),
    fetchImpl: fakeFetch(() => {
      throw new Error("must not call the Worker");
    }),
  });
  await assert.rejects(
    () => signer.signReadUrl({ path: "../images/alice/a.jpg" }),
    /Invalid Fan Works read path/,
  );
});
