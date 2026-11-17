import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env } from "./index.ts";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const SOURCE_KEY = "kirari/test-user/reel-1/source.mp4";
const COVER_KEY = "kirari/test-user/reel-1/cover-source.jpg";
const MP4 = new Uint8Array([0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]);
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 16, 0x4a, 0x46, 0x49, 0x46]);

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function mockBucket() {
  const objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  const puts: string[] = [];
  const aborts: string[] = [];
  const uploads = new Map<string, {
    key: string;
    uploadId: string;
    options: { customMetadata?: Record<string, string> };
    parts: Map<number, Uint8Array>;
  }>();
  let uploadCounter = 0;

  function handleFor(uploadId: string) {
    const upload = uploads.get(uploadId);
    if (!upload) throw new Error(`Unknown mock multipart upload: ${uploadId}`);
    return {
      uploadId,
      async uploadPart(number: number, body: ReadableStream) {
        upload.parts.set(number, new Uint8Array(await new Response(body).arrayBuffer()));
        return { etag: `etag-${number}` };
      },
      async complete(completed: Array<{ partNumber: number }>) {
        const size = completed.reduce((sum, part) => sum + (upload.parts.get(part.partNumber)?.length ?? 0), 0);
        const bytes = new Uint8Array(size);
        let offset = 0;
        for (const part of completed) {
          const chunk = upload.parts.get(part.partNumber) ?? new Uint8Array();
          bytes.set(chunk, offset);
          offset += chunk.length;
        }
        objects.set(upload.key, { bytes, contentType: "video/mp4" });
        uploads.delete(uploadId);
        return { size, customMetadata: upload.options.customMetadata };
      },
      async abort() {
        uploads.delete(uploadId);
        aborts.push(uploadId);
      },
    };
  }

  const bucket = {
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
    async put(key: string, body: ReadableStream, options?: { httpMetadata?: { contentType?: string } }) {
      puts.push(key);
      objects.set(key, {
        bytes: new Uint8Array(await new Response(body).arrayBuffer()),
        contentType: options?.httpMetadata?.contentType ?? "application/octet-stream",
      });
    },
    async delete(key: string) { objects.delete(key); },
    createMultipartUpload(key: string, options: { customMetadata?: Record<string, string> }) {
      uploadCounter++;
      const uploadId = `upload-${uploadCounter}`;
      uploads.set(uploadId, { key, uploadId, options, parts: new Map() });
      return handleFor(uploadId);
    },
    resumeMultipartUpload(_key: string, uploadId: string) {
      return handleFor(uploadId);
    },
  };
  return { bucket, objects, puts, aborts };
}

describe("Kirari R2 multipart routes", () => {
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
    jwk.kid = "kirari-route-key";
  });

  beforeEach(async () => {
    const now = Math.floor(Date.now() / 1000);
    const header = base64Url(JSON.stringify({ alg: "RS256", kid: jwk.kid, typ: "JWT" }));
    const claims = base64Url(JSON.stringify({
      aud: "pubget-aaf27",
      iss: "https://securetoken.google.com/pubget-aaf27",
      sub: "test-user",
      exp: now + 3600,
      iat: now,
      auth_time: now - 30,
    }));
    const input = `${header}.${claims}`;
    const signature = new Uint8Array(await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5", keyPair.privateKey, new TextEncoder().encode(input),
    ));
    token = `${input}.${base64Url(signature)}`;
    vi.stubGlobal("fetch", async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.startsWith("https://www.googleapis.com/service_accounts/")) {
        return new Response(JSON.stringify({ keys: [jwk] }), {
          status: 200,
          headers: { "content-type": "application/json", "cache-control": "public, max-age=300" },
        });
      }
      if (url.includes("/documents/kirari/reel-1")) {
        return new Response(JSON.stringify({ fields: {
          creatorId: { stringValue: "test-user" },
          status: { stringValue: "uploading" },
          originalStoragePath: { stringValue: SOURCE_KEY },
        } }), { status: 200, headers: { "content-type": "application/json" } });
      }
      throw new Error(`Unexpected network call in Kirari route test: ${url}`);
    });
    bucket = mockBucket();
    env = {
      MEDIA_BUCKET: bucket.bucket,
      FIREBASE_PROJECT_ID: "pubget-aaf27",
      MEDIA_SIGNING_SECRET: "22".repeat(32),
      KIRARI_R2_SERVICE_ACCOUNT_EMAIL: "runner@developer.gserviceaccount.com",
      KIRARI_R2_SERVICE_AUDIENCE: ORIGIN,
      FIRESTORE_SERVICE_ACCOUNT_EMAIL: "runner@developer.gserviceaccount.com",
      FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "unused",
    } as unknown as Env;
  });

  afterEach(() => vi.unstubAllGlobals());

  const request = (path: string, init: RequestInit = {}) => new Request(`${ORIGIN}${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${token}`,
      ...(init.headers as Record<string, string> | undefined),
    },
  });

  it("creates, completes and reports a multipart source", async () => {
    const missing = await worker.fetch(request("/kirari/multipart/reel-1", { method: "HEAD" }), env);
    expect(missing.status).toBe(404);

    const create = await worker.fetch(request("/kirari/multipart/reel-1", {
      method: "POST",
      headers: { "content-type": "application/json", "x-kirari-size": String(MP4.length) },
      body: "{}",
    }), env);
    expect(create.status).toBe(201);
    const session = await create.json() as { uploadId: string; key: string };
    expect(session.key).toBe(SOURCE_KEY);

    const part = await worker.fetch(request(`/kirari/multipart/reel-1/${session.uploadId}/1`, {
      method: "PUT",
      headers: { "content-type": "video/mp4", "content-length": String(MP4.length) },
      body: MP4,
    }), env);
    expect(part.status).toBe(201);
    expect((await part.json() as { etag: string }).etag).toBe("etag-1");

    const complete = await worker.fetch(request(`/kirari/multipart/reel-1/${session.uploadId}/complete`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ parts: [{ partNumber: 1, etag: "etag-1" }] }),
    }), env);
    expect(complete.status).toBe(201);
    expect((await complete.json() as { sizeBytes: number }).sizeBytes).toBe(MP4.length);

    const present = await worker.fetch(request("/kirari/multipart/reel-1", { method: "HEAD" }), env);
    expect(present.status).toBe(200);
    expect(present.headers.get("content-length")).toBe(String(MP4.length));
  });

  it("stores a custom cover under the pipeline's expected key", async () => {
    const response = await worker.fetch(request("/kirari/multipart/reel-1/cover", {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(JPEG.length) },
      body: JPEG,
    }), env);
    expect(response.status).toBe(201);
    expect((await response.json() as { key: string }).key).toBe(COVER_KEY);
    expect(bucket.puts).toContain(COVER_KEY);
  });

  it("rejects a cover whose bytes are not a JPEG", async () => {
    const response = await worker.fetch(request("/kirari/multipart/reel-1/cover", {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(MP4.length) },
      body: MP4,
    }), env);
    expect(response.status).toBe(415);
    expect(bucket.puts).toEqual([]);
  });
});
