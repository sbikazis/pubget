import { verifyFirebaseIdToken } from "./firebaseAuth";
import { createFirestoreGateway } from "./firestoreGateway";
import economyDomainModule from "../../functions/src/economyDomain.js";
import achievementsDomainModule from "../../functions/src/achievementsDomain.js";
import recommendationModule from "../../functions/src/recommendationEngine.js";

const { createEconomyDomain } = economyDomainModule as any;
const { createAchievementsDomain } = achievementsDomainModule as any;
const { createRecommendationEngine } = recommendationModule as any;

const CORS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, HEAD, POST, OPTIONS",
  "access-control-allow-headers": "Authorization, Content-Type",
};

export interface CoreReadsEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

export class CallableError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = "CallableError";
  }
}

export const CORE_READ_PATHS = {
  economy: "/core/economy",
  transactions: "/core/economy/transactions",
  discovery: "/core/discovery",
  achievements: "/core/achievements",
} as const;

type VerifiedIdentity = { uid: string; claims?: Record<string, unknown> };

export interface CoreReadsDependencies {
  verifyToken?: (
    token: string,
    projectId: string,
  ) => Promise<VerifiedIdentity | null>;
  createDb?: (env: CoreReadsEnv) => Promise<unknown>;
  createEconomy?: (db: unknown, HttpsError: any) => any;
  createAchievements?: (db: unknown, economy: any, HttpsError: any) => any;
  createRecommendations?: (db: unknown) => any;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS },
  });
}

function statusForCode(code: unknown): number {
  switch (typeof code === "string" ? code : "") {
    case "unauthenticated":
      return 401;
    case "permission-denied":
      return 403;
    case "not-found":
      return 404;
    case "invalid-argument":
    case "failed-precondition":
    case "already-exists":
      return 400;
    case "resource-exhausted":
    case "quota-exceeded":
      return 429;
    default:
      return 503;
  }
}

function defaultEconomy(db: unknown, HttpsError: any): any {
  return createEconomyDomain({ db, FieldValue: {}, HttpsError });
}

function defaultAchievements(db: unknown, economy: any, HttpsError: any): any {
  return createAchievementsDomain({
    db,
    economy,
    FieldValue: {},
    HttpsError,
  });
}

function defaultRecommendations(db: unknown): any {
  return createRecommendationEngine({ db, HttpsError: CallableError });
}

/**
 * Read-only migrations of the four callables that failed whenever Firebase
 * Functions billing was unavailable. Domain logic is imported from the
 * existing `functions/src` modules so the JSON contract cannot drift.
 */
export function createCoreReadsHandler(dependencies: CoreReadsDependencies = {}) {
  const verifyToken = dependencies.verifyToken ?? (async (token, projectId) => {
    const result = await verifyFirebaseIdToken(token, projectId);
    return result ? { uid: result.uid, claims: result.claims } : null;
  });
  const createDb = dependencies.createDb ?? (async (env) => createFirestoreGateway(env));
  const makeEconomy = dependencies.createEconomy ?? defaultEconomy;
  const makeAchievements = dependencies.createAchievements ?? defaultAchievements;
  const makeRecommendations = dependencies.createRecommendations ?? defaultRecommendations;

  return async function handleCoreReadsRequest(
    request: Request,
    env: CoreReadsEnv,
  ): Promise<Response | null> {
    const path = new URL(request.url).pathname;
    if (!Object.values(CORE_READ_PATHS).includes(path as any)) return null;
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }

    const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) return json({ error: "Authentication required.", code: "unauthenticated" }, 401);

    let identity: VerifiedIdentity | null;
    try {
      identity = await verifyToken(token, env.FIREBASE_PROJECT_ID);
    } catch {
      return json({ error: "Authentication could not be verified." }, 503);
    }
    if (!identity?.uid) {
      return json({ error: "Authentication required.", code: "unauthenticated" }, 401);
    }

    let payload: Record<string, unknown> = {};
    try {
      const body = await request.text();
      if (body) {
        const decoded = JSON.parse(body);
        if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
          payload = decoded as Record<string, unknown>;
        }
      }
    } catch {
      return json({ error: "Invalid JSON body.", code: "invalid-argument" }, 400);
    }

    try {
      const db = await createDb(env);
      const auth = { uid: identity.uid, token: identity.claims ?? {} };
      const economy = makeEconomy(db, CallableError);
      let data: unknown;

      switch (path) {
        case CORE_READ_PATHS.economy:
          data = await economy.getEconomy({ auth, data: {} });
          break;
        case CORE_READ_PATHS.transactions:
          data = await economy.getEconomyTransactions({ auth, data: {} });
          break;
        case CORE_READ_PATHS.discovery: {
          const discovery = makeRecommendations(db);
          data = await discovery.getDiscoveryFeed({
            auth,
            data: {
              section: payload.section,
              cursor: payload.cursor,
              limit: payload.limit,
            },
          });
          break;
        }
        case CORE_READ_PATHS.achievements: {
          const achievements = makeAchievements(db, economy, CallableError);
          data = await achievements.getAchievements({
            auth,
            data: typeof payload.userId === "string"
              ? { userId: payload.userId }
              : {},
          });
          break;
        }
        default:
          return json({ error: "Unknown core read route." }, 404);
      }
      return json(data);
    } catch (error) {
      if (error instanceof CallableError) {
        const status = statusForCode(error.code);
        return json(
          {
            error: status >= 500 ? "Core read failed." : error.message,
            code: error.code,
          },
          status,
        );
      }
      console.error("Core read failed", error);
      const detail = error instanceof Error ? error.message : String(error);
      return json({ error: `Core read failed: ${detail}` }, 503);
    }
  };
}

export const handleCoreReadsRequest = createCoreReadsHandler();
