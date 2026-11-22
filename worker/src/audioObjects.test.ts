import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env } from "./index.ts";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const SERVICE_EMAIL = "runner@developer.gserviceaccount.com";
const SOURCE_KEY = "edits/alice/edit_1.mp4";
const AUDIO_KEY = "reelAudios/alice/audio_1.m4a";
const MP4 = new Uint8Array([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]);

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

describe("audio internal object bridge", () => {
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
    jwk.kid = "audio-route-key";
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
      throw new Error(`Unexpected network call in audio object test: ${url}`);
    });
    bucket = mockBucket();
    bucket.objects.set(SOURCE_KEY, { bytes: MP4, contentType: "video/mp4" });
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
    const response = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(SOURCE_KEY)}`, {}, false);
    expect(response.status).toBe(401);
  });

  it("reads an Edit source through the authenticated bridge", async () => {
    const head = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(SOURCE_KEY)}`, { method: "HEAD" });
    expect(head.status).toBe(200);
    expect(head.headers.get("content-length")).toBe(String(MP4.length));
    const get = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(SOURCE_KEY)}`);
    expect(get.status).toBe(200);
    expect(new Uint8Array(await get.arrayBuffer())).toEqual(MP4);
  });

  it("writes only reelAudios objects with audio metadata", async () => {
    const audio = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(AUDIO_KEY)}`, {
      method: "PUT",
      headers: { "content-type": "audio/mp4", "content-length": String(MP4.length) },
      body: MP4,
    });
    expect(audio.status).toBe(201);
    expect(bucket.puts).toEqual([{
      key: AUDIO_KEY,
      metadata: {
        uploadedBy: "alice",
        mediaKind: "audio",
        pipeline: "audio-extractor-v1",
      },
    }]);

    const overwrite = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(SOURCE_KEY)}`, {
      method: "PUT",
      headers: { "content-type": "video/mp4", "content-length": String(MP4.length) },
      body: MP4,
    });
    expect(overwrite.status).toBe(403);
    expect(bucket.puts.length).toBe(1);
  });

  it("allows deleting extracted audio but never Edit sources", async () => {
    const audioDelete = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(AUDIO_KEY)}`, {
      method: "DELETE",
    });
    expect(audioDelete.status).toBe(204);
    const sourceDelete = await fetchRoute(`/_internal/audio/objects/${encodeURIComponent(SOURCE_KEY)}`, {
      method: "DELETE",
    });
    expect(sourceDelete.status).toBe(403);
    expect(bucket.deletes).toEqual([AUDIO_KEY]);
  });

  it("rejects keys outside the audio namespaces", async () => {
    const response = await fetchRoute("/_internal/audio/objects/images%2Falice%2F2b1c.jpg");
    expect(response.status).toBe(400);
  });
});
