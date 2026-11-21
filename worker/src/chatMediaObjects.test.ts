import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env } from "./index.ts";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const SERVICE_EMAIL = "runner@developer.gserviceaccount.com";
const ORIGINAL_KEY = "groups/g1/alice/2b1c.jpg";
const THUMB_KEY = "groups/g1/alice/2b1c_thumb.jpg";
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 16, 0x4a, 0x46, 0x49, 0x46]);

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function mockBucket() {
  const objects = new Map<string, {
    bytes: Uint8Array;
    contentType: string;
    metadata?: Record<string, string>;
  }>();
  const puts: Array<{ key: string; metadata?: Record<string, string> }> = [];
  const deletes: string[] = [];
  return {
    objects,
    puts,
    deletes,
    async head(key: string) {
      const object = objects.get(key);
      return object
        ? { size: object.bytes.length, httpMetadata: { contentType: object.contentType } }
        : null;
    },
    async get(key: string) {
      const object = objects.get(key);
      if (!object) return null;
      return {
        size: object.bytes.length,
        body: new ReadableStream<Uint8Array>({
          start(controller) { controller.enqueue(object.bytes); controller.close(); },
        }),
        writeHttpMetadata() {},
      };
    },
    async put(
      key: string,
      body: ReadableStream,
      options?: { httpMetadata?: { contentType?: string }; customMetadata?: Record<string, string> },
    ) {
      puts.push({ key, metadata: options?.customMetadata });
      objects.set(key, {
        bytes: new Uint8Array(await new Response(body).arrayBuffer()),
        contentType: options?.httpMetadata?.contentType ?? "application/octet-stream",
        metadata: options?.customMetadata,
      });
    },
    async delete(key: string) {
      deletes.push(key);
      objects.delete(key);
    },
  };
}

describe("chat media internal object bridge", () => {
  let token: string;
  let keyPair: CryptoKeyPair;
  let jwk: JsonWebKey & { kid?: string };
  let bucket: ReturnType<typeof mockBucket>;
  let env: Env;

  beforeAll(async () => {
    keyPair = await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
      true,
      ["sign", "verify"],
    );
    jwk = await crypto.subtle.exportKey("jwk", keyPair.publicKey) as JsonWebKey & { kid?: string };
    jwk.kid = "chat-route-key";
  });

  beforeEach(async () => {
    const now = Math.floor(Date.now() / 1000);
    const header = base64Url(JSON.stringify({ alg: "RS256", kid: jwk.kid, typ: "JWT" }));
    const claims = base64Url(JSON.stringify({
      iss: "https://accounts.google.com",
      aud: ORIGIN,
      email: SERVICE_EMAIL,
      email_verified: true,
      sub: "1234567890",
      iat: now - 30,
      exp: now + 1800,
    }));
    const input = `${header}.${claims}`;
    const signature = new Uint8Array(await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5", keyPair.privateKey, new TextEncoder().encode(input),
    ));
    token = `${input}.${base64Url(signature)}`;
    vi.stubGlobal("fetch", async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url === "https://www.googleapis.com/oauth2/v3/certs") {
        return new Response(JSON.stringify({ keys: [jwk] }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      throw new Error(`Unexpected network call in chat object test: ${url}`);
    });
    bucket = mockBucket();
    bucket.objects.set(ORIGINAL_KEY, { bytes: JPEG, contentType: "image/jpeg" });
    env = {
      MEDIA_BUCKET: bucket as unknown as Env["MEDIA_BUCKET"],
      KIRARI_R2_SERVICE_ACCOUNT_EMAIL: SERVICE_EMAIL,
      KIRARI_R2_SERVICE_AUDIENCE: ORIGIN,
      MEDIA_SIGNING_SECRET: "22".repeat(32),
    } as unknown as Env;
  });

  afterEach(() => vi.unstubAllGlobals());

  const request = (path: string, init: RequestInit = {}, auth = true) => new Request(`${ORIGIN}${path}`, {
    ...init,
    headers: {
      ...(auth ? { authorization: `Bearer ${token}` } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });

  async function fetchRoute(path: string, init: RequestInit = {}, auth = true) {
    return worker.fetch(request(path, init, auth), env);
  }

  it("rejects callers without the Functions service identity", async () => {
    const response = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(ORIGINAL_KEY)}`, {}, false);
    expect(response.status).toBe(401);
  });

  it("reads an original through the authenticated bridge", async () => {
    const head = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(ORIGINAL_KEY)}`, { method: "HEAD" });
    expect(head.status).toBe(200);
    expect(head.headers.get("content-length")).toBe(String(JPEG.length));
    const get = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(ORIGINAL_KEY)}`);
    expect(get.status).toBe(200);
    expect(new Uint8Array(await get.arrayBuffer())).toEqual(JPEG);
  });

  it("writes only derived JPEGs and inherits the original's conversation scope", async () => {
    const derivative = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(THUMB_KEY)}`, {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(JPEG.length) },
      body: JPEG,
    });
    expect(derivative.status).toBe(201);
    expect(bucket.puts).toEqual([{
      key: THUMB_KEY,
      metadata: {
        uploadedBy: "alice",
        scopeType: "groups",
        scopeId: "g1",
        mediaKind: "image",
        pipeline: "chat-derivatives-v1",
      },
    }]);

    const overwrite = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(ORIGINAL_KEY)}`, {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(JPEG.length) },
      body: JPEG,
    });
    expect(overwrite.status).toBe(403);
    expect(bucket.puts.length).toBe(1);
  });

  it("allows deleting derivatives but never client-owned originals", async () => {
    const derivativeDelete = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(THUMB_KEY)}`, {
      method: "DELETE",
    });
    expect(derivativeDelete.status).toBe(204);
    const originalDelete = await fetchRoute(`/_internal/chat/objects/${encodeURIComponent(ORIGINAL_KEY)}`, {
      method: "DELETE",
    });
    expect(originalDelete.status).toBe(403);
    expect(bucket.deletes).toEqual([THUMB_KEY]);
  });

  it("rejects keys outside the scoped chat namespace", async () => {
    const response = await fetchRoute("/_internal/chat/objects/images%2Falice%2F2b1c.jpg");
    expect(response.status).toBe(400);
  });
});
