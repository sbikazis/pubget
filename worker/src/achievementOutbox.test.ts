import { describe, expect, it } from "vitest";
import {
  achievementEffectId,
  claimAchievementEffect,
  completeAchievementEffect,
  createAchievementOutboxEvent,
  refreshAchievementEvent,
  retryAchievementEffect,
} from "./achievementOutbox";

function event() {
  return createAchievementOutboxEvent({
    userId: "user-1",
    achievementId: "the_threshold",
    rewardCoins: 25,
    notification: { type: "achievement_unlocked", targetId: "the_threshold" },
    now: 100,
  });
}

describe("achievement outbox state machine", () => {
  it("creates deterministic independent effects", () => {
    const first = event();
    const second = event();
    expect(first.id).toBe(second.id);
    expect(first.effects.map((effect) => effect.id)).toEqual(second.effects.map((effect) => effect.id));
    expect(first.effects.map((effect) => effect.kind)).toEqual([
      "coin_reward", "in_app_notification", "fcm_push",
    ]);
    expect(achievementEffectId("user-1", "the_threshold", "coin_reward"))
      .toBe(first.effects[0].id);
  });

  it("does not claim an active lease and recovers an expired lease", () => {
    const pending = event().effects[0];
    const claimed = claimAchievementEffect(pending, "worker-a", 100, 50)!;
    expect(claimAchievementEffect(claimed, "worker-b", 120, 50)).toBeNull();
    const recovered = claimAchievementEffect(claimed, "worker-b", 150, 50)!;
    expect(recovered.leaseOwner).toBe("worker-b");
    expect(recovered.attempts).toBe(2);
  });

  it("rejects completion by a worker that does not own the lease", () => {
    const claimed = claimAchievementEffect(event().effects[0], "worker-a", 100, 50)!;
    expect(() => completeAchievementEffect(claimed, "worker-b", 110))
      .toThrow("Outbox lease is not owned by this worker.");
  });

  it("retries with bounded exponential backoff", () => {
    const claimed = claimAchievementEffect(event().effects[0], "worker-a", 100, 50)!;
    const retry = retryAchievementEffect(claimed, "worker-a", 110, "temporary", 10, 25);
    expect(retry.status).toBe("retry");
    expect(retry.nextAttemptAt).toBe(120);
    expect(claimAchievementEffect(retry, "worker-b", 119, 50)).toBeNull();
    expect(claimAchievementEffect(retry, "worker-b", 120, 50)?.attempts).toBe(2);
  });

  it("does not complete the event while any durable effect remains", () => {
    const original = event();
    const [reward, notification, push] = original.effects;
    const deliveredReward = completeAchievementEffect(
      claimAchievementEffect(reward, "worker-a", 100, 50)!, "worker-a", 101,
    );
    const deliveredNotification = completeAchievementEffect(
      claimAchievementEffect(notification, "worker-a", 100, 50)!, "worker-a", 101,
    );
    const partial = refreshAchievementEvent(original, [deliveredReward, deliveredNotification, push], 102);
    expect(partial.status).not.toBe("completed");
    expect(partial.completedAt).toBeUndefined();

    const deliveredPush = completeAchievementEffect(
      claimAchievementEffect(push, "worker-a", 100, 50)!, "worker-a", 103,
    );
    const complete = refreshAchievementEvent(
      partial, [deliveredReward, deliveredNotification, deliveredPush], 104,
    );
    expect(complete.status).toBe("completed");
    expect(complete.completedAt).toBe(104);
  });


  it("rejects stale workers after their lease expires", () => {
    const claimed = claimAchievementEffect(event().effects[0], "worker-a", 100, 10)!;
    expect(() => completeAchievementEffect(claimed, "worker-a", 110))
      .toThrow("Outbox lease is not owned by this worker.");
    expect(() => retryAchievementEffect(claimed, "worker-a", 110, "late"))
      .toThrow("Outbox lease is not owned by this worker.");
  });

  it("omits the coin effect for a zero-coin achievement", () => {
    const noReward = createAchievementOutboxEvent({
      userId: "user-1", achievementId: "keeper_of_time", rewardCoins: 0,
      notification: { type: "achievement_unlocked" }, now: 100,
    });
    expect(noReward.effects.map((effect) => effect.kind)).toEqual([
      "in_app_notification", "fcm_push",
    ]);
  });
});
