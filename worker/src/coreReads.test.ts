import { describe, expect, test, vi } from "vitest";
import {
  CallableError,
  CORE_READ_PATHS,
  createCoreReadsHandler,
} from "./coreReads";

const env = {
  FIREBASE_PROJECT_ID: "pubget-test",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "service@example.com",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "unused",
};

function post(path: string, body?: string, authorized = true): Request {
  return new Request(`https://worker.example${path}`, {
    method: "POST",
    headers: {
      ...(authorized ? { Authorization: "Bearer test-token" } : {}),
      "content-type": "application/json",
    },
    body,
  });
}

function stubDependencies() {
  const seen: any[] = [];
  return {
    seen,
    verifyToken: vi.fn(async () => ({ uid: "alice", claims: { sub: "alice" } })),
    createDb: vi.fn(async () => ({ marker: "db" })),
    createEconomy: vi.fn(() => ({
      getEconomy: vi.fn(async (request: any) => {
        seen.push(["economy", request]);
        return { balance: { userId: request.auth.uid, balance: 42 } };
      }),
      getEconomyTransactions: vi.fn(async (request: any) => {
        seen.push(["transactions", request]);
        return { items: [{ id: "tx1" }] };
      }),
    })),
    createAchievements: vi.fn(() => ({
      getAchievements: vi.fn(async (request: any) => {
        seen.push(["achievements", request]);
        return { items: [{ id: "the_threshold", unlocked: true }] };
      }),
    })),
    createRecommendations: vi.fn(() => ({
      getDiscoveryFeed: vi.fn(async (request: any) => {
        seen.push(["discovery", request]);
        return { coldStart: false, section: request.data.section, items: [] };
      }),
    })),
  };
}

describe("core read Worker routes", () => {
  test("rejects unauthenticated reads before touching Firestore", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(post(CORE_READ_PATHS.economy, undefined, false), env);

    expect(result?.status).toBe(401);
    expect(deps.createDb).not.toHaveBeenCalled();
  });

  test("serves economy and transaction reads with the verified uid", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const economy = await handler(post(CORE_READ_PATHS.economy), env);
    const transactions = await handler(post(CORE_READ_PATHS.transactions), env);

    expect(economy?.status).toBe(200);
    expect(await economy!.json()).toEqual({
      balance: { userId: "alice", balance: 42 },
    });
    expect(transactions?.status).toBe(200);
    expect(await transactions!.json()).toEqual({ items: [{ id: "tx1" }] });
    expect(deps.seen[0][1].auth.uid).toBe("alice");
    expect(deps.seen[1][1].auth.uid).toBe("alice");
  });

  test("forwards only discovery pagination fields", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(
      post(
        CORE_READ_PATHS.discovery,
        JSON.stringify({ section: "recommendedGroups", cursor: "g1", limit: 12, evil: true }),
      ),
      env,
    );

    expect(result?.status).toBe(200);
    expect(deps.seen[0][1].data).toEqual({
      section: "recommendedGroups",
      cursor: "g1",
      limit: 12,
    });
  });

  test("forwards optional achievements viewer id", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(
      post(CORE_READ_PATHS.achievements, JSON.stringify({ userId: "bob" })),
      env,
    );

    expect(result?.status).toBe(200);
    expect(deps.seen[0][1].data).toEqual({ userId: "bob" });
  });

  test("maps callable errors without claiming the device is offline", async () => {
    const deps = stubDependencies();
    deps.createEconomy = vi.fn(() => ({
      getEconomy: vi.fn(async () => {
        throw new CallableError("invalid-argument", "Bad request.");
      }),
    })) as any;
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(post(CORE_READ_PATHS.economy), env);

    expect(result?.status).toBe(400);
    expect(await result!.json()).toMatchObject({ code: "invalid-argument" });
  });

  test("reports invalid JSON as a client error", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(post(CORE_READ_PATHS.economy, "{not-json"), env);

    expect(result?.status).toBe(400);
  });

  test("ignores non-core routes", async () => {
    const deps = stubDependencies();
    const handler = createCoreReadsHandler(deps as any);

    const result = await handler(post("/groups/create"), env);

    expect(result).toBeNull();
    expect(deps.createDb).not.toHaveBeenCalled();
  });
});
