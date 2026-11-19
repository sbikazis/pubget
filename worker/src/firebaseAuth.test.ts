import { describe, expect, it } from "vitest";
import {
  FIREBASE_SIGNING_KEYS_URL,
  GOOGLE_OAUTH_TOKEN_URL,
  getGoogleAccessToken,
  verifyFirebaseIdToken,
} from "./firebaseAuth";

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function makeSignedFirebaseToken(overrides: Record<string, unknown> = {}) {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const publicJwk = await crypto.subtle.exportKey("jwk", pair.publicKey) as JsonWebKey & { kid?: string };
  publicJwk.kid = "test-key";
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", kid: "test-key" })));
  const claims = base64Url(new TextEncoder().encode(JSON.stringify({
    aud: "pubget-aaf27",
    iss: "https://securetoken.google.com/pubget-aaf27",
    sub: "test-user",
    exp: now + 3600,
    iat: now,
    auth_time: now - 30,
    ...overrides,
  })));
  const unsigned = header + "." + claims;
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", pair.privateKey, new TextEncoder().encode(unsigned),
  ));
  return {
    token: unsigned + "." + base64Url(signature),
    fetcher: async (input: RequestInfo | URL) => {
      expect(String(input)).toBe(FIREBASE_SIGNING_KEYS_URL);
      return new Response(JSON.stringify({ keys: [publicJwk] }), {
        status: 200,
        headers: { "cache-control": "public, max-age=300", "content-type": "application/json" },
      });
    },
  };
}

describe("Firebase ID token verification", () => {
  it("verifies signature, project claims and user identity", async () => {
    const { token, fetcher } = await makeSignedFirebaseToken();
    const result = await verifyFirebaseIdToken(token, "pubget-aaf27", fetcher as typeof fetch);
    expect(result?.uid).toBe("test-user");
  });

  it("rejects wrong audience, empty subject and future issue/auth times", async () => {
    for (const claims of [
      { aud: "another-project" },
      { sub: "" },
      { iat: Math.floor(Date.now() / 1000) + 120 },
      { auth_time: Math.floor(Date.now() / 1000) + 120 },
    ]) {
      const { token, fetcher } = await makeSignedFirebaseToken(claims);
      expect(await verifyFirebaseIdToken(token, "pubget-aaf27", fetcher as typeof fetch)).toBeNull();
    }
  });

  it("can enforce recent authentication for sensitive operations", async () => {
    const { token, fetcher } = await makeSignedFirebaseToken({
      auth_time: Math.floor(Date.now() / 1000) - 7200,
    });
    expect(await verifyFirebaseIdToken(token, "pubget-aaf27", fetcher as typeof fetch, undefined, 300)).toBeNull();
  });

  it("rejects tampered signatures", async () => {
    const { token, fetcher } = await makeSignedFirebaseToken();
    const parts = token.split(".");
    parts[1] = base64Url(new TextEncoder().encode(JSON.stringify({
      aud: "pubget-aaf27",
      iss: "https://securetoken.google.com/pubget-aaf27",
      sub: "attacker",
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      auth_time: Math.floor(Date.now() / 1000),
    })));
    expect(await verifyFirebaseIdToken(parts.join("."), "pubget-aaf27", fetcher as typeof fetch)).toBeNull();
  });
});

describe("Google service-account OAuth", () => {
  it("exchanges a signed assertion for a cached least-scope access token", async () => {
    const pair = await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
      true,
      ["sign", "verify"],
    );
    const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
    let binary = "";
    for (const byte of der) binary += String.fromCharCode(byte);
    const pem = ["-----BEGIN " + "PRIVATE KEY-----", btoa(binary).match(/.{1,64}/g)!.join("\n"), "-----END " + "PRIVATE KEY-----"].join("\n");
    let calls = 0;
    const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
      calls++;
      expect(String(input)).toBe(GOOGLE_OAUTH_TOKEN_URL);
      const form = new URLSearchParams(String(init?.body));
      expect(form.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
      return new Response(JSON.stringify({ access_token: "test-access-token", expires_in: 3600, token_type: "Bearer" }), { status: 200 });
    };
    const scopes = ["https://www.googleapis.com/auth/datastore"];
    const first = await getGoogleAccessToken("worker-test@example.iam.gserviceaccount.com", pem, scopes, fetcher as typeof fetch);
    const second = await getGoogleAccessToken("worker-test@example.iam.gserviceaccount.com", pem, scopes, fetcher as typeof fetch);
    expect(first).toBe("test-access-token");
    expect(second).toBe(first);
    expect(calls).toBe(1);
    const fcmToken = await getGoogleAccessToken(
      "worker-test@example.iam.gserviceaccount.com",
      pem,
      ["https://www.googleapis.com/auth/firebase.messaging"],
      fetcher as typeof fetch,
    );
    expect(fcmToken).toBe("test-access-token");
    expect(calls).toBe(2);
  });

  it("rejects broader unapproved OAuth scopes", async () => {
    await expect(getGoogleAccessToken(
      "worker-test-2@example.iam.gserviceaccount.com",
      "not-used",
      ["https://www.googleapis.com/auth/cloud-platform"],
    )).rejects.toThrow("Invalid service account OAuth configuration.");
  });
});
