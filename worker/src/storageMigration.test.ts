import { afterEach, describe, expect, it, vi } from "vitest";
import { handleStorageMigrationRequest, storageMigrationTestHooks as hooks } from "./storageMigration";

const encoder = new TextEncoder();
const sha = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

afterEach(() => vi.unstubAllGlobals());

describe("Firebase Storage migration primitives", () => {
  it("computes streaming SHA-256 across arbitrary chunk boundaries", async () => {
    const hash = new hooks.Sha256();
    hash.update(encoder.encode("a"));
    hash.update(encoder.encode("b"));
    hash.update(encoder.encode("c"));
    expect(hash.finish()).toBe(sha);

    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(encoder.encode("a"));
        controller.enqueue(encoder.encode("bc"));
        controller.close();
      },
    });
    const result = hooks.hashBody(body);
    const copied = await new Response(result.stream).arrayBuffer();
    const digest = await result.result;
    expect(new TextDecoder().decode(copied)).toBe("abc");
    expect(digest).toEqual({ size: 3, sha256: sha });
  });

  it("preserves GCS object names including nested and repeated slash keys", () => {
    expect(hooks.validPath("users/alice/avatar.jpg")).toBe(true);
    expect(hooks.validPath("fan_works/alice//work/file.pdf")).toBe(true);
    expect(hooks.validPath("folder/../literal-object-name")).toBe(true);
    expect(hooks.validPath("")).toBe(false);
  });

  it("never copies Firebase permanent download tokens into R2 metadata", () => {
    expect(hooks.metadataMap({
      owner: "alice",
      firebaseStorageDownloadTokens: "permanent-secret",
      FirebaseStorageDownloadTokens: "another-token",
    })).toEqual({ owner: "alice" });
  });

  it("requires the exact manifest record to be verified before R2 reads", () => {
    expect(hooks.isVerifiedManifestRecord("images/a/a.jpg", {
      sourcePath: "images/a/a.jpg", status: "verified",
      sourceGeneration: "7", destinationSha256: "a".repeat(64),
    })).toBe(true);
    expect(hooks.isVerifiedManifestRecord("images/a/a.jpg", {
      sourcePath: "images/a/a.jpg", status: "copying",
      sourceGeneration: "7", destinationSha256: "a".repeat(64),
    })).toBe(false);
    expect(hooks.isVerifiedManifestRecord("images/a/a.jpg", {
      sourcePath: "images/b/b.jpg", status: "verified",
      sourceGeneration: "7", destinationSha256: "a".repeat(64),
    })).toBe(false);
  });

  it("lists a GCS page without dropping zero-byte or unusual object names", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify({
      items: [
        { name: "avatars/a.jpg", size: "0", generation: "1" },
        { name: "folder//name with spaces", size: "4", generation: "2" },
      ],
      nextPageToken: "next-page",
    }), { status: 200 })));
    const page = await hooks.gcsList("bucket-name", "read-token", null, 1000);
    expect(page.items.map((item: { name: string }) => item.name)).toEqual([
      "avatars/a.jpg", "folder//name with spaces",
    ]);
    expect(page.next).toBe("next-page");
  });

  it("rejects unauthenticated migration administration requests", async () => {
    const response = await handleStorageMigrationRequest(
      new Request("https://worker.test/_admin/storage-migration/status"),
      {
        FIREBASE_PROJECT_ID: "pubget-aaf27",
        FIREBASE_STORAGE_BUCKET: "pubget-aaf27.firebasestorage.app",
      } as never,
    );
    expect(response?.status).toBe(403);
  });

  it("refuses to retry an object after the bounded retry budget", async () => {
    const doc = {
      name: "projects/demo/databases/(default)/documents/storageMigrationManifest/x",
      fields: {
        sourcePath: { stringValue: "fan_works/a/b/c.pdf" },
        sourceGeneration: { stringValue: "9" },
        sizeBytes: { integerValue: "20" },
        attempts: { integerValue: "5" },
        sourceBucket: { stringValue: "bucket" },
      },
    };
    const result = await hooks.copyObject(
      { MEDIA_BUCKET: {} } as never, "https://firestore.test", "fs", "gcs", doc, false,
    );
    expect(result).toMatchObject({ status: "failed", reason: "retry-limit-reached" });
  });

  it("acquires one durable Firestore lease and rejects a concurrent runner", async () => {
    let stored: Record<string, unknown> | null = null;
    let transactionCount = 0;
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url.endsWith(":beginTransaction")) {
        transactionCount++;
        return new Response(JSON.stringify({ transaction: "tx-" + transactionCount }), { status: 200 });
      }
      if (url.includes("storageMigration/control?transaction=")) {
        return stored
          ? new Response(JSON.stringify(stored), { status: 200 })
          : new Response("", { status: 404 });
      }
      if (url.endsWith(":commit")) {
        const payload = JSON.parse(String(init?.body)) as { writes: Array<{ update: { fields: Record<string, unknown> } }> };
        stored = { name: "control", fields: payload.writes[0].update.fields };
        return new Response("{}", { status: 200 });
      }
      if (url.endsWith(":rollback")) return new Response("{}", { status: 200 });
      throw new Error("Unexpected request " + url);
    }));
    const base = "https://firestore.test";
    const first = await hooks.acquireLease(base, "service-token");
    expect(first).toBeTruthy();
    await expect(hooks.acquireLease(base, "service-token")).rejects.toThrow(/lease/i);
  });
});
