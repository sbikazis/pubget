export type AchievementEffectKind = "coin_reward" | "in_app_notification" | "fcm_push";
export type EffectStatus = "pending" | "processing" | "delivered" | "retry";

export interface AchievementEffect {
  id: string;
  eventId: string;
  userId: string;
  achievementId: string;
  kind: AchievementEffectKind;
  status: EffectStatus;
  attempts: number;
  leaseOwner?: string;
  leaseUntil?: number;
  nextAttemptAt?: number;
  lastError?: string;
  deliveredAt?: number;
  payload: Record<string, unknown>;
}

export interface AchievementOutboxEvent {
  id: string;
  userId: string;
  achievementId: string;
  status: "pending" | "processing" | "completed" | "retry";
  effects: AchievementEffect[];
  createdAt: number;
  completedAt?: number;
}

/**
 * Pure state transitions for the durable achievement outbox.
 *
 * Persistence adapters MUST apply each transition with a Firestore transaction.
 * Effect IDs are deterministic so a retried enqueue cannot create a second
 * reward, notification record, or push-delivery record.
 */
export function achievementEventId(userId: string, achievementId: string): string {
  return `achievement_${userId}_${achievementId}`;
}

export function achievementEffectId(
  userId: string,
  achievementId: string,
  kind: AchievementEffectKind,
): string {
  return `${achievementEventId(userId, achievementId)}_${kind}`;
}

export function createAchievementOutboxEvent(input: {
  userId: string;
  achievementId: string;
  rewardCoins: number;
  notification: Record<string, unknown>;
  now: number;
}): AchievementOutboxEvent {
  const { userId, achievementId, rewardCoins, notification, now } = input;
  if (!userId || !achievementId || !Number.isSafeInteger(now) || now < 0) {
    throw new Error("Invalid achievement outbox identity.");
  }
  if (!Number.isSafeInteger(rewardCoins) || rewardCoins < 0) {
    throw new Error("Invalid achievement reward.");
  }

  const eventId = achievementEventId(userId, achievementId);
  const effects: AchievementEffect[] = [];
  if (rewardCoins > 0) {
    effects.push({
      id: achievementEffectId(userId, achievementId, "coin_reward"),
      eventId, userId, achievementId, kind: "coin_reward",
      status: "pending", attempts: 0,
      payload: {
        type: "earn_achievement",
        referenceId: achievementId,
        amount: rewardCoins,
        source: "achievement",
      },
    });
  }
  effects.push({
    id: achievementEffectId(userId, achievementId, "in_app_notification"),
    eventId, userId, achievementId, kind: "in_app_notification",
    status: "pending", attempts: 0, payload: { ...notification },
  });
  effects.push({
    id: achievementEffectId(userId, achievementId, "fcm_push"),
    eventId, userId, achievementId, kind: "fcm_push",
    status: "pending", attempts: 0,
    payload: { notificationId: `achievement-${userId}-${achievementId}` },
  });

  return { id: eventId, userId, achievementId, status: "pending", effects, createdAt: now };
}

export function claimAchievementEffect(
  effect: AchievementEffect,
  workerId: string,
  now: number,
  leaseMs: number,
): AchievementEffect | null {
  if (!workerId || !Number.isSafeInteger(now) || now < 0 ||
      !Number.isSafeInteger(leaseMs) || leaseMs < 1) {
    throw new Error("Invalid outbox lease.");
  }
  const leaseExpired = effect.status === "processing" &&
    (effect.leaseUntil ?? 0) <= now;
  const eligible = effect.status === "pending" ||
    effect.status === "retry" && (effect.nextAttemptAt ?? 0) <= now ||
    leaseExpired;
  if (!eligible) return null;
  return {
    ...effect,
    status: "processing",
    attempts: effect.attempts + 1,
    leaseOwner: workerId,
    leaseUntil: now + leaseMs,
    nextAttemptAt: undefined,
    lastError: undefined,
  };
}

export function completeAchievementEffect(
  effect: AchievementEffect,
  workerId: string,
  now: number,
): AchievementEffect {
  if (effect.status !== "processing" || effect.leaseOwner !== workerId ||
      (effect.leaseUntil ?? 0) <= now) {
    throw new Error("Outbox lease is not owned by this worker.");
  }
  return {
    ...effect,
    status: "delivered",
    deliveredAt: now,
    leaseOwner: undefined,
    leaseUntil: undefined,
    nextAttemptAt: undefined,
    lastError: undefined,
  };
}

export function retryAchievementEffect(
  effect: AchievementEffect,
  workerId: string,
  now: number,
  errorCode: string,
  baseDelayMs = 5_000,
  maxDelayMs = 6 * 60 * 60 * 1000,
): AchievementEffect {
  if (effect.status !== "processing" || effect.leaseOwner !== workerId ||
      (effect.leaseUntil ?? 0) <= now) {
    throw new Error("Outbox lease is not owned by this worker.");
  }
  const exponent = Math.min(Math.max(effect.attempts - 1, 0), 20);
  const delay = Math.min(baseDelayMs * (2 ** exponent), maxDelayMs);
  return {
    ...effect,
    status: "retry",
    leaseOwner: undefined,
    leaseUntil: undefined,
    nextAttemptAt: now + delay,
    lastError: errorCode.slice(0, 120),
  };
}

export function refreshAchievementEvent(
  event: AchievementOutboxEvent,
  effects: AchievementEffect[],
  now: number,
): AchievementOutboxEvent {
  const allDelivered = effects.length > 0 && effects.every((effect) => effect.status === "delivered");
  const anyProcessing = effects.some((effect) => effect.status === "processing");
  return {
    ...event,
    effects,
    status: allDelivered ? "completed" : anyProcessing ? "processing" : "retry",
    ...(allDelivered ? { completedAt: now } : { completedAt: undefined }),
  };
}

/**
 * FCM is deliberately modelled as a separate effect. A crash after FCM accepts
 * a message but before this record is committed can cause a duplicate push.
 * The contract is at-least-once, not exactly-once. In-app notification and
 * coin reward effects must be idempotent independently of FCM.
 */
