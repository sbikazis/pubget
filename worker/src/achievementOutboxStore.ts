import { getGoogleAccessToken } from "./firebaseAuth";
import {
  AchievementEffect,
  AchievementOutboxEvent,
  claimAchievementEffect,
  completeAchievementEffect,
  refreshAchievementEvent,
  retryAchievementEffect,
} from "./achievementOutbox";

export interface AchievementOutboxEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

type FsValue = Record<string, unknown>;
type FsDocument = { name: string; fields?: Record<string, FsValue> };
type DecodedEvent = AchievementOutboxEvent & { path: string };

export interface AchievementOutboxStore {
  listCandidateEvents(limit: number): Promise<string[]>;
  claimNextEffect(path: string, workerId: string, now: number, leaseMs: number): Promise<AchievementEffect | null>;
  markDelivered(path: string, effectId: string, workerId: string, now: number): Promise<void>;
  markRetry(path: string, effectId: string, workerId: string, now: number, errorCode: string): Promise<void>;
}

interface StoreDependencies {
  fetcher?: typeof fetch;
  getAccessToken?: (env: AchievementOutboxEnv) => Promise<string>;
  maxTransactionAttempts?: number;
}

const DATASTORE_SCOPE = "https://www.googleapis.com/auth/datastore";
const COLLECTION = "achievement_outbox";
const MAX_PAGE_SIZE = 100;
const MAX_SCAN_DOCUMENTS = 1000;
const DEFAULT_TRANSACTION_ATTEMPTS = 5;
const BASE_RETRY_DELAY_MS = 5_000;
const MAX_RETRY_DELAY_MS = 6 * 60 * 60 * 1000;

function encode(value: unknown): FsValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Invalid Firestore numeric value.");
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (typeof value === "object") {
    const fields: Record<string, FsValue> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      if (item !== undefined) fields[key] = encode(item);
    }
    return { mapValue: { fields } };
  }
  throw new Error("Unsupported Firestore outbox value.");
}

function decode(value?: FsValue): unknown {
  if (!value) return null;
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("mapValue" in value) {
    const fields = (value.mapValue as { fields?: Record<string, FsValue> }).fields ?? {};
    return Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, decode(item)]));
  }
  if ("arrayValue" in value) {
    return ((value.arrayValue as { values?: FsValue[] }).values ?? []).map(decode);
  }
  return null;
}

function decodeDocument(document: FsDocument): DecodedEvent {
  const fields = Object.fromEntries(
    Object.entries(document.fields ?? {}).map(([key, item]) => [key, decode(item)]),
  ) as Record<string, unknown>;
  const id = document.name.split("/").pop() ?? "";
  const userId = String(fields.userId ?? "");
  const achievementId = String(fields.achievementId ?? "");
  const rawEffects = Array.isArray(fields.effects) ? fields.effects : [];
  const effects = rawEffects.map((raw) => {
    const item = raw as Record<string, unknown>;
    return {
      ...item,
      eventId: id,
      userId,
      achievementId,
      id: String(item.id ?? ""),
      kind: item.kind as AchievementEffect["kind"],
      status: item.status as AchievementEffect["status"],
      attempts: Number(item.attempts ?? 0),
      payload: (item.payload && typeof item.payload === "object" ? item.payload : {}) as Record<string, unknown>,
    } as AchievementEffect;
  });
  return {
    id,
    path: document.name,
    userId,
    achievementId,
    status: fields.status as AchievementOutboxEvent["status"],
    effects,
    createdAt: typeof fields.createdAt === "number" ? fields.createdAt : 0,
    ...(typeof fields.completedAt === "number" ? { completedAt: fields.completedAt } : {}),
  };
}

function cleanEffect(effect: AchievementEffect): Record<string, unknown> {
  return Object.fromEntries(Object.entries(effect).filter(([, value]) => value !== undefined));
}

export function createFirestoreAchievementOutboxStore(
  env: AchievementOutboxEnv,
  dependencies: StoreDependencies = {},
): AchievementOutboxStore {
  const fetcher = dependencies.fetcher ?? fetch;
  const transactionAttempts = dependencies.maxTransactionAttempts ?? DEFAULT_TRANSACTION_ATTEMPTS;
  const base = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents`;

  async function accessToken(): Promise<string> {
    if (dependencies.getAccessToken) return dependencies.getAccessToken(env);
    if (!env.FIRESTORE_SERVICE_ACCOUNT_EMAIL || !env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY) {
      throw new Error("Firestore service credentials are not configured.");
    }
    return getGoogleAccessToken(
      env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
      env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
      [DATASTORE_SCOPE],
      fetcher,
    );
  }

  async function request(url: string, token: string, init: RequestInit = {}): Promise<Response> {
    return fetcher(url, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(init.body ? { "content-type": "application/json" } : {}),
        ...init.headers,
      },
    });
  }

  async function begin(token: string): Promise<string> {
    const response = await request(`${base}:beginTransaction`, token, {
      method: "POST",
      body: JSON.stringify({ options: { readWrite: {} } }),
    });
    if (!response.ok) throw new Error(`OUTBOX_BEGIN_TRANSACTION_${response.status}`);
    const body = await response.json() as { transaction?: string };
    if (!body.transaction) throw new Error("OUTBOX_TRANSACTION_ID_MISSING");
    return body.transaction;
  }

  async function readInTransaction(path: string, token: string, transaction: string): Promise<FsDocument | null> {
    const url = `${base}/${path}?transaction=${encodeURIComponent(transaction)}`;
    const response = await request(url, token);
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`OUTBOX_READ_${response.status}`);
    return await response.json() as FsDocument;
  }

  async function commit(
    token: string,
    transaction: string,
    path: string,
    fields: Record<string, unknown>,
  ): Promise<void> {
    const response = await request(`${base}:commit`, token, {
      method: "POST",
      body: JSON.stringify({
        transaction,
        writes: [{
          update: {
            name: path,
            fields: Object.fromEntries(
              Object.entries(fields).map(([key, item]) => [key, encode(item)]),
            ),
          },
          updateMask: { fieldPaths: ["effects", "status", "completedAt"] },
        }],
      }),
    });
    if (response.status === 409 || response.status === 400) {
      const body = await response.text();
      if (/ABORTED|FAILED_PRECONDITION|transaction/i.test(body)) {
        throw new Error("OUTBOX_TRANSACTION_CONFLICT");
      }
    }
    if (!response.ok) throw new Error(`OUTBOX_COMMIT_${response.status}`);
  }

  async function transact<T>(
    path: string,
    update: (event: DecodedEvent) => { fields: Record<string, unknown>; result: T } | null,
  ): Promise<T | null> {
    const token = await accessToken();
    for (let attempt = 0; attempt < transactionAttempts; attempt += 1) {
      const transaction = await begin(token);
      const document = await readInTransaction(path, token, transaction);
      if (!document) return null;
      const event = decodeDocument(document);
      const change = update(event);
      if (!change) return null;
      try {
        await commit(token, transaction, path, change.fields);
        return change.result;
      } catch (error) {
        if (!(error instanceof Error) || error.message !== "OUTBOX_TRANSACTION_CONFLICT" ||
            attempt === transactionAttempts - 1) throw error;
      }
    }
    return null;
  }

  async function listCandidateEvents(limit: number): Promise<string[]> {
    if (!Number.isSafeInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) {
      throw new Error("Invalid outbox scan limit.");
    }
    const token = await accessToken();
    const paths: string[] = [];
    let pageToken = "";
    let scanned = 0;
    while (scanned < MAX_SCAN_DOCUMENTS && paths.length < limit) {
      const url = new URL(`${base}/${COLLECTION}`);
      url.searchParams.set("pageSize", String(Math.min(MAX_PAGE_SIZE, MAX_SCAN_DOCUMENTS - scanned)));
      if (pageToken) url.searchParams.set("pageToken", pageToken);
      const response = await request(url.toString(), token);
      if (!response.ok) throw new Error(`OUTBOX_LIST_${response.status}`);
      const body = await response.json() as { documents?: FsDocument[]; nextPageToken?: string };
      const documents = body.documents ?? [];
      scanned += documents.length;
      for (const document of documents) {
        const event = decodeDocument(document);
        if (event.status !== "completed" && event.effects.some((effect) =>
          effect.status !== "delivered")) {
          paths.push(document.name);
          if (paths.length >= limit) break;
        }
      }
      pageToken = body.nextPageToken ?? "";
      if (!pageToken || documents.length === 0) break;
    }
    return paths;
  }

  async function claimNextEffect(
    path: string,
    workerId: string,
    now: number,
    leaseMs: number,
  ): Promise<AchievementEffect | null> {
    if (!workerId || workerId.length > 128) throw new Error("Invalid outbox worker identity.");
    return transact(path, (event) => {
      if (event.status === "completed") return null;
      for (let index = 0; index < event.effects.length; index += 1) {
        const claimed = claimAchievementEffect(event.effects[index], workerId, now, leaseMs);
        if (!claimed) continue;
        const effects = [...event.effects];
        effects[index] = claimed;
        const refreshed = refreshAchievementEvent(event, effects, now);
        return {
          fields: {
            effects: effects.map(cleanEffect),
            status: refreshed.status,
            ...(refreshed.completedAt !== undefined ? { completedAt: refreshed.completedAt } : {}),
          },
          result: claimed,
        };
      }
      return null;
    });
  }

  async function mutateEffect(
    path: string,
    effectId: string,
    workerId: string,
    now: number,
    mutation: (effect: AchievementEffect) => AchievementEffect,
  ): Promise<void> {
    const result = await transact(path, (event) => {
      const index = event.effects.findIndex((effect) => effect.id === effectId);
      if (index < 0) return null;
      const effects = [...event.effects];
      effects[index] = mutation(effects[index]);
      const refreshed = refreshAchievementEvent(event, effects, now);
      return {
        fields: {
          effects: effects.map(cleanEffect),
          status: refreshed.status,
          ...(refreshed.completedAt !== undefined ? { completedAt: refreshed.completedAt } : {}),
        },
        result: true,
      };
    });
    if (result === null) throw new Error("OUTBOX_EFFECT_NOT_FOUND_OR_LEASE_LOST");
  }

  return {
    listCandidateEvents,
    claimNextEffect,
    async markDelivered(path, effectId, workerId, now) {
      await mutateEffect(path, effectId, workerId, now, (effect) =>
        completeAchievementEffect(effect, workerId, now));
    },
    async markRetry(path, effectId, workerId, now, errorCode) {
      await mutateEffect(path, effectId, workerId, now, (effect) =>
        retryAchievementEffect(
          effect, workerId, now, errorCode, BASE_RETRY_DELAY_MS, MAX_RETRY_DELAY_MS,
        ));
    },
  };
}

export interface AchievementOutboxBatchResult {
  scanned: number;
  claimed: number;
  delivered: number;
  retried: number;
  skipped: number;
}

/**
 * The dispatcher is deliberately injected. Reward, in-app notification and
 * FCM handlers are implemented in separate rollout steps; this batch runner
 * only owns durable claiming, leases, completion and retry bookkeeping.
 */
export async function runAchievementOutboxBatch(input: {
  store: AchievementOutboxStore;
  workerId: string;
  now?: () => number;
  batchSize?: number;
  leaseMs?: number;
  deliver: (effect: AchievementEffect) => Promise<void>;
}): Promise<AchievementOutboxBatchResult> {
  const now = input.now ?? Date.now;
  const batchSize = input.batchSize ?? 25;
  const leaseMs = input.leaseMs ?? 120_000;
  const paths = await input.store.listCandidateEvents(batchSize);
  const result: AchievementOutboxBatchResult = {
    scanned: paths.length, claimed: 0, delivered: 0, retried: 0, skipped: 0,
  };

  for (const path of paths) {
    const claimedAt = now();
    const effect = await input.store.claimNextEffect(path, input.workerId, claimedAt, leaseMs);
    if (!effect) {
      result.skipped += 1;
      continue;
    }
    result.claimed += 1;
    try {
      await input.deliver(effect);
      await input.store.markDelivered(path, effect.id, input.workerId, now());
      result.delivered += 1;
    } catch (error) {
      const code = error instanceof Error ? error.name || "delivery_error" : "delivery_error";
      try {
        await input.store.markRetry(path, effect.id, input.workerId, now(), code);
        result.retried += 1;
      } catch {
        // If the lease expired or Firestore is unavailable, leave it processing.
        // A later worker recovers it after leaseUntil; never overwrite another lease.
        result.skipped += 1;
      }
    }
  }
  return result;
}
