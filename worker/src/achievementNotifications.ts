import { getGoogleAccessToken } from "./firebaseAuth";
import { AchievementEffect, achievementEffectId, achievementEventId } from "./achievementOutbox";

export interface AchievementNotificationEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}
interface Dependencies {
  fetcher?: typeof fetch;
  getAccessToken?: (scopes: string[]) => Promise<string>;
}
type FsValue = Record<string, unknown>;
type FsDocument = { name: string; fields?: Record<string, FsValue> };
const DATASTORE_SCOPE = "https://www.googleapis.com/auth/datastore";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const MAX_TOKENS = 100;

function decode(value?: FsValue): unknown {
  if (!value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("mapValue" in value) {
    const fields = (value.mapValue as { fields?: Record<string, FsValue> }).fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, decode(item)]));
  }
  if ("arrayValue" in value) {
    return ((value.arrayValue as { values?: FsValue[] }).values ?? []).map(decode);
  }
  return null;
}
function encode(value: unknown): FsValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number" && Number.isSafeInteger(value)) return { integerValue: String(value) };
  if (typeof value === "object" && value !== null) {
    return { mapValue: { fields: Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([, item]) => item !== undefined)
        .map(([key, item]) => [key, encode(item)]),
    ) } };
  }
  throw new Error("ACHIEVEMENT_NOTIFICATION_INVALID_VALUE");
}
function validId(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.length <= 128 &&
    !value.includes("/");
}
function baseUrl(projectId: string): string {
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
}
function validateNotification(effect: AchievementEffect): {
  notificationId: string; userId: string; achievementId: string;
} {
  const payload = effect.payload;
  const userId = effect.userId;
  const achievementId = effect.achievementId;
  const notificationId = `achievement-${userId}-${achievementId}`;
  if (effect.kind !== "in_app_notification" ||
      effect.eventId !== achievementEventId(userId, achievementId) ||
      effect.id !== achievementEffectId(userId, achievementId, "in_app_notification") ||
      !validId(userId) || !validId(achievementId) ||
      payload.id !== notificationId ||
      payload.type !== "achievement_unlocked" ||
      payload.targetId !== achievementId ||
      payload.action !== "unlocked" ||
      payload.destination !== `/achievements?id=${achievementId}` ||
      !Array.isArray(payload.recipientIds) ||
      payload.recipientIds.length !== 1 || payload.recipientIds[0] !== userId) {
    throw new Error("ACHIEVEMENT_NOTIFICATION_INVALID_EFFECT");
  }
  return { notificationId, userId, achievementId };
}

export function createAchievementNotificationDelivery(
  env: AchievementNotificationEnv,
  dependencies: Dependencies = {},
): (effect: AchievementEffect) => Promise<{ created: boolean }> {
  const fetcher = dependencies.fetcher ?? fetch;
  const prefix = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/`;
  const base = baseUrl(env.FIREBASE_PROJECT_ID);
  async function token(): Promise<string> {
    if (dependencies.getAccessToken) return dependencies.getAccessToken([DATASTORE_SCOPE]);
    return getGoogleAccessToken(
      env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
      env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
      [DATASTORE_SCOPE], fetcher,
    );
  }
  async function request(url: string, accessToken: string, init: RequestInit = {}): Promise<Response> {
    return fetcher(url, { ...init, headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(init.body ? { "content-type": "application/json" } : {}),
      ...init.headers,
    } });
  }
  return async (effect) => {
    const { notificationId, userId, achievementId } = validateNotification(effect);
    const accessToken = await token();
    const notificationPath = `users/${encodeURIComponent(userId)}/notifications/${encodeURIComponent(notificationId)}`;
    const userPath = `users/${encodeURIComponent(userId)}`;
    const transactionResponse = await request(`${base}:beginTransaction`, accessToken, {
      method: "POST", body: JSON.stringify({ options: { readWrite: {} } }),
    });
    if (!transactionResponse.ok) throw new Error(`ACHIEVEMENT_NOTIFICATION_BEGIN_${transactionResponse.status}`);
    const transaction = (await transactionResponse.json() as { transaction?: string }).transaction;
    if (!transaction) throw new Error("ACHIEVEMENT_NOTIFICATION_TRANSACTION_MISSING");
    async function read(path: string): Promise<FsDocument | null> {
      const response = await request(`${base}/${path}?transaction=${encodeURIComponent(transaction)}`, accessToken);
      if (response.status === 404) return null;
      if (!response.ok) throw new Error(`ACHIEVEMENT_NOTIFICATION_READ_${response.status}`);
      return await response.json() as FsDocument;
    }
    let existing: FsDocument | null;
    let user: FsDocument | null;
    try {
      existing = await read(notificationPath);
      if (existing) {
        await request(`${base}:rollback`, accessToken, {
          method: "POST", body: JSON.stringify({ transaction }),
        });
        return { created: false };
      }
      user = await read(userPath);
      if (!user) throw new Error("ACHIEVEMENT_NOTIFICATION_USER_MISSING");
      const p = effect.payload;
      const metadata = p.metadata && typeof p.metadata === "object" ? p.metadata : { achievementId };
      const notificationFields = {
        type: "achievement_unlocked",
        actorId: userId,
        targetId: achievementId,
        action: "unlocked",
        destination: `/achievements?id=${achievementId}`,
        metadata,
        groupKey: null,
        readAt: null,
        pushWorthy: true,
      };
      const commit = await request(`${base}:commit`, accessToken, {
        method: "POST",
        body: JSON.stringify({
          transaction,
          writes: [
            {
              update: {
                name: prefix + notificationPath,
                fields: Object.fromEntries(Object.entries(notificationFields)
                  .map(([key, value]) => [key, encode(value)])),
              },
              currentDocument: { exists: false },
              updateTransforms: [{ fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" }],
            },
            {
              update: { name: prefix + userPath, fields: {} },
              currentDocument: { exists: true },
              updateTransforms: [{
                fieldPath: "unreadNotificationsCount",
                increment: { integerValue: "1" },
              }],
            },
          ],
        }),
      });
      if (!commit.ok) throw new Error(`ACHIEVEMENT_NOTIFICATION_COMMIT_${commit.status}`);
      return { created: true };
    } catch (error) {
      await request(`${base}:rollback`, accessToken, {
        method: "POST", body: JSON.stringify({ transaction }),
      }).catch(() => undefined);
      throw error;
    }
  };
}

export function createAchievementFcmPushDelivery(
  env: AchievementNotificationEnv,
  dependencies: Dependencies = {},
): (effect: AchievementEffect) => Promise<{ sent: number; noTokens: boolean }> {
  const fetcher = dependencies.fetcher ?? fetch;
  const base = baseUrl(env.FIREBASE_PROJECT_ID);
  async function token(): Promise<string> {
    if (dependencies.getAccessToken) return dependencies.getAccessToken([DATASTORE_SCOPE, FCM_SCOPE]);
    return getGoogleAccessToken(
      env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
      env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
      [DATASTORE_SCOPE, FCM_SCOPE], fetcher,
    );
  }
  return async (effect) => {
    const { userId, achievementId } = validateNotification({
      ...effect,
      kind: "in_app_notification",
      id: achievementEffectId(effect.userId, effect.achievementId, "in_app_notification"),
      payload: {
        id: `achievement-${effect.userId}-${effect.achievementId}`,
        type: "achievement_unlocked",
        targetId: effect.achievementId,
        action: "unlocked",
        destination: `/achievements?id=${effect.achievementId}`,
        recipientIds: [effect.userId],
      },
    });
    if (effect.kind !== "fcm_push" ||
        effect.eventId !== achievementEventId(userId, achievementId) ||
        effect.id !== achievementEffectId(userId, achievementId, "fcm_push") ||
        effect.payload.notificationId !== `achievement-${userId}-${achievementId}` ||
        typeof effect.payload.title !== "string" || effect.payload.title.length > 100 ||
        typeof effect.payload.body !== "string" || effect.payload.body.length > 200) {
      throw new Error("ACHIEVEMENT_FCM_INVALID_EFFECT");
    }
    const accessToken = await token();
    const query = await fetcher(`${base}:runQuery`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "fcmTokens", allDescendants: true }],
          where: { fieldFilter: {
            field: { fieldPath: "uid" }, op: "EQUAL", value: { stringValue: userId },
          } },
          limit: MAX_TOKENS,
        },
      }),
    });
    if (!query.ok) throw new Error(`ACHIEVEMENT_FCM_TOKEN_QUERY_${query.status}`);
    const rows = await query.json() as Array<{ document?: FsDocument }>;
    const tokens = [...new Set(rows.map((row) => {
      const fields = Object.fromEntries(Object.entries(row.document?.fields ?? {})
        .map(([key, value]) => [key, decode(value)]));
      return typeof fields.token === "string" && fields.token.length <= 4096
        ? fields.token : null;
    }).filter((value): value is string => value !== null))];
    if (tokens.length === 0) return { sent: 0, noTokens: true };
    let sent = 0;
    for (const deviceToken of tokens) {
      const response = await fetcher(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/messages:send`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
          body: JSON.stringify({
            message: {
              token: deviceToken,
              notification: {
                title: effect.payload.title as string,
                body: effect.payload.body as string,
              },
              data: {
                type: "achievement_unlocked",
                destination: `/achievements?id=${achievementId}`,
                targetId: achievementId,
                notificationId: `achievement-${userId}-${achievementId}`,
              },
            },
          }),
        },
      );
      if (!response.ok) throw new Error(`ACHIEVEMENT_FCM_SEND_${response.status}`);
      sent += 1;
    }
    return { sent, noTokens: false };
  };
}
