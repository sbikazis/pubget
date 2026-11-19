import { describe, expect, it } from "vitest";
import {
  createAchievementNotificationDelivery,
  createAchievementFcmPushDelivery,
} from "./achievementNotifications";
import { AchievementEffect, achievementEffectId, achievementEventId } from "./achievementOutbox";

const env = {
  FIREBASE_PROJECT_ID: "demo-pubget",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "worker@example.iam.gserviceaccount.com",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "test-only",
};
function effect(kind: "in_app_notification" | "fcm_push"): AchievementEffect {
  const userId = "user_1";
  const achievementId = "the_threshold";
  const notificationId = `achievement-${userId}-${achievementId}`;
  return {
    id: achievementEffectId(userId, achievementId, kind),
    eventId: achievementEventId(userId, achievementId),
    userId, achievementId, kind, status: "processing", attempts: 1,
    leaseOwner: "worker", leaseUntil: 99_000,
    payload: kind === "fcm_push"
      ? { notificationId, title: "Achievement unlocked", body: "The Threshold" }
      : {
          id: notificationId, recipientIds: [userId], type: "achievement_unlocked",
          actorId: userId, targetId: achievementId, action: "unlocked",
          destination: `/achievements?id=${achievementId}`,
          metadata: { achievementId, celebration: true },
          title: "Achievement unlocked", body: "The Threshold", pushWorthy: true,
        },
  };
}
function response(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

describe("achievement in-app notification delivery", () => {
  it("creates notification and unread counter atomically with server timestamp", async () => {
    const calls: Array<{ url: string; body?: any }> = [];
    const fetcher: typeof fetch = async (input, init = {}) => {
      const url = String(input);
      const body = init.body ? JSON.parse(String(init.body)) : undefined;
      calls.push({ url, body });
      if (url.endsWith(":beginTransaction")) return response({ transaction: "tx" });
      if (url.includes("/notifications/") && url.includes("?transaction=")) {
        return new Response("missing", { status: 404 });
      }
      if (url.includes("/users/user_1?transaction=")) return response({
        name: "users/user_1", fields: {},
      });
      if (url.endsWith(":commit")) return response({ writeResults: [] });
      if (url.endsWith(":rollback")) return response({});
      return new Response("unexpected", { status: 500 });
    };
    const scopes: string[] = [];
    const deliver = createAchievementNotificationDelivery(env, {
      fetcher, getAccessToken: async (scope) => { scopes.push(scope); return "token"; },
    });
    await expect(deliver(effect("in_app_notification"))).resolves.toEqual({ created: true });
    const commit = calls.find((call) => call.url.endsWith(":commit"))?.body;
    expect(commit.writes).toHaveLength(2);
    expect(commit.writes[0].currentDocument).toEqual({ exists: false });
    expect(commit.writes[0].update.fields.type.stringValue).toBe("achievement_unlocked");
    expect(commit.writes[0].updateTransforms[0]).toEqual({
      fieldPath: "createdAt", setToServerValue: "REQUEST_TIME",
    });
    expect(commit.writes[1].updateTransforms[0].increment.integerValue).toBe("1");
    expect(scopes).toEqual(["https://www.googleapis.com/auth/datastore"]);
  });

  it("treats an existing notification as a successful idempotent replay", async () => {
    const calls: string[] = [];
    const fetcher: typeof fetch = async (input) => {
      const url = String(input);
      calls.push(url);
      if (url.endsWith(":beginTransaction")) return response({ transaction: "tx" });
      if (url.includes("/notifications/")) return response({ name: "existing" });
      if (url.endsWith(":rollback")) return response({});
      return new Response("unexpected", { status: 500 });
    };
    const deliver = createAchievementNotificationDelivery(env, {
      fetcher, getAccessToken: async () => "token",
    });
    await expect(deliver(effect("in_app_notification"))).resolves.toEqual({ created: false });
    expect(calls.some((url) => url.endsWith(":commit"))).toBe(false);
    expect(calls.some((url) => url.endsWith(":rollback"))).toBe(true);
  });

  it("rejects a mismatched recipient or forged deterministic effect ID", async () => {
    const deliver = createAchievementNotificationDelivery(env, {
      fetcher: async () => new Response("unexpected", { status: 500 }),
      getAccessToken: async () => "token",
    });
    await expect(deliver({
      ...effect("in_app_notification"),
      payload: { ...effect("in_app_notification").payload, recipientIds: ["other_user"] },
    })).rejects.toThrow("ACHIEVEMENT_NOTIFICATION_INVALID_EFFECT");
  });
});

describe("achievement FCM delivery", () => {
  it("uses the FCM OAuth scope, queries the user's token docs and sends a data-routed push", async () => {
    const calls: Array<{ url: string; body?: any; authorization?: string }> = [];
    const fetcher: typeof fetch = async (input, init = {}) => {
      const url = String(input);
      const body = init.body ? JSON.parse(String(init.body)) : undefined;
      calls.push({ url, body, authorization: new Headers(init.headers).get("authorization") ?? undefined });
      if (url.endsWith(":runQuery")) return response([{
        document: { fields: { uid: { stringValue: "user_1" }, token: { stringValue: "device-token" } } },
      }]);
      if (url.includes("fcm.googleapis.com")) return response({ name: "projects/demo-pubget/messages/1" });
      return new Response("unexpected", { status: 500 });
    };
    const scopes: string[] = [];
    const deliver = createAchievementFcmPushDelivery(env, {
      fetcher, getAccessToken: async (scope) => { scopes.push(scope); return "token"; },
    });
    await expect(deliver(effect("fcm_push"))).resolves.toEqual({ sent: 1, noTokens: false });
    expect(scopes).toEqual(["https://www.googleapis.com/auth/firebase.messaging"]);
    const query = calls.find((call) => call.url.endsWith(":runQuery"))?.body;
    expect(query.structuredQuery.from[0]).toMatchObject({
      collectionId: "fcmTokens", allDescendants: true,
    });
    const sent = calls.find((call) => call.url.includes("fcm.googleapis.com"));
    expect(sent?.body.message).toMatchObject({
      token: "device-token",
      data: {
        type: "achievement_unlocked",
        targetId: "the_threshold",
        notificationId: "achievement-user_1-the_threshold",
      },
      notification: { title: "Achievement unlocked", body: "The Threshold" },
    });
  });

  it("does not fail an event when the user has no registered device token", async () => {
    const deliver = createAchievementFcmPushDelivery(env, {
      fetcher: async () => response([]),
      getAccessToken: async () => "token",
    });
    await expect(deliver(effect("fcm_push"))).resolves.toEqual({ sent: 0, noTokens: true });
  });

  it("leaves failed FCM sends retryable", async () => {
    const deliver = createAchievementFcmPushDelivery(env, {
      fetcher: async (input) => String(input).endsWith(":runQuery")
        ? response([{ document: { fields: { token: { stringValue: "device-token" } } } }])
        : new Response("permission denied", { status: 403 }),
      getAccessToken: async () => "token",
    });
    await expect(deliver(effect("fcm_push"))).rejects.toThrow("ACHIEVEMENT_FCM_SEND_403");
  });
});
