import { describe, expect, it } from "vitest";
import {
  createFirestoreAchievementOutboxStore,
  runAchievementOutboxBatch,
} from "./achievementOutboxStore";
import { AchievementEffect } from "./achievementOutbox";

type FsValue = Record<string, unknown>;
function encode(value: unknown): FsValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") return Number.isInteger(value)
    ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === "object") {
    return { mapValue: { fields: Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([, item]) => item !== undefined)
        .map(([key, item]) => [key, encode(item)]),
    ) } };
  }
  throw new Error("unsupported");
}
function decode(value: FsValue): unknown {
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("mapValue" in value) {
    return Object.fromEntries(Object.entries(
      (value.mapValue as { fields?: Record<string, FsValue> }).fields ?? {},
    ).map(([key, item]) => [key, decode(item)]));
  }
  if ("arrayValue" in value) {
    return ((value.arrayValue as { values?: FsValue[] }).values ?? []).map(decode);
  }
  return null;
}

function fakeFirestore(initial: Record<string, unknown>) {
  const project = "demo-outbox";
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const path = "achievement_outbox/event-1";
  const fullPath = `${base}/${path}`;
  const resourcePath = `projects/${project}/databases/(default)/documents/${path}`;
  let version = 1;
  let transactionNumber = 0;
  const transactionVersions = new Map<string, number>();
  let document = Object.fromEntries(
    Object.entries(initial).map(([key, item]) => [key, encode(item)]),
  ) as Record<string, FsValue>;

  const fetcher: typeof fetch = async (input, init = {}) => {
    const url = String(input);
    if (url.endsWith(":beginTransaction")) {
      const transaction = `tx-${++transactionNumber}`;
      transactionVersions.set(transaction, version);
      return Response.json({ transaction });
    }
    if (url.includes("/achievement_outbox?") || url.endsWith("/achievement_outbox")) {
      return Response.json({
        documents: [{ name: resourcePath, fields: document }],
      });
    }
    if (url.startsWith(fullPath + "?transaction=")) {
      const transaction = new URL(url).searchParams.get("transaction")!;
      transactionVersions.set(transaction, version);
      return Response.json({ name: resourcePath, fields: document });
    }
    if (url.endsWith(":commit")) {
      const body = JSON.parse(String(init.body)) as {
        transaction: string;
        writes: Array<{ update: { fields: Record<string, FsValue> }; updateMask: { fieldPaths: string[] } }>;
      };
      if (transactionVersions.get(body.transaction) !== version) {
        return new Response("ABORTED: transaction conflict", { status: 409 });
      }
      for (const write of body.writes) {
        for (const field of write.updateMask.fieldPaths) {
          if (field in write.update.fields) document[field] = write.update.fields[field];
          else delete document[field];
        }
      }
      version += 1;
      return Response.json({ writeResults: [{}] });
    }
    return new Response("not found", { status: 404 });
  };

  return {
    path,
    fetcher,
    read() {
      return Object.fromEntries(Object.entries(document).map(([key, item]) => [key, decode(item)]));
    },
  };
}

function seedEvent(status: string, effectStatus: string, extra: Record<string, unknown> = {}) {
  return {
    userId: "user-1",
    achievementId: "the_threshold",
    status,
    effects: [{
      id: "effect-1",
      kind: "coin_reward",
      status: effectStatus,
      attempts: 0,
      payload: { amount: 5 },
      ...extra,
    }],
    createdAt: "2026-11-19T00:00:00.000Z",
  };
}
const env = {
  FIREBASE_PROJECT_ID: "demo-outbox",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "worker@example.iam.gserviceaccount.com",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "unused-in-unit-test",
};

describe("Firestore achievement outbox store", () => {
  it("claims a pending effect atomically and persists its lease", async () => {
    const fake = fakeFirestore(seedEvent("pending", "pending"));
    const store = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    const effect = await store.claimNextEffect(fake.path, "worker-a", 1_000, 60_000);
    expect(effect?.status).toBe("processing");
    expect(effect?.leaseOwner).toBe("worker-a");
    expect(effect?.leaseUntil).toBe(61_000);
    expect(effect?.attempts).toBe(1);
    const persisted = fake.read().effects as Array<Record<string, unknown>>;
    expect(persisted[0].leaseOwner).toBe("worker-a");
    expect(fake.read().status).toBe("processing");
  });

  it("does not steal an active lease and recovers it after expiry", async () => {
    const fake = fakeFirestore(seedEvent("processing", "processing", {
      leaseOwner: "worker-a", leaseUntil: 5_000, attempts: 1,
    }));
    const store = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    expect(await store.claimNextEffect(fake.path, "worker-b", 4_999, 10_000)).toBeNull();
    const recovered = await store.claimNextEffect(fake.path, "worker-b", 5_000, 10_000);
    expect(recovered?.leaseOwner).toBe("worker-b");
    expect(recovered?.attempts).toBe(2);
  });


  it("allows only one concurrent worker to own the same pending effect", async () => {
    const fake = fakeFirestore(seedEvent("pending", "pending"));
    const storeA = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    const storeB = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    const claims = await Promise.all([
      storeA.claimNextEffect(fake.path, "worker-a", 1_000, 60_000),
      storeB.claimNextEffect(fake.path, "worker-b", 1_000, 60_000),
    ]);
    expect(claims.filter(Boolean)).toHaveLength(1);
    expect(["worker-a", "worker-b"]).toContain(
      (fake.read().effects as Array<Record<string, unknown>>)[0].leaseOwner,
    );
  });

  it("honours retry backoff and allows the effect at its retry time", async () => {
    const fake = fakeFirestore(seedEvent("retry", "retry", {
      nextAttemptAt: 9_000, attempts: 2,
    }));
    const store = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    expect(await store.claimNextEffect(fake.path, "worker-b", 8_999, 10_000)).toBeNull();
    expect((await store.claimNextEffect(fake.path, "worker-b", 9_000, 10_000))?.attempts).toBe(3);
  });

  it("only the lease owner can complete an effect", async () => {
    const fake = fakeFirestore(seedEvent("processing", "processing", {
      leaseOwner: "worker-a", leaseUntil: 50_000, attempts: 1,
    }));
    const store = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    await expect(store.markDelivered(fake.path, "effect-1", "worker-b", 2_000))
      .rejects.toThrow("Outbox lease is not owned by this worker.");
    await store.markDelivered(fake.path, "effect-1", "worker-a", 2_000);
    const persisted = fake.read().effects as Array<Record<string, unknown>>;
    expect(persisted[0].status).toBe("delivered");
    expect(fake.read().status).toBe("completed");
  });

  it("returns failed deliveries to retry with persisted backoff", async () => {
    const fake = fakeFirestore(seedEvent("pending", "pending"));
    const store = createFirestoreAchievementOutboxStore(env, {
      fetcher: fake.fetcher,
      getAccessToken: async () => "test-token",
    });
    const claimed = await store.claimNextEffect(fake.path, "worker-a", 1_000, 60_000);
    expect(claimed).not.toBeNull();
    await store.markRetry(fake.path, "effect-1", "worker-a", 1_100, "temporary");
    const persisted = fake.read().effects as Array<Record<string, unknown>>;
    expect(persisted[0].status).toBe("retry");
    expect(persisted[0].nextAttemptAt).toBe(6_100);
    expect(persisted[0].leaseOwner).toBeUndefined();
  });
});

describe("outbox batch consumer", () => {
  it("marks successful delivery and retries a failed delivery", async () => {
    const claimed: AchievementEffect = {
      id: "effect-1", eventId: "event-1", userId: "user-1",
      achievementId: "the_threshold", kind: "coin_reward",
      status: "processing", attempts: 1, leaseOwner: "worker-a",
      leaseUntil: 100_000, payload: {},
    };
    const calls: string[] = [];
    const result = await runAchievementOutboxBatch({
      workerId: "worker-a",
      now: () => 1_000,
      store: {
        listCandidateEvents: async () => ["event-1", "event-2"],
        claimNextEffect: async (path) => path === "event-1" ? claimed : {
          ...claimed, id: "effect-2",
        },
        markDelivered: async (_path, id) => { calls.push("delivered:" + id); },
        markRetry: async (_path, id) => { calls.push("retry:" + id); },
      },
      deliver: async (effect) => {
        if (effect.id === "effect-2") throw new Error("temporary");
      },
    });
    expect(result).toEqual({
      scanned: 2, claimed: 2, delivered: 1, retried: 1, skipped: 0,
    });
    expect(calls).toEqual(["delivered:effect-1", "retry:effect-2"]);
  });
});
