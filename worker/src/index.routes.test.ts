import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env } from "./index.ts";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function request(path: string, init: RequestInit = {}, token?: string): Request {
  return new Request(`${ORIGIN}${path}`, {
    ...init,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });
}

type StoredObject = {
  bytes: Uint8Array;
  contentType: string;
  customMetadata?: Record<string, string>;
};

function mockBucket() {
  const objects = new Map<string, StoredObject>();
  const puts: string[] = [];
  const deletes: string[] = [];
  const bucket = {
    async put(key: string, body: ReadableStream, options?: {
      httpMetadata?: { contentType?: string };
      customMetadata?: Record<string, string>;
    }) {
      const bytes = new Uint8Array(await new Response(body).arrayBuffer());
      objects.set(key, {
        bytes,
        contentType: options?.httpMetadata?.contentType ?? "application/octet-stream",
        customMetadata: options?.customMetadata,
      });
      puts.push(key);
    },
    async head(key: string) {
      const object = objects.get(key);
      return object
        ? { size: object.bytes.length, customMetadata: object.customMetadata, httpEtag: "test-etag" }
        : null;
    },
    async get(key: string, options?: { range?: { offset: number; length: number } }) {
      const object = objects.get(key);
      if (!object) return null;
      const range = options?.range;
      const bytes = range
        ? object.bytes.slice(range.offset, range.offset + range.length)
        : object.bytes;
      return {
        size: bytes.length,
        httpEtag: "test-etag",
        body: new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(bytes);
            controller.close();
          },
        }),
        writeHttpMetadata(headers: Headers) {
          headers.set("content-type", object.contentType);
        },
      };
    },
    async delete(key: string) {
      objects.delete(key);
      deletes.push(key);
    },
  };
  return { bucket, objects, puts, deletes };
}

function makeEnv(bucket: ReturnType<typeof mockBucket>["bucket"]): Env {
  return {
    MEDIA_BUCKET: bucket,
    FIREBASE_PROJECT_ID: "pubget-aaf27",
    MEDIA_SIGNING_SECRET: "11".repeat(32),
    KIRARI_R2_SERVICE_ACCOUNT_EMAIL: "runner@developer.gserviceaccount.com",
    KIRARI_R2_SERVICE_AUDIENCE: ORIGIN,
    FIRESTORE_SERVICE_ACCOUNT_EMAIL: "runner@developer.gserviceaccount.com",
    FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "unused",
  } as unknown as Env;
}

/// A full in-process R2 lifecycle test: the only external effects are the
/// Firebase JWKS lookup and Firestore REST authorisation, both stubbed here.
/// This guards the signed-URL contract without needing Cloudflare credentials.
describe("shared R2 media route lifecycle", () => {
  let token: string;
  let bucket: ReturnType<typeof mockBucket>;
  let env: Env;
  let keyPair: CryptoKeyPair;
  let jwk: JsonWebKey & { kid?: string };

  // firebaseAuth caches JWKS for five minutes. One key for the whole suite
  // keeps subsequent tests from being rejected by the cached signing key.
  beforeAll(async () => {
    keyPair = await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
      true,
      ["sign", "verify"],
    );
    jwk = await crypto.subtle.exportKey("jwk", keyPair.publicKey) as JsonWebKey & { kid?: string };
    jwk.kid = "route-test-key";
  });

  beforeEach(async () => {
    const now = Math.floor(Date.now() / 1000);
    const sign = async (uid: string) => {
      const header = base64Url(JSON.stringify({ alg: "RS256", kid: jwk.kid, typ: "JWT" }));
      const claims = base64Url(JSON.stringify({
        aud: "pubget-aaf27",
        iss: "https://securetoken.google.com/pubget-aaf27",
        sub: uid,
        exp: now + 3600,
        iat: now,
        auth_time: now - 30,
      }));
      const input = `${header}.${claims}`;
      const signature = new Uint8Array(await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5", keyPair.privateKey, new TextEncoder().encode(input),
      ));
      return `${input}.${base64Url(signature)}`;
    };
    token = await sign("test-user");
    vi.stubGlobal("fetch", async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith("https://www.googleapis.com/service_accounts/")) {
        return new Response(JSON.stringify({ keys: [jwk] }), {
          status: 200,
          headers: { "content-type": "application/json", "cache-control": "public, max-age=300" },
        });
      }
      // A caller other than the object owner gets no published-asset proof.
      if (url.includes("firestore.googleapis.com")) return new Response("{}", { status: 404 });
      throw new Error(`Unexpected network call in R2 route test: ${url}`);
    });
    bucket = mockBucket();
    env = makeEnv(bucket.bucket);
  });

  afterEach(() => vi.unstubAllGlobals());

  it("refuses to issue an upload URL without Firebase authentication", async () => {
    const response = await worker.fetch(
      request("/presign?kind=image&contentType=image/png&ext=png&sizeBytes=8"),
      env,
    );
    expect(response.status).toBe(401);
    expect(bucket.puts).toEqual([]);
  });

  it("presigns, uploads, resolves, seeks and deletes a private object", async () => {
    const presign = await worker.fetch(
      request("/presign?kind=image&contentType=image/png&ext=png&sizeBytes=8", {}, token),
      env,
    );
    expect(presign.status).toBe(200);
    const signed = await presign.json() as { uploadUrl: string; key: string };
    expect(signed.key).toMatch(/^images\/test-user\/[A-Za-z0-9_-]{36}\.png$/);
    expect(signed.uploadUrl).toContain("signature=");

    const uploaded = await worker.fetch(new Request(signed.uploadUrl, {
      method: "PUT",
      body: PNG,
      headers: { "content-type": "image/png", "content-length": "8" },
    }), env);
    expect(uploaded.status).toBe(201);
    expect(bucket.puts).toEqual([signed.key]);

    const resolved = await worker.fetch(
      request(`/resolve?key=${encodeURIComponent(signed.key)}`, {}, token), env,
    );
    expect(resolved.status).toBe(200);
    const link = await resolved.json() as { url: string; expiresAt: number };
    expect(link.url).toContain("/media/");
    expect(link.expiresAt).toBeGreaterThan(Math.floor(Date.now() / 1000));

    const tampered = new URL(link.url);
    tampered.searchParams.set("signature", "0".repeat(64));
    expect((await worker.fetch(request(tampered.href.slice(ORIGIN.length)), env)).status).toBe(403);

    const seek = await worker.fetch(request(link.url.slice(ORIGIN.length), {
      headers: { range: "bytes=0-3" },
    }), env);
    expect(seek.status).toBe(206);
    expect(seek.headers.get("content-range")).toBe("bytes 0-3/8");
    expect(new Uint8Array(await seek.arrayBuffer())).toEqual(PNG.slice(0, 4));

    // Playback URLs are bearer credentials: an unsigned link is rejected even
    // though no Firebase header is required on the media GET itself.
    expect((await worker.fetch(request(`/media/${encodeURIComponent(signed.key)}`), env)).status)
      .toBe(403);

    const deleted = await worker.fetch(
      request(`/media/${encodeURIComponent(signed.key)}`, { method: "DELETE" }, token), env,
    );
    expect(deleted.status).toBe(204);
    expect(bucket.deletes).toEqual([signed.key]);
    // Deletion is idempotent: a second call must not produce a second delete.
    expect((await worker.fetch(
      request(`/media/${encodeURIComponent(signed.key)}`, { method: "DELETE" }, token), env,
    )).status).toBe(204);
    expect(bucket.deletes).toEqual([signed.key]);
  });

  it("rejects bytes that do not match the declared media signature", async () => {
    const presign = await worker.fetch(
      request("/presign?kind=image&contentType=image/png&ext=png&sizeBytes=8", {}, token),
      env,
    );
    const signed = await presign.json() as { uploadUrl: string };
    const uploaded = await worker.fetch(new Request(signed.uploadUrl, {
      method: "PUT",
      body: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]),
      headers: { "content-type": "image/png", "content-length": "8" },
    }), env);
    expect(uploaded.status).toBe(415);
    expect(bucket.puts).toEqual([]);
  });
});
