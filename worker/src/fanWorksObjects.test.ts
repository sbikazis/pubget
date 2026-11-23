import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env, fanWorksSessionStateKey, isFanWorksKey } from "./index.ts";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const SERVICE_EMAIL = "runner@developer.gserviceaccount.com";
const KEY = "fan_works/alice/work1/abc123_media1.jpg";
const PDF_KEY = "fan_works/alice/work2/def456_doc1.pdf";

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function mockBucket() {
  const objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  const completedWith: Array<Array<{ partNumber: number; etag: string }>> = [];
  const aborted: string[] = [];
  async function put(key: string, body: string | ReadableStream<Uint8Array>, options?: {
    httpMetadata?: { contentType?: string };
  }) {
    const bytes = typeof body === "string"
      ? new TextEncoder().encode(body)
      : new Uint8Array(await new Response(body).arrayBuffer());
    objects.set(key, {
      bytes,
      contentType: options?.httpMetadata?.contentType ?? "application/octet-stream",
    });
  }
  return {
    objects,
    completedWith,
    aborted,
    put,
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
        async json() { return JSON.parse(new TextDecoder().decode(object.bytes)); },
      };
    },
    async delete(key: string) { objects.delete(key); },
    async createMultipartUpload(key: string) {
      return { key, uploadId: "upload-1" };
    },
    resumeMultipartUpload(key: string, uploadId: string) {
      return {
        async uploadPart(partNumber: number, body: ReadableStream<Uint8Array>) {
          await new Response(body).arrayBuffer();
          return { partNumber, etag: `real-etag-${partNumber}` };
        },
        async complete(parts: Array<{ partNumber: number; etag: string }>) {
          completedWith.push(parts);
          await put(key, new Uint8Array([37, 80, 68, 70]), { httpMetadata: { contentType: "application/pdf" } });
          return { key };
        },
        async abort() { aborted.push(uploadId); },
      };
    },
  };
}

describe("isFanWorksKey", () => {
  it("accepts the existing buildMediaPath shape for images and PDFs", () => {
    expect(isFanWorksKey(KEY)).toBe(true);
    expect(isFanWorksKey(PDF_KEY)).toBe(true);
  });

  it("rejects traversal, wrong folders and foreign shapes", () => {
    expect(isFanWorksKey("images/alice/a.jpg")).toBe(false);
    expect(isFanWorksKey("fan_works/alice/a.jpg")).toBe(false);
    expect(isFanWorksKey("fan_works/alice/work1/../a.jpg")).toBe(false);
    expect(isFanWorksKey("fan_works/alice/work1/a.exe")).toBe(false);
  });
});

describe("Fan Works R2 bridge", () => {
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
    jwk.kid = "fanworks-route-key";
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
      throw new Error(`Unexpected network call in fan works test: ${url}`);
    });
    bucket = mockBucket();
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

  async function sign(op: string, extra: Record<string, unknown> = {}, auth = true) {
    return worker.fetch(request("/_internal/fanworks/sign", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ op, ...extra }),
    }, auth), env);
  }

  it("requires the Functions service identity for signing", async () => {
    expect((await sign("read", { key: KEY }, false)).status).toBe(401);
  });

  it("rejects keys outside the Fan Works namespace", async () => {
    expect((await sign("read", { key: "images/alice/a.jpg" })).status).toBe(400);
  });

  it("mints a one-shot image upload URL", async () => {
    const response = await sign("upload", {
      key: KEY, contentType: "image/jpeg", size: 12 * 1024 * 1024,
    });
    expect(response.status).toBe(200);
    const body = (await response.json()) as { uploadUrl: string };
    expect(body.uploadUrl).toContain("/fanworks/upload/");
    expect(body.uploadUrl).toContain("signature=");
  });

  it("mints a resumable PDF session", async () => {
    const response = await sign("upload", {
      key: PDF_KEY, contentType: "application/pdf", size: 50 * 1024 * 1024,
    });
    expect(response.status).toBe(200);
    const body = (await response.json()) as { sessionUrl: string };
    expect(body.sessionUrl).toContain("/fanworks/session/");
    expect(body.sessionUrl).toContain("uploadId=");
  });

  it("resumes a PDF session and completes it with the real part ETags", async () => {
    const signed = await sign("upload", {
      key: PDF_KEY, contentType: "application/pdf", size: 50 * 1024 * 1024,
    });
    const { sessionUrl } = (await signed.json()) as { sessionUrl: string };
    const stateKey = fanWorksSessionStateKey("upload-1");
    expect(bucket.objects.has(stateKey)).toBe(true);

    const total = 8 * 1024 * 1024 + 2;
    const chunk = (range: string, bytes: Uint8Array) => worker.fetch(
      new Request(sessionUrl, {
        method: "PUT",
        headers: { "content-range": range, "content-length": String(bytes.length) },
        body: bytes,
      }),
      env,
    );

    const first = await chunk(`bytes=0-1/${total}`, new Uint8Array([37, 80]));
    expect(first.status).toBe(308);
    expect(first.headers.get("range")).toBe("bytes=0-1");

    const last = await chunk(
      `bytes=${8 * 1024 * 1024}-${total - 1}/${total}`,
      new Uint8Array([68, 70]),
    );
    expect(last.status).toBe(201);
    expect(bucket.completedWith).toEqual([[
      { partNumber: 1, etag: "real-etag-1" },
      { partNumber: 2, etag: "real-etag-2" },
    ]]);
    expect(bucket.objects.has(stateKey)).toBe(false);
  });

  it("refuses a PDF chunk whose session signature is tampered with", async () => {
    const signed = await sign("upload", {
      key: PDF_KEY, contentType: "application/pdf", size: 50 * 1024 * 1024,
    });
    const { sessionUrl } = (await signed.json()) as { sessionUrl: string };
    const tampered = sessionUrl.replace(
      /signature=([0-9a-f]+)$/,
      (_match, signature: string) =>
        `signature=${signature[0] === "a" ? "b" : "a"}${signature.slice(1)}`,
    );
    expect(tampered).not.toBe(sessionUrl);
    const response = await worker.fetch(new Request(tampered, {
      method: "PUT",
      headers: { "content-range": "bytes=0-1/2", "content-length": "2" },
      body: new Uint8Array([37, 80]),
    }), env);
    expect(response.status).toBe(403);
  });

  it("serves a signed read with inline disposition and nosniff", async () => {
    bucket.objects.set(PDF_KEY, {
      bytes: new Uint8Array([37, 80, 68, 70]),
      contentType: "application/pdf",
    });
    const signed = await sign("read", { key: PDF_KEY, disposition: "inline" });
    const { url } = (await signed.json()) as { url: string };
    const response = await worker.fetch(new Request(url), env);
    expect(response.status).toBe(200);
    expect(response.headers.get("content-disposition")).toContain("inline");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  });
});
