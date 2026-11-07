"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { webcrypto } = require("node:crypto");
const { authenticateKirariService } = require("../../worker/src/kirariServiceAuth.cjs");

const expected = {
  audience: "https://pubget-media.pubget.workers.dev",
  serviceAccountEmail: "452313838148-compute@developer.gserviceaccount.com",
};
const now = 1_800_000_000;

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

async function signedRequest(overrides = {}, signingKey) {
  const keyPair = signingKey || await webcrypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const publicJwk = await webcrypto.subtle.exportKey("jwk", keyPair.publicKey);
  publicJwk.kid = "test-key";
  const header = encode({ alg: "RS256", kid: "test-key", typ: "JWT" });
  const claims = {
    iss: "https://accounts.google.com",
    aud: expected.audience,
    sub: "12345678901234567890",
    email: expected.serviceAccountEmail,
    email_verified: true,
    iat: now - 10,
    exp: now + 3500,
    ...overrides,
  };
  const payload = encode(claims);
  const signingInput = `${header}.${payload}`;
  const signature = await webcrypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    keyPair.privateKey,
    new TextEncoder().encode(signingInput),
  );
  const token = `${signingInput}.${Buffer.from(signature).toString("base64url")}`;
  const request = new Request("https://pubget-media.pubget.workers.dev/_internal/kirari/sign", {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
  });
  const fetchImpl = async () => new Response(JSON.stringify({ keys: [publicJwk] }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
  return { request, fetchImpl };
}

test("Worker accepts a correctly signed Google token for the configured Firebase runtime identity", async () => {
  const { request, fetchImpl } = await signedRequest();
  assert.equal(await authenticateKirariService(request, expected, fetchImpl, now), true);
});

test("Worker rejects missing bearer credentials without contacting Google", async () => {
  const request = new Request("https://pubget-media.pubget.workers.dev/_internal/kirari/sign");
  let fetched = false;
  assert.equal(await authenticateKirariService(request, expected, async () => {
    fetched = true;
    return new Response("{}", { status: 200 });
  }, now), false);
  assert.equal(fetched, false);
});

test("Worker rejects tokens with the wrong audience, issuer, service account, or trust claims", async (t) => {
  for (const [name, claims] of [
    ["wrong audience", { aud: "https://attacker.example" }],
    ["wrong service account", { email: "other@developer.gserviceaccount.com" }],
    ["unverified service account email", { email_verified: false }],
    ["wrong issuer", { iss: "https://malicious.example" }],
    ["expired token", { exp: now - 1 }],
  ]) {
    await t.test(name, async () => {
      const { request, fetchImpl } = await signedRequest(claims);
      assert.equal(await authenticateKirariService(request, expected, fetchImpl, now), false);
    });
  }
});
