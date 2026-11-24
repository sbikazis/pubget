import { getGoogleAccessToken, verifyFirebaseIdToken } from "./firebaseAuth";

/**
 * Privileged group creation, migrated from the `createGroup` Firebase callable.
 *
 * The callable is still deployed for backwards compatibility. This route uses
 * the same service-account Firestore transaction as the callable, so no client
 * ever needs privileged write access to `groups/{id}` or its subcollections.
 */

export interface GroupsEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

type FirestoreValue = Record<string, unknown>;
type FirestoreDocument = { name: string; fields?: Record<string, FirestoreValue> };
type Write = {
  update?: { name: string; fields: Record<string, FirestoreValue>; updateMask?: unknown };
  delete?: string;
  currentDocument?: { exists: boolean };
};

const DATASTORE_SCOPE = "https://www.googleapis.com/auth/datastore";
const GROUP_TYPES = ["public", "animeRoleplay", "openRoleplay"];
const ROLEPLAY_TYPES = new Set(["animeRoleplay", "openRoleplay"]);
const JOIN_POLICIES = ["open", "approval", "inviteOnly"];
const ROLES = [
  "ronin", "gokenin", "samurai", "hatamoto", "daimyo", "shogun", "mikado",
] as const;
const ROLE_POSITIONS: Record<string, number> = Object.fromEntries(
  ROLES.map((role, index) => [role, index]),
);
// Mirrors functions/src/pubgetRanks.js:ROLE_PERMISSIONS. The seven role docs
// written at group creation must stay identical to the callable's output.
const ROLE_PERMISSIONS: Record<string, string[]> = {
  ronin: [],
  gokenin: ["invite"],
  samurai: ["invite", "pinOwnMessages", "promoteContent"],
  hatamoto: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
  ],
  daimyo: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "manageBackground",
  ],
  shogun: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "unban", "manageBackground",
    "manageSettings", "manageRoles",
  ],
  mikado: [
    "invite", "pinOwnMessages", "promoteContent",
    "manageRequests", "manageEvents", "moderateChat", "deleteMessages",
    "manageGames", "kickBan", "unban", "manageBackground",
    "manageSettings", "manageRoles",
  ],
};

const DOC_ID_ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

export class GroupInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GroupInputError";
  }
}

export type GroupCharacter = { key: string; name: string; avatarUrl: string };
export type NormalizedGroup = {
  name: string;
  description: string;
  type: string;
  animeId: string | null;
  joinPolicy: string;
  isSearchable: boolean;
  rules: string;
  maxMembers: unknown;
  imageUrl: string;
  coverUrl: string;
  chatBackgroundUrl: string | null;
  welcomeMessage: string | null;
  character: GroupCharacter | null;
  idempotencyKey: string | null;
};

function validString(value: unknown, max: number): value is string {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= max;
}

function optionalUrl(value: unknown, max: number): boolean {
  if (value === undefined || value === null || value === "") return true;
  if (typeof value !== "string" || value.length > max) return false;
  const trimmed = value.trim();
  return /^https?:\/\//i.test(trimmed) && !/\s/.test(trimmed);
}

/** Legacy http(s) URLs or an R2 key owned by the group creator. */
function ownedImageReference(value: unknown, uid: string, max: number): boolean {
  if (value === undefined || value === null || value === "") return true;
  if (typeof value !== "string" || value.length > max) return false;
  const reference = value.trim();
  if (/^https?:\/\//i.test(reference) && !/\s/.test(reference)) return true;
  if (!uid) return false;
  const parts = reference.split("/");
  return parts.length === 3 && parts[0] === "images" && parts[1] === uid &&
    /^[A-Za-z0-9_-]{1,80}\.(?:jpg|jpeg|png|webp|gif)$/.test(parts[2]);
}

function parseCharacter(raw: Record<string, unknown>): GroupCharacter | null {
  const value = raw.character;
  if (value === undefined || value === null || value === "") return null;
  if (!value && raw.characterKey === undefined) return null;
  const source = value && typeof value === "object"
    ? value as Record<string, unknown>
    : raw;
  const key = typeof raw.characterKey === "string"
    ? raw.characterKey
    : source.key;
  const name = source.name;
  const avatarUrl = source.avatarUrl;
  if (!validString(key, 128) || !validString(name, 80) ||
      (avatarUrl !== undefined && avatarUrl !== null &&
       (typeof avatarUrl !== "string" || avatarUrl.length > 500))) {
    throw new GroupInputError("Character details are invalid.");
  }
  return {
    key: (key as string).trim(),
    name: (name as string).trim(),
    avatarUrl: typeof avatarUrl === "string" ? avatarUrl.trim() : "",
  };
}

/** Same validation and normalization as functions/src/groupsDomain.js:groupInput. */
export function validateGroupInput(input: unknown, uid = ""): NormalizedGroup {
  const data = input && typeof input === "object" && !Array.isArray(input)
    ? input as Record<string, unknown>
    : {};
  if (!validString(data.name, 80) || typeof data.description !== "string" ||
      data.description.length > 500 ||
      typeof data.type !== "string" || !GROUP_TYPES.includes(data.type) ||
      typeof data.joinPolicy !== "string" ||
      !JOIN_POLICIES.includes(data.joinPolicy) ||
      typeof data.isSearchable !== "boolean" || typeof data.rules !== "string" ||
      data.rules.length > 4000 ||
      (data.animeId !== null && data.animeId !== undefined &&
       !validString(data.animeId, 128)) ||
      !ownedImageReference(data.imageUrl, uid, 500) ||
      !ownedImageReference(data.coverUrl, uid, 500) ||
      !optionalUrl(data.chatBackgroundUrl, 500) ||
      (data.welcomeMessage !== undefined && data.welcomeMessage !== null &&
       (typeof data.welcomeMessage !== "string" ||
        data.welcomeMessage.length > 500))) {
    throw new GroupInputError("Group details are invalid.");
  }
  if (data.type === "animeRoleplay" && !validString(data.animeId, 128)) {
    throw new GroupInputError("Anime roleplay groups require an animeId.");
  }
  const character = parseCharacter(data);
  if (ROLEPLAY_TYPES.has(String(data.type)) && !character) {
    throw new GroupInputError("Roleplay groups require a founder character.");
  }
  if (data.type === "public" && character) {
    throw new GroupInputError("Public groups cannot reserve a character.");
  }
  const idempotencyKey = validString(data.idempotencyKey, 80)
    ? data.idempotencyKey.trim()
    : null;
  return {
    name: (data.name as string).trim(),
    description: data.description.trim(),
    type: data.type as string,
    animeId: (data.animeId as string | null | undefined) || null,
    joinPolicy: data.joinPolicy as string,
    isSearchable: data.isSearchable as boolean,
    rules: data.rules.trim(),
    maxMembers: data.maxMembers,
    imageUrl: typeof data.imageUrl === "string" && ownedImageReference(data.imageUrl, uid, 500)
      ? data.imageUrl.trim()
      : "",
    coverUrl: typeof data.coverUrl === "string" && ownedImageReference(data.coverUrl, uid, 500)
      ? data.coverUrl.trim()
      : "",
    chatBackgroundUrl: typeof data.chatBackgroundUrl === "string"
      ? data.chatBackgroundUrl.trim()
      : null,
    welcomeMessage: typeof data.welcomeMessage === "string" &&
      data.welcomeMessage.trim().length > 0
      ? data.welcomeMessage.trim()
      : null,
    character,
    idempotencyKey,
  };
}

/** Same entitlement ceiling as groupsDomain.js:entitledMaxMembers. */
export function entitledMaxMembers(userData: Record<string, unknown>): number {
  const custom = Number(userData?.customMaxMembersLimit) || 0;
  if (!Number.isFinite(custom) || custom <= 0) return 100;
  return Math.min(Math.max(Math.trunc(custom), 2), 500);
}

/** Same clamp as groupsDomain.js:resolveMaxMembers. */
export function resolveMaxMembers(
  userData: Record<string, unknown>,
  requested: unknown,
): number {
  const ceiling = entitledMaxMembers(userData);
  const wanted = Number(requested);
  if (!Number.isFinite(wanted)) return ceiling;
  return Math.min(Math.max(Math.trunc(wanted), 2), ceiling);
}

function value(input: unknown): FirestoreValue {
  if (input === null || input === undefined) return { nullValue: null };
  if (input instanceof Date) return { timestampValue: input.toISOString() };
  if (typeof input === "boolean") return { booleanValue: input };
  if (typeof input === "string") return { stringValue: input };
  if (typeof input === "number") {
    if (!Number.isFinite(input)) throw new Error("Invalid numeric field.");
    return Number.isInteger(input)
      ? { integerValue: String(input) }
      : { doubleValue: input };
  }
  if (Array.isArray(input)) return { arrayValue: { values: input.map(value) } };
  if (typeof input === "object") {
    const fields: Record<string, FirestoreValue> = {};
    for (const [key, item] of Object.entries(input as Record<string, unknown>)) {
      fields[key] = value(item);
    }
    return { mapValue: { fields } };
  }
  throw new Error("Unsupported group field.");
}

function decode(input: FirestoreValue | undefined): unknown {
  if (!input) return null;
  if ("stringValue" in input) return input.stringValue;
  if ("booleanValue" in input) return input.booleanValue;
  if ("integerValue" in input) return Number(input.integerValue);
  if ("doubleValue" in input) return Number(input.doubleValue);
  if ("timestampValue" in input) return input.timestampValue;
  if ("nullValue" in input) return null;
  if ("arrayValue" in input) {
    const values = (input.arrayValue as { values?: FirestoreValue[] } | undefined)?.values;
    return (values ?? []).map(decode);
  }
  if ("mapValue" in input) {
    const fields = (input.mapValue as { fields?: Record<string, FirestoreValue> } | undefined)?.fields;
    return decodeDocument({ name: "", fields });
  }
  return null;
}

function decodeDocument(document: FirestoreDocument | null): Record<string, unknown> {
  const fields = document?.fields ?? {};
  const result: Record<string, unknown> = {};
  for (const [key, field] of Object.entries(fields)) result[key] = decode(field);
  return result;
}

function response(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "Authorization, Content-Type",
      "access-control-allow-methods": "POST, OPTIONS",
      "cache-control": "no-store",
    },
  });
}

async function requestUid(request: Request, env: GroupsEnv): Promise<string | null> {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return null;
  const verified = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
  return verified?.uid ?? null;
}

async function firestoreToken(env: GroupsEnv): Promise<string> {
  if (!env.FIRESTORE_SERVICE_ACCOUNT_EMAIL || !env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY) {
    throw new Error("Firestore service credentials are not configured.");
  }
  return getGoogleAccessToken(
    env.FIRESTORE_SERVICE_ACCOUNT_EMAIL,
    env.FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY.replace(/\\n/g, "\n"),
    [DATASTORE_SCOPE],
  );
}

function documentsBase(projectId: string): string {
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
}

function docUrl(base: string, ...segments: string[]): string {
  return `${base}/${segments.map(encodeURIComponent).join("/")}`;
}

async function readDocument(
  url: string,
  token: string,
  transaction?: string,
): Promise<FirestoreDocument | null> {
  const target = transaction ? `${url}?transaction=${encodeURIComponent(transaction)}` : url;
  const result = await fetch(target, { headers: { Authorization: `Bearer ${token}` } });
  if (result.status === 404) return null;
  if (!result.ok) throw new Error(`Firestore read failed (${result.status}).`);
  return await result.json() as FirestoreDocument;
}

async function beginTransaction(base: string, token: string): Promise<string> {
  const result = await fetch(`${base}:beginTransaction`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ options: { readWrite: {} } }),
  });
  if (!result.ok) throw new Error(`Firestore transaction could not start (${result.status}).`);
  const body = await result.json() as { transaction?: string };
  if (!body.transaction) throw new Error("Firestore returned no transaction identifier.");
  return body.transaction;
}

function isConflict(error: unknown): boolean {
  return error instanceof Error &&
    (error.message === "TRANSACTION_CONFLICT" || error.message.includes("Firestore read failed (409)"));
}

async function commit(
  base: string,
  token: string,
  transaction: string,
  writes: Write[],
): Promise<void> {
  const result = await fetch(`${base}:commit`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ transaction, writes }),
  });
  if (result.status === 409 || result.status === 400) {
    const body = await result.text();
    if (/ABORTED|FAILED_PRECONDITION|ALREADY_EXISTS/i.test(body)) {
      throw new Error("TRANSACTION_CONFLICT");
    }
    throw new Error(`Firestore transaction commit failed (${result.status}): ${body}`);
  }
  if (!result.ok) throw new Error(`Firestore transaction commit failed (${result.status}).`);
}

function newDocumentId(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  return Array.from(bytes, (byte) => DOC_ID_ALPHABET[byte % DOC_ID_ALPHABET.length]).join("");
}

function createWrite(url: string, fields: Record<string, FirestoreValue>): Write {
  return { update: { name: url, fields }, currentDocument: { exists: false } };
}

function roleDefinition(role: string): Record<string, unknown> {
  return {
    name: role,
    permissions: ROLE_PERMISSIONS[role] ?? [],
    position: ROLE_POSITIONS[role] ?? 0,
    isDefault: true,
  };
}

function groupFields(
  uid: string,
  input: NormalizedGroup,
  maxMembers: number,
  now: Date,
): Record<string, FirestoreValue> {
  return value({
    name: input.name,
    searchName: input.name.toLowerCase(),
    description: input.description,
    imageUrl: input.imageUrl,
    coverUrl: input.coverUrl,
    type: input.type,
    animeId: input.animeId,
    founderId: uid,
    migrationVersion: 2,
    membersCount: 1,
    maxMembers,
    joinPolicy: input.joinPolicy,
    isSearchable: input.isSearchable,
    createdAt: now,
    chatBackgroundUrl: input.chatBackgroundUrl,
    welcomeMessage: input.welcomeMessage,
    rules: input.rules,
    activityScore: 0,
    risingEligible: false,
  })["mapValue"]!.fields as Record<string, FirestoreValue>;
}

function memberFields(
  uid: string,
  input: NormalizedGroup,
  now: Date,
): Record<string, FirestoreValue> {
  return value({
    uid,
    role: "mikado",
    rankV2: "mikado",
    customRoleId: null,
    roleplayCharacter: input.character,
    invitedBy: null,
    joinedAt: now,
    inviteCount: 0,
    effectiveInviteCount: 0,
    isManualRole: true,
    seatSource: "manual",
    lastActiveAt: now,
  })["mapValue"]!.fields as Record<string, FirestoreValue>;
}

type CreatePlan = {
  groupId: string;
  writes: Write[];
  reused: boolean;
};

async function planCreate(
  base: string,
  serviceToken: string,
  uid: string,
  input: NormalizedGroup,
  transaction: string,
): Promise<CreatePlan> {
  const lockUrl = input.idempotencyKey
    ? docUrl(base, "users", uid, "groupCreateKeys", input.idempotencyKey)
    : null;
  if (lockUrl) {
    const lock = await readDocument(lockUrl, serviceToken, transaction);
    const existingId = decode(lock?.fields?.groupId);
    if (validString(existingId, 128)) {
      return { groupId: existingId.trim(), writes: [], reused: true };
    }
  }

  const userDoc = await readDocument(docUrl(base, "users", uid), serviceToken, transaction);
  const userData = decodeDocument(userDoc);
  const maxMembers = resolveMaxMembers(userData, input.maxMembers);
  const groupId = newDocumentId();
  const groupUrl = docUrl(base, "groups", groupId);
  const now = new Date();
  const writes: Write[] = [
    createWrite(groupUrl, groupFields(uid, input, maxMembers, now)),
    createWrite(
      docUrl(base, "groups", groupId, "members", uid),
      memberFields(uid, input, now),
    ),
  ];
  if (input.character) {
    writes.push(createWrite(
      docUrl(base, "groups", groupId, "characters", input.character.key),
      value({
        reservedByUid: uid,
        reservedAt: now,
        name: input.character.name,
        avatarUrl: input.character.avatarUrl,
      })["mapValue"]!.fields as Record<string, FirestoreValue>,
    ));
  }
  for (const role of ROLES) {
    writes.push(createWrite(
      docUrl(base, "groups", groupId, "roles", role),
      value(roleDefinition(role))["mapValue"]!.fields as Record<string, FirestoreValue>,
    ));
  }
  if (lockUrl) {
    writes.push(createWrite(lockUrl, value({
      groupId,
      createdAt: now,
    })["mapValue"]!.fields as Record<string, FirestoreValue>));
  }
  // Firestore-triggered consumption keeps the achievement rules in one place
  // (functions/src/achievementsDomain.js) instead of duplicating them here.
  writes.push(createWrite(
    docUrl(base, "achievementEvents", newDocumentId()),
    value({
      type: "group_created",
      userId: uid,
      source: "group",
      metadata: { groupId },
      status: "pending",
      createdAt: now,
    })["mapValue"]!.fields as Record<string, FirestoreValue>,
  ));
  return { groupId, writes, reused: false };
}

async function createGroup(
  uid: string,
  input: NormalizedGroup,
  base: string,
  serviceToken: string,
): Promise<Response> {
  let lastPlan: CreatePlan | null = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const transaction = await beginTransaction(base, serviceToken);
    try {
      const plan = await planCreate(base, serviceToken, uid, input, transaction);
      await commit(base, serviceToken, transaction, plan.writes);
      lastPlan = plan;
      break;
    } catch (error) {
      if (isConflict(error) && attempt < 2) continue;
      if (isConflict(error)) {
        return response({ error: "Group creation changed concurrently. Please retry." }, 409);
      }
      throw error;
    }
  }
  if (!lastPlan) return response({ error: "Group creation could not be completed." }, 503);
  const created = await readDocument(docUrl(base, "groups", lastPlan.groupId), serviceToken);
  if (!created) return response({ error: "Group not found after creation." }, 404);
  return response({
    ok: true,
    groupId: lastPlan.groupId,
    group: decodeDocument(created),
  });
}

/** Handles only the group mutations that used to be privileged callables. */
export async function handleGroupsRequest(
  request: Request,
  env: GroupsEnv,
): Promise<Response | null> {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/groups/")) return null;
  if (request.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }

  const uid = await requestUid(request, env);
  if (!uid) return response({ error: "Authentication required." }, 401);

  let serviceToken: string;
  try { serviceToken = await firestoreToken(env); }
  catch { return response({ error: "Group service is not configured." }, 503); }
  const base = documentsBase(env.FIREBASE_PROJECT_ID);

  if (url.pathname === "/groups/entitlements") {
    const userDoc = await readDocument(docUrl(base, "users", uid), serviceToken);
    const userData = decodeDocument(userDoc);
    return response({
      maxMembers: entitledMaxMembers(userData),
      canCreateGroups: userData.groupsCreatedToday === undefined ||
        Number(userData.groupsCreatedToday) < 5,
    });
  }
  if (url.pathname !== "/groups/create") {
    return response({ error: "Unknown group operation." }, 404);
  }

  let payload: unknown;
  try { payload = await request.json(); }
  catch { return response({ error: "Invalid JSON." }, 400); }
  let input: NormalizedGroup;
  try { input = validateGroupInput(payload, uid); }
  catch (error) {
    return response({
      error: error instanceof Error ? error.message : "Group details are invalid.",
    }, 400);
  }

  try {
    return await createGroup(uid, input, base, serviceToken);
  } catch (error) {
    console.error("Group creation failed", error);
    const detail = error instanceof Error ? error.message : String(error);
    return response({ error: `Group creation failed: ${detail}` }, 503);
  }
}
