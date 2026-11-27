import { verifyFirebaseIdToken } from "./firebaseAuth";
import { createFirestoreGateway, FieldValue } from "./firestoreGateway";
import { CallableError } from "./coreReads";
import economyModule from "../../functions/src/economyDomain.js";
import achievementsModule from "../../functions/src/achievementsDomain.js";
import groupChatModule from "../../functions/src/groupChat.js";
import privateChatModule from "../../functions/src/privateChat.js";
import socialGraphModule from "../../functions/src/socialGraph.js";
import groupsDomainModule from "../../functions/src/groupsDomain.js";
import animeCatalogModule from "../../functions/src/animeCatalogDomain.js";

// The callable bridge owns the HTTP mapping for domain errors, so expose the
// error class its tests use to simulate domain failures.
export { CallableError };

const { createEconomyDomain } = economyModule as any;
const { createAchievementsDomain } = achievementsModule as any;
const { createGroupChat } = groupChatModule as any;
const { createPrivateChat } = privateChatModule as any;
const { createSocialGraph } = socialGraphModule as any;
const { createGroupsDomain } = groupsDomainModule as any;
const { createAnimeCatalogDomain } = animeCatalogModule as any;

const CORS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "Authorization, Content-Type",
};

export interface CallableEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
  MEDIA_BUCKET?: R2Bucket;
}

type VerifiedIdentity = { uid: string; claims?: Record<string, unknown> };
type CallableFunction = (request: {
  auth: { uid: string; token: Record<string, unknown> };
  data: Record<string, unknown>;
}) => Promise<unknown>;

export interface CallableDependencies {
  verifyToken?: (
    token: string,
    projectId: string,
  ) => Promise<VerifiedIdentity | null>;
  createDb?: (env: CallableEnv) => Promise<unknown>;
  createDomains?: (db: unknown, env: CallableEnv) => Record<string, CallableFunction>;
}

const GROUP_CHAT_ROUTES: Record<string, string> = {
  sendGroupMessage: "sendMessage",
  editGroupMessage: "editMessage",
  deleteGroupMessage: "deleteMessage",
  pinGroupMessage: "pinMessage",
  addGroupMessageReaction: "addReaction",
  markGroupMessagesRead: "markMessagesRead",
  markGroupMessagesDelivered: "markMessagesDelivered",
  updateGroupChatBackground: "updateBackground",
  forwardGroupMessage: "forwardMessage",
  reportGroupMessage: "reportMessage",
};

const PRIVATE_CHAT_ROUTES: Record<string, string> = {
  startPrivateChat: "startPrivateChat",
  sendPrivateMessage: "sendPrivateMessage",
  deletePrivateMessage: "deleteMessage",
  editPrivateMessage: "editMessage",
  pinPrivateMessage: "pinMessage",
  addPrivateMessageReaction: "addReaction",
  reportPrivateMessage: "reportMessage",
  markPrivateMessagesRead: "markMessagesRead",
  markPrivateMessagesDelivered: "markMessagesDelivered",
  deletePrivateChat: "deleteChat",
};

const SOCIAL_ROUTES: Record<string, string> = {
  giveRespect: "giveRespect",
  sendFriendRequest: "sendFriendRequest",
  cancelFriendRequest: "cancelFriendRequest",
  respondToFriendRequest: "respondToFriendRequest",
  removeFriend: "removeFriend",
  blockUser: "blockUser",
  unblockUser: "unblockUser",
};

// Group administration callables whose logic already lives in groupsDomain.
// `disbandGroup` is intentionally absent: its Firebase Storage prefix delete
// needs a dedicated Worker route rather than this generic domain bridge.
const GROUP_ADMIN_ROUTES: Record<string, string> = {
  joinGroup: "joinGroup",
  requestToJoin: "requestToJoin",
  leaveGroup: "leaveGroup",
  updateGroupSettings: "updateGroupSettings",
  promoteGroup: "promoteGroup",
  createGroupInvite: "createInvite",
  updateRolePermissions: "updateRolePermissions",
  changeRole: "changeRole",
  kickMember: "kickMember",
  banMember: "banMember",
  transferOwnership: "transferOwnership",
  acceptJoinRequest: "acceptJoinRequest",
  rejectJoinRequest: "rejectJoinRequest",
  unbanMember: "unbanMember",
  warnMember: "warnMember",
  prepareOwnershipTransfer: "prepareOwnershipTransfer",
  reserveRoleplayCharacter: "reserveRoleplayCharacter",
  releaseRoleplayCharacter: "releaseRoleplayCharacter",
  browseAnimeCatalog: "browseAnimeCatalog",
  browseRoleplayCharacters: "browseRoleplayCharacters",
  reservedGroupCharacters: "reservedCharacterKeys",
};

export const CALLABLE_PATH_PREFIX = "/callables/";
export const CALLABLE_ROUTES: Record<string, string> = {
  ...Object.fromEntries(
    Object.entries(GROUP_CHAT_ROUTES).map(([route, method]) => [route, `groupChat.${method}`]),
  ),
  ...Object.fromEntries(
    Object.entries(PRIVATE_CHAT_ROUTES).map(([route, method]) => [route, `privateChat.${method}`]),
  ),
  ...Object.fromEntries(
    Object.entries(SOCIAL_ROUTES).map(([route, method]) => [route, `social.${method}`]),
  ),
  ...Object.fromEntries(
    Object.entries(GROUP_ADMIN_ROUTES).map(([route, method]) => [route, `groups.${method}`]),
  ),
};

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
    case "aborted":
      return 409;
    case "resource-exhausted":
    case "quota-exceeded":
      return 429;
    case "invalid-argument":
    case "failed-precondition":
    case "already-exists":
    case "cancelled":
      return 400;
    default:
      return 503;
  }
}

/** GCS-shaped adapter: the domain only needs `file(key).copy(...)`. */
function createGcsLikeBucket(r2: R2Bucket | undefined) {
  if (!r2) return undefined;
  return {
    file(key: string) {
      return {
        key,
        async copy(destination: { key: string }) {
          await r2.copy(key, destination.key);
        },
      };
    },
  };
}

function defaultDomains(db: unknown, env: CallableEnv): Record<string, CallableFunction> {
  const economy = createEconomyDomain({ db, FieldValue, HttpsError: CallableError });
  const achievements = createAchievementsDomain({
    db,
    economy,
    FieldValue,
    HttpsError: CallableError,
  });
  const groupChat = createGroupChat({
    db,
    FieldValue,
    HttpsError: CallableError,
    bucket: createGcsLikeBucket(env.MEDIA_BUCKET),
    randomUUID: () => crypto.randomUUID(),
    achievements,
  });
  const privateChat = createPrivateChat({
    db,
    FieldValue,
    HttpsError: CallableError,
  });
  const social = createSocialGraph({
    db,
    FieldValue,
    HttpsError: CallableError,
    achievements,
  });
  const catalog = createAnimeCatalogDomain({ db });
  const groups = createGroupsDomain({
    db,
    FieldValue,
    HttpsError: CallableError,
    randomUUID: () => crypto.randomUUID(),
    achievements,
    catalog,
  });
  return { groupChat, privateChat, social, groups };
}

/**
 * Authenticated bridge for write callables that used to require Firebase
 * Functions. The domain modules are imported unchanged from `functions/src`,
 * so request/response contracts cannot drift from the old callables.
 */
export function createCallableHandler(dependencies: CallableDependencies = {}) {
  const verifyToken = dependencies.verifyToken ?? (async (token, projectId) => {
    const result = await verifyFirebaseIdToken(token, projectId);
    return result ? { uid: result.uid, claims: result.claims } : null;
  });
  const createDb = dependencies.createDb ?? (async (env) => createFirestoreGateway(env));
  const makeDomains = dependencies.createDomains ?? defaultDomains;

  return async function handleCallablesRequest(
    request: Request,
    env: CallableEnv,
  ): Promise<Response | null> {
    const path = new URL(request.url).pathname;
    if (!path.startsWith(CALLABLE_PATH_PREFIX)) return null;
    const name = path.slice(CALLABLE_PATH_PREFIX.length);
    if (!Object.hasOwn(CALLABLE_ROUTES, name)) {
      return json({ error: "Unknown callable route.", code: "not-found" }, 404);
    }
    if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

    const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) {
      return json({ error: "Authentication required.", code: "unauthenticated" }, 401);
    }
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
      const domains = makeDomains(db, env);
      const [domainName, method] = CALLABLE_ROUTES[name].split(".");
      const domain = domains[domainName];
      if (!domain || typeof domain[method] !== "function") {
        return json({ error: "Callable is not available.", code: "unavailable" }, 503);
      }
      const data = await domain[method]({
        auth: { uid: identity.uid, token: identity.claims ?? {} },
        data: payload,
      });
      // Match the Worker's other JSON routes: the domain result is the body.
      return json(data ?? {});
    } catch (error) {
      if (error instanceof CallableError) {
        const status = statusForCode(error.code);
        return json(
          {
            error: status >= 500 ? "Callable request failed." : error.message,
            code: error.code,
          },
          status,
        );
      }
      console.error("Callable request failed", error);
      return json({ error: "Callable request failed." }, 503);
    }
  };
}

export const handleCallablesRequest = createCallableHandler();
