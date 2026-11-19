import { describe, expect, it } from "vitest";
import {
  createAchievementCoinRewardDelivery,
  deliverAchievementCoinReward,
} from "./achievementCoinReward";
import { AchievementEffect } from "./achievementOutbox";

type Value = Record<string, unknown>;
function encode(value: unknown): Value {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") return { integerValue: String(value) };
  if (typeof value === "object" && value !== null) {
    return { mapValue: { fields: Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, encode(item)]),
    ) } };
  }
  throw new Error("unsupported value");
}
function decode(value: Value): unknown {
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("mapValue" in value) return Object.fromEntries(Object.entries(
    (value.mapValue as { fields?: Record<string, Value> }).fields ?? {},
  ).map(([key, item]) => [key, decode(item)]));
  return null;
}

function fakeFirestore(seed: Record<string, Record<string, unknown>>) {
  const project = "demo-economy";
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const prefix = `projects/${project}/databases/(default)/documents/`;
  const docs = new Map(Object.entries(seed).map(([path, fields]) => [
    path, Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, encode(value)])),
  ] as [string, Record<string, Value>]));
  let version = 1;
  let nextTransaction = 0;
  const snapshots = new Map<string, number>();

  const fetcher: typeof fetch = async (input, init = {}) => {
    const url = String(input);
    if (url.endsWith(":beginTransaction")) {
      const transaction = `tx-${++nextTransaction}`;
      snapshots.set(transaction, version);
      return Response.json({ transaction });
    }
    if (url.endsWith(":rollback")) return Response.json({});
    if (url.endsWith(":commit")) {
      const body = JSON.parse(String(init.body)) as {
        transaction: string;
        writes: Array<{
          update?: { name: string; fields: Record<string, Value> };
          updateMask?: { fieldPaths: string[] };
          currentDocument?: { exists: boolean };
        }>;
      };
      if (snapshots.get(body.transaction) !== version) {
        return new Response("ABORTED: transaction conflict", { status: 409 });
      }
      for (const write of body.writes) {
        if (!write.update) continue;
        const path = write.update.name.slice(prefix.length);
        const exists = docs.has(path);
        if (write.currentDocument?.exists === false && exists) {
          return new Response("FAILED_PRECONDITION: exists", { status: 400 });
        }
        if (write.currentDocument?.exists === true && !exists) {
          return new Response("FAILED_PRECONDITION: missing", { status: 400 });
        }
        const next = write.updateMask
          ? { ...(docs.get(path) ?? {}) }
          : {};
        for (const [key, value] of Object.entries(write.update.fields)) {
          if (!write.updateMask || write.updateMask.fieldPaths.includes(key)) next[key] = value;
        }
        docs.set(path, next);
      }
      version += 1;
      return Response.json({ writeResults: [] });
    }
    const match = url.match(/\/documents\/(.+)\?transaction=/);
    if (match) {
      const path = decodeURIComponent(match[1]);
      const fields = docs.get(path);
      if (!fields) return new Response("NOT_FOUND", { status: 404 });
      return Response.json({ name: prefix + path, fields });
    }
    return new Response("unexpected request", { status: 500 });
  };

  return {
    fetcher,
    get(path: string) {
      const fields = docs.get(path);
      return fields ? Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decode(value)])) : null;
    },
    count(prefixPath: string) {
      return [...docs.keys()].filter((path) => path.startsWith(prefixPath)).length;
    },
  };
}

const env = {
  FIREBASE_PROJECT_ID: "demo-economy",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "worker@example.iam.gserviceaccount.com",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "test-only",
};
const user = { coinsBalance: 20, economyVersion: 3 };
function effect(overrides: Partial<AchievementEffect> = {}): AchievementEffect {
  return {
    id: "achievement_user-1_the_threshold_coin_reward",
    eventId: "achievement_user-1_the_threshold",
    userId: "user-1",
    achievementId: "the_threshold",
    kind: "coin_reward",
    status: "processing",
    attempts: 1,
    leaseOwner: "worker-1",
    leaseUntil: 100_000,
    payload: {
      type: "earn_achievement",
      referenceId: "the_threshold",
      amount: 5,
      source: "achievement",
    },
    ...overrides,
  };
}
function createDelivery(fake: ReturnType<typeof fakeFirestore>) {
  return createAchievementCoinRewardDelivery(env, {
    fetcher: fake.fetcher,
    getAccessToken: async () => "test-token",
    now: () => new Date("2026-11-19T12:00:00.000Z"),
  });
}

describe("achievement coin reward delivery", () => {
  it("credits the server-owned amount and writes the canonical economy ledger", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    const result = await createDelivery(fake)(effect());
    expect(result).toMatchObject({
      applied: true, amount: 5, balanceAfter: 25, version: 4,
      transactionId: "earn_achievement_user-1_the_threshold",
    });
    expect(fake.get("users/user-1")).toMatchObject({ coinsBalance: 25, economyVersion: 4 });
    expect(fake.get("economyTransactions/earn_achievement_user-1_the_threshold")).toMatchObject({
      userId: "user-1", type: "earn_achievement", amount: 5,
      balanceBefore: 20, balanceAfter: 25, source: "achievement",
      referenceId: "the_threshold", idempotencyKey: "earn_achievement_user-1_the_threshold",
      schemaVersion: 1,
    });
    expect(fake.get("users/user-1/transactions/earn_achievement_user-1_the_threshold")).not.toBeNull();
    expect(fake.get("users/user-1/daily_rewards/achievement_2026-11-19")).toMatchObject({
      count: 1, date: "2026-11-19",
    });
  });


  it("uses the server catalog value for higher-rarity achievements", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    const higherReward = effect({
      id: "achievement_user-1_dragon_of_legacy_coin_reward",
      eventId: "achievement_user-1_dragon_of_legacy",
      achievementId: "dragon_of_legacy",
      payload: {
        type: "earn_achievement",
        referenceId: "dragon_of_legacy",
        amount: 100,
        source: "achievement",
      },
    });
    const result = await createDelivery(fake)(higherReward);
    expect(result).toMatchObject({ applied: true, amount: 100, balanceAfter: 120 });
    expect(fake.get("users/user-1")?.coinsBalance).toBe(120);
    expect(fake.get("economyTransactions/earn_achievement_user-1_dragon_of_legacy"))
      .toMatchObject({ amount: 100, metadata: { amountOverride: 100 } });
  });

  it("treats a replay as a successful delivery without crediting twice", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    const deliver = createDelivery(fake);
    const first = await deliver(effect());
    const replay = await deliver(effect());
    expect(first.applied).toBe(true);
    expect(replay).toMatchObject({ applied: false, reason: "duplicate" });
    expect(fake.get("users/user-1")?.coinsBalance).toBe(25);
    expect(fake.count("economyTransactions/")).toBe(1);
    await expect(deliverAchievementCoinReward(deliver, effect())).resolves.toMatchObject({
      reason: "duplicate",
    });
  });


  it("honours the legacy per-reference transaction guard", async () => {
    const fake = fakeFirestore({
      "users/user-1": user,
      "users/user-1/transactions/the_threshold": {
        transactionId: "legacy-achievement-record",
        amount: 5,
      },
    });
    const result = await createDelivery(fake)(effect());
    expect(result).toMatchObject({ applied: false, reason: "duplicate" });
    expect(fake.get("users/user-1")?.coinsBalance).toBe(20);
    expect(fake.count("economyTransactions/")).toBe(0);
  });

  it("serializes concurrent duplicate deliveries to one credit", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    const deliver = createDelivery(fake);
    const results = await Promise.all([deliver(effect()), deliver(effect())]);
    expect(results.filter((item) => item.applied)).toHaveLength(1);
    expect(results.filter((item) => item.reason === "duplicate")).toHaveLength(1);
    expect(fake.get("users/user-1")?.coinsBalance).toBe(25);
    expect(fake.count("economyTransactions/")).toBe(1);
  });

  it("does not trust an altered reward amount or identity", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    const deliver = createDelivery(fake);
    await expect(deliver(effect({ payload: { type: "earn_achievement", referenceId: "the_threshold", amount: 500 } })))
      .rejects.toThrow("ACHIEVEMENT_REWARD_INVALID_EFFECT");
    await expect(deliver(effect({ userId: "other-user" })))
      .rejects.toThrow("ACHIEVEMENT_REWARD_INVALID_EFFECT");
    expect(fake.get("users/user-1")?.coinsBalance).toBe(20);
  });

  it("respects the existing daily achievement reward cap", async () => {
    const fake = fakeFirestore({
      "users/user-1": user,
      "users/user-1/daily_rewards/achievement_2026-11-19": { count: 9, date: "2026-11-19" },
    });
    const result = await createDelivery(fake)(effect());
    expect(result).toMatchObject({ applied: false, reason: "daily_cap" });
    expect(fake.get("users/user-1")?.coinsBalance).toBe(20);
    expect(fake.count("economyTransactions/")).toBe(0);
  });

  it("rejects missing users and corrupt or overflowing balances without writes", async () => {
    const missing = fakeFirestore({});
    await expect(createDelivery(missing)(effect())).resolves.toMatchObject({ reason: "user_missing" });

    const corrupt = fakeFirestore({ "users/user-1": { coinsBalance: -1, economyVersion: 0 } });
    await expect(createDelivery(corrupt)(effect())).resolves.toMatchObject({ reason: "corrupt_balance" });

    const overflow = fakeFirestore({ "users/user-1": { coinsBalance: 1_000_000_000, economyVersion: 1 } });
    await expect(createDelivery(overflow)(effect())).resolves.toMatchObject({ reason: "overflow" });
  });

  it("rejects non-coin outbox effects", async () => {
    const fake = fakeFirestore({ "users/user-1": user });
    await expect(createDelivery(fake)(effect({ kind: "fcm_push" })))
      .rejects.toThrow("ACHIEVEMENT_REWARD_INVALID_EFFECT");
  });
});
