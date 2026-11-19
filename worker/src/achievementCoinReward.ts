import { getGoogleAccessToken } from "./firebaseAuth";
import { AchievementEffect } from "./achievementOutbox";

export interface AchievementCoinRewardEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

export interface AchievementCoinRewardResult {
  applied: boolean;
  reason?: string;
  amount?: number;
  balanceAfter?: number;
  balance?: number;
  transactionId?: string;
  version?: number;
}

interface Dependencies {
  fetcher?: typeof fetch;
  getAccessToken?: (env: AchievementCoinRewardEnv) => Promise<string>;
  now?: () => Date;
  maxTransactionAttempts?: number;
}

type FirestoreValue = Record<string, unknown>;
type FirestoreDocument = { name: string; fields?: Record<string, FirestoreValue> };

const REWARD_TYPE = "earn_achievement";
const REWARD_AMOUNT = 5;
const MAX_GRANT = 1_000;
const MAX_BALANCE = 1_000_000_000;
const MAX_ID = 128;
const DAILY_CAP = 9;
const SCHEMA_VERSION = 1;
const SCOPE = "https://www.googleapis.com/auth/datastore";
const MAX_TRANSACTION_ATTEMPTS = 5;

function validId(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= MAX_ID;
}

function safeInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) ? value : null;
}

function encode(value: unknown): FirestoreValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Invalid Firestore number.");
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === "object") {
    return { mapValue: { fields: Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([, item]) => item !== undefined)
        .map(([key, item]) => [key, encode(item)]),
    ) } };
  }
  throw new Error("Unsupported Firestore value.");
}

function decode(value?: FirestoreValue): unknown {
  if (!value) return null;
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("mapValue" in value) {
    const fields = (value.mapValue as { fields?: Record<string, FirestoreValue> }).fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, decode(item)]));
  }
  return null;
}

function decodeFields(document: FirestoreDocument | null): Record<string, unknown> | null {
  if (!document) return null;
  return Object.fromEntries(Object.entries(document.fields ?? {})
    .map(([key, value]) => [key, decode(value)]));
}

function transactionId(userId: string, referenceId: string): string {
  return `${REWARD_TYPE}_${userId}_${referenceId}`
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 700);
}

export function createAchievementCoinRewardDelivery(
  env: AchievementCoinRewardEnv,
  dependencies: Dependencies = {},
): (effect: AchievementEffect) => Promise<AchievementCoinRewardResult> {
  const fetcher = dependencies.fetcher ?? fetch;
  const clock = dependencies.now ?? (() => new Date());
  const attempts = dependencies.maxTransactionAttempts ?? MAX_TRANSACTION_ATTEMPTS;
  const resourcePrefix = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/`;
  const base = `https://firestore.googleapis.com/v1/${resourcePrefix.slice(0, -1)}`;

  async function token(): Promise<string> {
    if (dependencies.getAccessToken) return dependencies.getAccessToken(env);
    if (!env.FIRESTORE_SERVICE_ACCOUNT_EMAIL || !env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY) {
      throw new Error("Firestore service credentials are not configured.");
    }
    return getGoogleAccessToken(
      env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
      env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
      [SCOPE],
      fetcher,
    );
  }

  async function request(url: string, accessToken: string, init: RequestInit = {}): Promise<Response> {
    return fetcher(url, {
      ...init,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        ...(init.body ? { "content-type": "application/json" } : {}),
        ...init.headers,
      },
    });
  }

  async function begin(accessToken: string): Promise<string> {
    const response = await request(`${base}:beginTransaction`, accessToken, {
      method: "POST",
      body: JSON.stringify({ options: { readWrite: {} } }),
    });
    if (!response.ok) throw new Error(`ECONOMY_BEGIN_TRANSACTION_${response.status}`);
    const body = await response.json() as { transaction?: string };
    if (!body.transaction) throw new Error("ECONOMY_TRANSACTION_ID_MISSING");
    return body.transaction;
  }

  async function read(path: string, accessToken: string, transaction: string): Promise<FirestoreDocument | null> {
    const response = await request(
      `${base}/${path}?transaction=${encodeURIComponent(transaction)}`,
      accessToken,
    );
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`ECONOMY_READ_${response.status}`);
    return await response.json() as FirestoreDocument;
  }

  async function rollback(accessToken: string, transaction: string): Promise<void> {
    await request(`${base}:rollback`, accessToken, {
      method: "POST",
      body: JSON.stringify({ transaction }),
    });
  }

  async function commit(accessToken: string, transaction: string, writes: unknown[]): Promise<void> {
    const response = await request(`${base}:commit`, accessToken, {
      method: "POST",
      body: JSON.stringify({ transaction, writes }),
    });
    if (response.status === 409 || response.status === 400) {
      const body = await response.text();
      if (/ABORTED|FAILED_PRECONDITION|ALREADY_EXISTS|transaction/i.test(body)) {
        throw new Error("ECONOMY_TRANSACTION_CONFLICT");
      }
    }
    if (!response.ok) throw new Error(`ECONOMY_COMMIT_${response.status}`);
  }

  return async (effect: AchievementEffect): Promise<AchievementCoinRewardResult> => {
    if (effect.kind !== "coin_reward" || !validId(effect.userId) ||
        !validId(effect.achievementId) || effect.payload.type !== REWARD_TYPE ||
        effect.payload.referenceId !== effect.achievementId ||
        effect.payload.amount !== REWARD_AMOUNT) {
      throw new Error("ACHIEVEMENT_REWARD_INVALID_EFFECT");
    }
    if (REWARD_AMOUNT <= 0 || REWARD_AMOUNT > MAX_GRANT) {
      throw new Error("ACHIEVEMENT_REWARD_CONFIGURATION_INVALID");
    }

    const userId = effect.userId;
    const referenceId = effect.achievementId;
    const txId = transactionId(userId, referenceId);
    const date = clock().toISOString().slice(0, 10);
    const userPath = `users/${encodeURIComponent(userId)}`;
    const ledgerPath = `economyTransactions/${encodeURIComponent(txId)}`;
    const userTxPath = `${userPath}/transactions/${encodeURIComponent(txId)}`;
    const legacyTxPath = `${userPath}/transactions/${encodeURIComponent(referenceId)}`;
    const dailyPath = `${userPath}/daily_rewards/achievement_${date}`;
    const accessToken = await token();

    for (let attempt = 0; attempt < attempts; attempt += 1) {
      const transaction = await begin(accessToken);
      const [ledgerDoc, userTxDoc, legacyTxDoc, userDoc, dailyDoc] = await Promise.all([
        read(ledgerPath, accessToken, transaction),
        read(userTxPath, accessToken, transaction),
        read(legacyTxPath, accessToken, transaction),
        read(userPath, accessToken, transaction),
        read(dailyPath, accessToken, transaction),
      ]);

      if (ledgerDoc || userTxDoc || legacyTxDoc) {
        const user = decodeFields(userDoc);
        await rollback(accessToken, transaction);
        return {
          applied: false,
          reason: "duplicate",
          transactionId: txId,
          balance: safeInteger(user?.coinsBalance) ?? 0,
        } as AchievementCoinRewardResult;
      }
      const user = decodeFields(userDoc);
      if (!user) {
        await rollback(accessToken, transaction);
        return { applied: false, reason: "user_missing" };
      }
      const daily = decodeFields(dailyDoc);
      const dailyCount = safeInteger(daily?.count) ?? 0;
      if (dailyCount >= DAILY_CAP) {
        await rollback(accessToken, transaction);
        return { applied: false, reason: "daily_cap" };
      }
      const balanceBefore = safeInteger(user.coinsBalance);
      if (balanceBefore === null || balanceBefore < 0) {
        await rollback(accessToken, transaction);
        return { applied: false, reason: "corrupt_balance" };
      }
      const balanceAfter = balanceBefore + REWARD_AMOUNT;
      if (balanceAfter > MAX_BALANCE) {
        await rollback(accessToken, transaction);
        return { applied: false, reason: "overflow" };
      }
      const version = (safeInteger(user.economyVersion) ?? 0) + 1;
      const timestamp = clock().toISOString();
      const record = {
        transactionId: txId,
        userId,
        type: REWARD_TYPE,
        amount: REWARD_AMOUNT,
        balanceBefore,
        balanceAfter,
        source: "achievement",
        referenceId,
        createdAt: timestamp,
        idempotencyKey: txId,
        metadata: {},
        schemaVersion: SCHEMA_VERSION,
      };
      const writes = [
        {
          update: {
            name: `${resourcePrefix}${userPath}`,
            fields: {
              coinsBalance: encode(balanceAfter),
              economyVersion: encode(version),
              economyUpdatedAt: encode(timestamp),
            },
          },
          updateMask: { fieldPaths: ["coinsBalance", "economyVersion", "economyUpdatedAt"] },
          currentDocument: { exists: true },
        },
        {
          update: {
            name: `${resourcePrefix}${ledgerPath}`,
            fields: Object.fromEntries(Object.entries(record).map(([key, value]) => [key, encode(value)])),
          },
          currentDocument: { exists: false },
        },
        {
          update: {
            name: `${resourcePrefix}${userTxPath}`,
            fields: Object.fromEntries(Object.entries(record).map(([key, value]) => [key, encode(value)])),
          },
          currentDocument: { exists: false },
        },
        {
          update: {
            name: `${resourcePrefix}${dailyPath}`,
            fields: {
              count: encode(dailyCount + 1),
              date: encode(date),
              lastUpdate: encode(timestamp),
            },
          },
          updateMask: { fieldPaths: ["count", "date", "lastUpdate"] },
          currentDocument: { exists: Boolean(dailyDoc) },
        },
      ];

      try {
        await commit(accessToken, transaction, writes);
        return {
          applied: true,
          amount: REWARD_AMOUNT,
          balanceAfter,
          transactionId: txId,
          version,
        };
      } catch (error) {
        if (!(error instanceof Error) || error.message !== "ECONOMY_TRANSACTION_CONFLICT" ||
            attempt === attempts - 1) throw error;
      }
    }
    throw new Error("ECONOMY_TRANSACTION_RETRIES_EXHAUSTED");
  };
}

/** Only successful grants and already-committed duplicate grants are complete. */
export async function deliverAchievementCoinReward(
  deliver: (effect: AchievementEffect) => Promise<AchievementCoinRewardResult>,
  effect: AchievementEffect,
): Promise<AchievementCoinRewardResult> {
  const result = await deliver(effect);
  if (result.applied || result.reason === "duplicate") return result;
  throw new Error(`ACHIEVEMENT_REWARD_${result.reason ?? "failed"}`);
}
