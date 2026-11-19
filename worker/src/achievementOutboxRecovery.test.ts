import { describe, expect, it } from "vitest";
import {
  AchievementEffect,
  AchievementOutboxEvent,
  claimAchievementEffect,
  completeAchievementEffect,
  createAchievementOutboxEvent,
  refreshAchievementEvent,
  retryAchievementEffect,
} from "./achievementOutbox";
import {
  AchievementOutboxStore,
  runAchievementOutboxBatch,
} from "./achievementOutboxStore";

function seededEvent(): AchievementOutboxEvent {
  return createAchievementOutboxEvent({
    userId: "user-1",
    achievementId: "the_threshold",
    rewardCoins: 5,
    notification: {
      id: "achievement-user-1-the_threshold",
      type: "achievement_unlocked",
    },
    now: 1_000,
  });
}

/**
 * Durable in-memory model of the Firestore outbox document. It intentionally
 * survives worker/runner recreation so tests exercise restart recovery rather
 * than relying on process-local state.
 */
function durableStore(seed: AchievementOutboxEvent) {
  let event = structuredClone(seed);
  const deliveredBusinessKeys = new Set<string>();
  const externalAttempts = new Map<string, number>();
  let now = 1_000;

  const store: AchievementOutboxStore = {
    listCandidateEvents: async (limit) =>
      event.status === "completed" ? [] : [event.id].slice(0, limit),
    claimNextEffect: async (_path, workerId, claimNow, leaseMs) => {
      for (let index = 0; index < event.effects.length; index += 1) {
        const claimed = claimAchievementEffect(event.effects[index], workerId, claimNow, leaseMs);
        if (!claimed) continue;
        const effects = [...event.effects];
        effects[index] = claimed;
        event = refreshAchievementEvent(event, effects, claimNow);
        return structuredClone(claimed);
      }
      return null;
    },
    markDelivered: async (_path, effectId, workerId, completedAt) => {
      const index = event.effects.findIndex((item) => item.id === effectId);
      if (index < 0) throw new Error("missing_effect");
      const effects = [...event.effects];
      effects[index] = completeAchievementEffect(effects[index], workerId, completedAt);
      event = refreshAchievementEvent(event, effects, completedAt);
    },
    markRetry: async (_path, effectId, workerId, retryAt, errorCode) => {
      const index = event.effects.findIndex((item) => item.id === effectId);
      if (index < 0) throw new Error("missing_effect");
      const effects = [...event.effects];
      effects[index] = retryAchievementEffect(effects[index], workerId, retryAt, errorCode);
      event = refreshAchievementEvent(event, effects, retryAt);
    },
  };

  return {
    store,
    event: () => structuredClone(event),
    setNow(value: number) { now = value; },
    now: () => now,
    businessEffects: deliveredBusinessKeys,
    externalAttempts,
    async deliverIdempotently(effect: AchievementEffect) {
      externalAttempts.set(effect.id, (externalAttempts.get(effect.id) ?? 0) + 1);
      // Simulate the idempotency keys used by the economy ledger and notification ID.
      const key = effect.kind === "coin_reward" ? `coin:${effect.userId}:${effect.achievementId}`
        : effect.kind === "in_app_notification" ? `notification:${effect.userId}:${effect.achievementId}`
        : `push-attempt:${effect.id}:${externalAttempts.get(effect.id)}`;
      deliveredBusinessKeys.add(key);
    },
  };
}

describe("achievement outbox recovery and fault matrix", () => {
  it("recovers every pending effect across repeated worker restarts without losing durable effects", async () => {
    const durable = durableStore(seededEvent());
    const delivered: string[] = [];

    for (let restart = 0; restart < 3; restart += 1) {
      const result = await runAchievementOutboxBatch({
        store: durable.store,
        workerId: `worker-restart-${restart}`,
        now: durable.now,
        batchSize: 1,
        leaseMs: 60_000,
        deliver: async (effect) => { delivered.push(effect.kind); },
      });
      expect(result.delivered).toBe(1);
      durable.setNow(durable.now() + 1);
    }

    expect(delivered).toEqual(["coin_reward", "in_app_notification", "fcm_push"]);
    expect(durable.event().effects.every((effect) => effect.status === "delivered")).toBe(true);
    expect(durable.event().status).toBe("completed");
  });

  it("retries a transient delivery failure after persisted backoff and completes on a later invocation", async () => {
    const durable = durableStore(seededEvent());
    let failFirst = true;
    const first = await runAchievementOutboxBatch({
      store: durable.store,
      workerId: "worker-a",
      now: durable.now,
      deliver: async () => {
        if (failFirst) { failFirst = false; throw new Error("temporary network outage"); }
      },
    });
    expect(first).toMatchObject({ claimed: 1, retried: 1, delivered: 0 });
    const effectAfterFailure = durable.event().effects[0];
    expect(effectAfterFailure.status).toBe("retry");
    expect(effectAfterFailure.attempts).toBe(1);
    expect(effectAfterFailure.nextAttemptAt).toBe(6_000);

    durable.setNow(5_999);
    const tooEarly = await runAchievementOutboxBatch({
      store: durable.store, workerId: "worker-b", now: durable.now,
      deliver: async () => undefined,
    });
    expect(tooEarly.skipped).toBe(1);

    durable.setNow(6_000);
    const recovered = await runAchievementOutboxBatch({
      store: durable.store, workerId: "worker-b", now: durable.now,
      deliver: async () => undefined,
    });
    expect(recovered.delivered).toBe(1);
    expect(durable.event().effects[0].status).toBe("delivered");
  });

  it("recovers a worker crash after claim but before delivery once the lease expires", async () => {
    const durable = durableStore(seededEvent());
    const claimed = await durable.store.claimNextEffect("event", "crashed-worker", 1_000, 10_000);
    expect(claimed?.status).toBe("processing");
    expect(durable.event().effects[0].leaseOwner).toBe("crashed-worker");

    durable.setNow(10_999);
    const beforeExpiry = await durable.store.claimNextEffect("event", "recovery-worker", 10_999, 10_000);
    expect(beforeExpiry).toBeNull();

    durable.setNow(11_000);
    const recovered = await durable.store.claimNextEffect("event", "recovery-worker", 11_000, 10_000);
    expect(recovered?.leaseOwner).toBe("recovery-worker");
    expect(recovered?.attempts).toBe(2);
    await durable.store.markDelivered("event", recovered!.id, "recovery-worker", 11_001);
    expect(durable.event().effects[0].status).toBe("delivered");
  });

  it("rejects stale worker acknowledgement after lease takeover", async () => {
    const durable = durableStore(seededEvent());
    const first = await durable.store.claimNextEffect("event", "worker-old", 1_000, 100);
    expect(first).not.toBeNull();
    const second = await durable.store.claimNextEffect("event", "worker-new", 1_100, 100);
    expect(second?.leaseOwner).toBe("worker-new");
    await expect(durable.store.markDelivered("event", first!.id, "worker-old", 1_101))
      .rejects.toThrow();
    await durable.store.markDelivered("event", second!.id, "worker-new", 1_102);
    expect(durable.event().effects[0].status).toBe("delivered");
  });

  it("keeps event incomplete until every independent effect is delivered", async () => {
    const durable = durableStore(seededEvent());
    const first = await durable.store.claimNextEffect("event", "worker", 1_000, 60_000);
    await durable.store.markDelivered("event", first!.id, "worker", 1_001);
    expect(durable.event().status).not.toBe("completed");
    expect(durable.event().effects.filter((effect) => effect.status === "delivered")).toHaveLength(1);

    const second = await durable.store.claimNextEffect("event", "worker", 1_002, 60_000);
    await durable.store.markDelivered("event", second!.id, "worker", 1_003);
    expect(durable.event().status).not.toBe("completed");

    const third = await durable.store.claimNextEffect("event", "worker", 1_004, 60_000);
    await durable.store.markDelivered("event", third!.id, "worker", 1_005);
    expect(durable.event().status).toBe("completed");
  });

  it("documents the unavoidable FCM duplicate window while keeping coin and notification effects idempotent", async () => {
    const durable = durableStore(seededEvent());
    const push = durable.event().effects.find((effect) => effect.kind === "fcm_push")!;
    const claimed = claimAchievementEffect(push, "push-worker", 1_000, 100);
    expect(claimed).not.toBeNull();

    // External FCM accepted the message, but the process crashes before markDelivered.
    await durable.deliverIdempotently(claimed!);
    const recovered = claimAchievementEffect(claimed!, "push-worker-2", 1_100, 100);
    expect(recovered?.attempts).toBe(2);
    await durable.deliverIdempotently(recovered!);
    expect([...durable.businessEffects].filter((key) => key.startsWith("push-attempt:"))).toHaveLength(2);

    const coin = durable.event().effects.find((effect) => effect.kind === "coin_reward")!;
    await durable.deliverIdempotently(coin);
    await durable.deliverIdempotently(coin);
    expect([...durable.businessEffects].filter((key) => key === "coin:user-1:the_threshold")).toHaveLength(1);
    const notification = durable.event().effects.find((effect) => effect.kind === "in_app_notification")!;
    await durable.deliverIdempotently(notification);
    await durable.deliverIdempotently(notification);
    expect([...durable.businessEffects].filter((key) => key === "notification:user-1:the_threshold")).toHaveLength(1);
  });

  it("does not mark a reward or notification effect delivered when the downstream handler fails", async () => {
    const durable = durableStore(seededEvent());
    const result = await runAchievementOutboxBatch({
      store: durable.store,
      workerId: "worker-failing",
      now: durable.now,
      deliver: async () => { throw new Error("downstream unavailable"); },
    });
    expect(result.retried).toBe(1);
    expect(durable.event().effects[0].status).toBe("retry");
    expect(durable.event().status).not.toBe("completed");
  });
});
