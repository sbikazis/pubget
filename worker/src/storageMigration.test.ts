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

  it("hashes multi-block streams consistently with WebCrypto", async () => {
    const bytes = Uint8Array.from({length:4097}, (_, index) => index % 251);
    const expected = Array.from(
      new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
      value => value.toString(16).padStart(2, "0"),
    ).join("");
    const hash = new hooks.Sha256();
    for (let offset = 0; offset < bytes.length; offset += 37) {
      hash.update(bytes.subarray(offset, Math.min(offset + 37, bytes.length)));
    }
    expect(hash.finish()).toBe(expected);
  });

  it("preserves GCS object names including nested and repeated slash keys", () => {
    expect(hooks.validPath("users/alice/avatar.jpg")).toBe(true);
    expect(hooks.validPath("fan_works/alice//work/file.pdf")).toBe(true);
    expect(hooks.validPath("folder/../literal-object-name")).toBe(true);
    expect(hooks.validPath("")).toBe(false);
  });

  it("bounds R2 custom metadata and infers uploader only from supported legacy key shapes", () => {
    const metadata = hooks.r2CustomMetadata(
      "groups/group-1/alice/clip.mp4",
      { firebaseStorageDownloadTokens: "secret", note: "x".repeat(1800) },
      "generation-1",
      "legacy-bucket",
    );
    expect(metadata.uploadedBy).toBe("alice");
    expect(metadata.migrationSourceGeneration).toBe("generation-1");
    expect(metadata.firebaseStorageDownloadTokens).toBeUndefined();
    expect(Object.entries(metadata).reduce((n,[k,v])=>n+k.length+v.length,0)).toBeLessThanOrEqual(1500);
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


describe("verified GCS to R2 copy lifecycle", () => {
  function setup(corruptDestination = false) {
    const sourceBytes = encoder.encode("legacy-media");
    let destinationBytes: Uint8Array | null = null;
    let destinationMetadata: Record<string,string> = {};
    let manifestFields: Record<string,unknown> = {
      sourcePath: {stringValue:"fan_works/alice/work/cover.jpg"},
      sourceBucket: {stringValue:"pubget-aaf27.firebasestorage.app"},
      sourceGeneration: {stringValue:"77"},
      sourceMetageneration: {stringValue:"3"},
      sizeBytes: {integerValue:String(sourceBytes.length)},
      contentType: {stringValue:"image/jpeg"},
      sourceMetadata: {mapValue:{fields:{uploadedBy:{stringValue:"alice"}}}},
      contentMetadata: {mapValue:{fields:{contentType:{stringValue:"image/jpeg"},cacheControl:{stringValue:"private"}}}},
      status: {stringValue:"pending"},
      attempts: {integerValue:"0"},
    };
    const bucket = {
      async head() {
        return destinationBytes ? {
          size: destinationBytes.length,
          customMetadata: destinationMetadata,
        } : null;
      },
      async put(_key:string, stream:ReadableStream<Uint8Array>, options: {customMetadata:Record<string,string>}) {
        destinationBytes = new Uint8Array(await new Response(stream).arrayBuffer());
        destinationMetadata = options.customMetadata;
      },
      async get() {
        if (!destinationBytes) return null;
        const bytes = corruptDestination
          ? Uint8Array.from(destinationBytes, (value,index) => index === 0 ? value ^ 1 : value)
          : destinationBytes;
        return { body: new Response(bytes).body };
      },
      async delete() { destinationBytes = null; },
    };
    const requests: string[] = [];
    vi.stubGlobal("fetch", vi.fn(async (input:RequestInfo|URL, init?:RequestInit) => {
      const url = new URL(String(input));
      requests.push(url.href);
      if (url.hostname === "storage.googleapis.com") {
        if (url.searchParams.get("alt") === "media") {
          return new Response(sourceBytes, {status:200});
        }
        return new Response(JSON.stringify({
          name: "fan_works/alice/work/cover.jpg",
          size: String(sourceBytes.length),
          generation: "77",
          metageneration: "3",
          contentType: "image/jpeg",
        }), {status:200});
      }
      if (url.hostname === "firestore.googleapis.com" && init?.method === "PATCH") {
        const payload = JSON.parse(String(init.body)) as {fields:Record<string,unknown>};
        manifestFields = payload.fields;
        return new Response("{}",{status:200});
      }
      if (url.hostname === "firestore.googleapis.com") {
        return new Response(JSON.stringify({
          name: String(input),
          fields: manifestFields,
        }),{status:200});
      }
      throw new Error("Unexpected fetch " + url.href);
    }));
    const doc = {
      name: "projects/pubget-aaf27/databases/(default)/documents/storageMigrationManifest/test",
      fields: {
        sourcePath: {stringValue:"fan_works/alice/work/cover.jpg"},
        sourceBucket: {stringValue:"pubget-aaf27.firebasestorage.app"},
        sourceGeneration: {stringValue:"77"},
        sourceMetageneration: {stringValue:"3"},
        sizeBytes: {integerValue:String(sourceBytes.length)},
        contentType: {stringValue:"image/jpeg"},
        sourceMetadata: {mapValue:{fields:{uploadedBy:{stringValue:"alice"}}}},
        contentMetadata: {mapValue:{fields:{contentType:{stringValue:"image/jpeg"},cacheControl:{stringValue:"private"}}}},
        status: {stringValue:"pending"},
        attempts: {integerValue:"0"},
      },
    };
    return {bucket,doc,requests,getDestination:()=>destinationBytes,manifest:()=>manifestFields};
  }

  it("copies and marks verified only after matching source/destination SHA-256 and size", async () => {
    const state = setup();
    const result = await hooks.copyObject(
      {MEDIA_BUCKET:state.bucket} as never,
      "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents",
      "firestore-token","gcs-token",state.doc,false,
    );
    expect(result).toMatchObject({status:"verified",sizeBytes:12});
    expect(state.manifest()).toMatchObject({
      status:{stringValue:"verified"},
      sourceSha256:{stringValue:expect.any(String)},
      destinationSha256:{stringValue:expect.any(String)},
      verifiedAt:{stringValue:expect.any(String)},
    });
    expect(state.manifest().sourceSha256).toEqual(state.manifest().destinationSha256);
    expect(state.getDestination()).not.toBeNull();
    expect(state.requests.some(url=>url.includes("alt=media"))).toBe(true);
    expect(state.requests.some(url=>url.includes("DELETE"))).toBe(false);
  });

  it("deletes a corrupt partial R2 copy and leaves the Firebase source untouched", async () => {
    const state = setup(true);
    const result = await hooks.copyObject(
      {MEDIA_BUCKET:state.bucket} as never,
      "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents",
      "firestore-token","gcs-token",state.doc,false,
    );
    expect(result).toMatchObject({status:"failed",reason:"verification-mismatch"});
    expect(state.getDestination()).toBeNull();
    expect(state.manifest()).toMatchObject({
      status:{stringValue:"failed"},
      lastError:{stringValue:expect.stringContaining("verification mismatch")},
    });
    expect(state.requests.some(url=>url.includes("alt=media"))).toBe(true);
  });
  it("does not download the GCS source again for a matching verified generation", async () => {
    const state = setup();
    const first = await hooks.copyObject(
      {MEDIA_BUCKET:state.bucket} as never,
      "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents",
      "firestore-token","gcs-token",state.doc,false,
    );
    expect(first.status).toBe("verified");
    const sourceHash = String((state.manifest().sourceSha256 as {stringValue:string}).stringValue);
    const verifiedDoc = {
      ...state.doc,
      fields: {
        ...state.doc.fields,
        status: {stringValue:"verified"},
        destinationSha256: {stringValue:sourceHash},
      },
    };
    const before = state.requests.filter(url=>url.includes("alt=media")).length;
    const second = await hooks.copyObject(
      {MEDIA_BUCKET:state.bucket} as never,
      "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents",
      "firestore-token","gcs-token",verifiedDoc,false,
    );
    expect(second).toMatchObject({status:"verified",skipped:true});
    expect(state.requests.filter(url=>url.includes("alt=media")).length).toBe(before);
  });


});
