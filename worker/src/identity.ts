import { getGoogleAccessToken, verifyFirebaseIdToken } from "./firebaseAuth";

export interface IdentityEnv {
  FIREBASE_PROJECT_ID: string;
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: string;
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: string;
}

type FirestoreValue = Record<string, unknown>;
type FirestoreDocument = { name: string; fields?: Record<string, FirestoreValue>; updateTime?: string };

const USERNAME_RE = /^[\p{L}][\p{L}\p{N}._-]{2,19}$/u;
const DATASTORE_SCOPE = "https://www.googleapis.com/auth/datastore";

function value(input: unknown): FirestoreValue {
  if (input === null) return { nullValue: null };
  if (typeof input === "boolean") return { booleanValue: input };
  if (typeof input === "string") return { stringValue: input };
  if (typeof input === "number") {
    if (!Number.isFinite(input)) throw new Error("Invalid numeric field.");
    return Number.isInteger(input) ? { integerValue: String(input) } : { doubleValue: input };
  }
  if (Array.isArray(input)) return { arrayValue: { values: input.map(value) } };
  if (typeof input === "object") {
    const fields: Record<string, FirestoreValue> = {};
    for (const [key, item] of Object.entries(input as Record<string, unknown>)) fields[key] = value(item);
    return { mapValue: { fields } };
  }
  throw new Error("Unsupported profile value.");
}

function decodeString(document: FirestoreDocument | null, field: string): string {
  return String(document?.fields?.[field]?.stringValue ?? "");
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

export function normalizeUsername(input: unknown): string {
  return typeof input === "string" ? input.trim().toLowerCase() : "";
}

export function validUsername(username: string): boolean {
  return username.length >= 3 && username.length <= 20 && USERNAME_RE.test(username);
}

async function userId(request: Request, env: IdentityEnv): Promise<string | null> {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return null;
  const verified = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
  return verified?.uid ?? null;
}

async function firestoreToken(env: IdentityEnv): Promise<string> {
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

async function readDocument(url: string, token: string, transaction?: string): Promise<FirestoreDocument | null> {
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

async function commit(base: string, token: string, transaction: string, writes: unknown[]): Promise<void> {
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
  }
  if (!result.ok) throw new Error(`Firestore transaction commit failed (${result.status}).`);
}

function userDocument(base: string, uid: string): string {
  return `${base}/users/${encodeURIComponent(uid)}`;
}
function usernameDocument(base: string, username: string): string {
  return `${base}/usernames/${encodeURIComponent(username)}`;
}

export function validateProfile(input: Record<string, unknown>, uid = ''): string | null {
  const allowed = new Set([
    "bio", "favoriteAnimeIds", "favoriteAnimes", "profileVisibility",
    "activityVisibility", "whoCanMessageMe", "username", "displayName",
    "country", "gender", "avatarUrl", "isProfileCompleted", "favoriteQuote",
    "animeTwin", "age", "socialLinks", "sectionPrivacy", "coverUrl", "language",
  ]);
  const keys = Object.keys(input);
  if (!keys.length || keys.some((key) => !allowed.has(key))) return "invalid-profile";

  for (const key of ["bio", "displayName", "country", "favoriteQuote", "animeTwin"]) {
    if (input[key] !== undefined &&
        (typeof input[key] !== "string" ||
         (input[key] as string).length > ({ bio: 500, displayName: 64, country: 64, favoriteQuote: 200, animeTwin: 80 } as Record<string, number>)[key])) {
      return "invalid-profile";
    }
  }
  if (input.avatarUrl !== undefined && input.avatarUrl !== null &&
      (typeof input.avatarUrl !== "string" || input.avatarUrl.length > 2048)) return "invalid-profile";
  if (input.coverUrl !== undefined && input.coverUrl !== null) {
    if (typeof input.coverUrl !== "string" || input.coverUrl.length > 1024) return "invalid-profile";
    const cover = input.coverUrl.trim();
    const isUrl = /^https?:\/\//.test(cover);
    const parts = cover.split("/");
    const isOwnedR2Key = uid.length > 0 && parts.length === 3 &&
      parts[0] === "images" && parts[1] === uid &&
      /^[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp|gif)$/.test(parts[2]);
    if (cover !== "" && !isUrl && !isOwnedR2Key) return "invalid-profile";
  }
  for (const key of ["favoriteAnimeIds", "favoriteAnimes"]) {
    const item = input[key];
    if (item !== undefined && (!Array.isArray(item) || item.length > 50 ||
        item.some((entry) => typeof entry !== "string" || entry.length > (key === "favoriteAnimeIds" ? 128 : 64)))) return "invalid-profile";
  }
  for (const key of ["profileVisibility", "activityVisibility"]) {
    if (input[key] !== undefined && !["public", "private"].includes(String(input[key]))) return "invalid-profile";
  }
  if (input.whoCanMessageMe !== undefined && !["related", "friends"].includes(String(input.whoCanMessageMe))) return "invalid-profile";
  if (input.gender !== undefined && input.gender !== null &&
      !["female", "male", "other", "prefer_not_to_say"].includes(String(input.gender))) return "invalid-profile";
  if (input.isProfileCompleted !== undefined && typeof input.isProfileCompleted !== "boolean") return "invalid-profile";
  if (input.age !== undefined && input.age !== null &&
      (typeof input.age !== "number" || !Number.isInteger(input.age) || input.age < 13 || input.age > 120)) return "invalid-profile";
  if (input.language !== undefined && !["ar", "en"].includes(String(input.language))) return "invalid-profile";
  if (input.socialLinks !== undefined && (!Array.isArray(input.socialLinks) || input.socialLinks.length > 20 ||
      input.socialLinks.some((link) => !link || typeof link !== "object" ||
        typeof (link as Record<string, unknown>).url !== "string" ||
        String((link as Record<string, unknown>).url).trim().length === 0 ||
        String((link as Record<string, unknown>).url).length > 500 ||
        ((link as Record<string, unknown>).label !== undefined &&
          typeof (link as Record<string, unknown>).label !== "string") ||
        ((link as Record<string, unknown>).platform !== undefined &&
          typeof (link as Record<string, unknown>).platform !== "string")))) return "invalid-profile";
  if (input.sectionPrivacy !== undefined && (!input.sectionPrivacy || typeof input.sectionPrivacy !== "object" ||
      Object.values(input.sectionPrivacy as Record<string, unknown>).some((v) => typeof v !== "boolean"))) return "invalid-profile";
  if (input.username !== undefined && !validUsername(normalizeUsername(input.username))) return "invalid-username";
  return null;
}

export async function handleIdentityRequest(request: Request, env: IdentityEnv): Promise<Response | null> {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/identity/")) return null;
  if (request.method !== "POST") return response({ error: "Method not allowed." }, 405);

  const uid = await userId(request, env);
  if (!uid) return response({ error: "Authentication required." }, 401);

  let input: Record<string, unknown>;
  try {
    const parsed = await request.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return response({ error: "Invalid request." }, 400);
    input = parsed as Record<string, unknown>;
  } catch {
    return response({ error: "Invalid JSON." }, 400);
  }

  let serviceToken: string;
  try { serviceToken = await firestoreToken(env); }
  catch { return response({ error: "Identity service is not configured." }, 503); }

  const base = documentsBase(env.FIREBASE_PROJECT_ID);
  if (url.pathname === "/identity/username/check") {
    const normalized = normalizeUsername(input.username);
    if (!validUsername(normalized)) return response({ available: false, normalized, reason: normalized.length < 3 ? "too-short" : "invalid-characters" });
    const claim = await readDocument(usernameDocument(base, normalized), serviceToken);
    const owner = decodeString(claim, "uid");
    return response({ available: !owner || owner === uid, normalized, reason: owner && owner !== uid ? "taken" : null });
  }

  if (url.pathname === "/identity/username/reserve") {
    const normalized = normalizeUsername(input.username);
    if (!validUsername(normalized)) return response({ error: "Username is invalid." }, 400);
    const transaction = await beginTransaction(base, serviceToken);
    const claim = await readDocument(usernameDocument(base, normalized), serviceToken, transaction);
    const owner = decodeString(claim, "uid");
    if (owner && owner !== uid) return response({ error: "Username is already taken." }, 409);
    if (!claim) {
      await commit(base, serviceToken, transaction, [{
        update: {
          name: usernameDocument(base, normalized),
          fields: { uid: value(uid), normalized: value(normalized), claimedAt: value(new Date().toISOString()) },
        },
        currentDocument: { exists: false },
      }]);
    } else {
      await commit(base, serviceToken, transaction, []);
    }
    return response({ normalized, alreadyClaimed: owner === uid });
  }

  if (url.pathname === "/identity/profile/update") {
    const invalid = validateProfile(input, uid);
    if (invalid) return response({ error: invalid }, 400);
    const transaction = await beginTransaction(base, serviceToken);
    const profile = await readDocument(userDocument(base, uid), serviceToken, transaction);
    if (!profile) return response({ error: "Profile not found." }, 404);
    const currentUsername = normalizeUsername(decodeString(profile, "username"));
    const nextUsername = input.username === undefined ? currentUsername : normalizeUsername(input.username);
    if (input.isProfileCompleted === true) {
      const displayName = input.displayName === undefined ? decodeString(profile, "displayName") : String(input.displayName ?? "").trim();
      const avatarUrl = input.avatarUrl === undefined ? decodeString(profile, "avatarUrl") : String(input.avatarUrl ?? "");
      if (!nextUsername || !displayName || !avatarUrl.trim()) return response({ error: "Profile identity fields are required." }, 412);
    }

    const writes: unknown[] = [];
    const mustOwnUsername = input.username !== undefined || input.isProfileCompleted === true;
    if (mustOwnUsername && nextUsername) {
      const claim = await readDocument(usernameDocument(base, nextUsername), serviceToken, transaction);
      const owner = decodeString(claim, "uid");
      if (owner && owner !== uid) return response({ error: "Username is already taken." }, 409);
      if (!claim) writes.push({
        update: { name: usernameDocument(base, nextUsername), fields: {
          uid: value(uid), normalized: value(nextUsername), claimedAt: value(new Date().toISOString()),
        } },
        currentDocument: { exists: false },
      });
    }

    const fields: Record<string, FirestoreValue> = {};
    for (const [key, raw] of Object.entries(input)) {
      let field = raw;
      if (typeof raw === "string" && ["bio", "displayName", "country", "favoriteQuote", "animeTwin", "coverUrl"].includes(key)) field = raw.trim();
      if (key === "username") field = nextUsername;
      if (key === "socialLinks" && Array.isArray(raw)) {
        field = raw.map((item) => {
          const link = item as Record<string, unknown>;
          return {
            url: String(link.url).trim(),
            ...(link.label ? { label: String(link.label).trim() } : {}),
            ...(link.platform ? { platform: String(link.platform).trim() } : {}),
          };
        });
      }
      if (key === "sectionPrivacy" && raw && typeof raw === "object") {
        const privacy = raw as Record<string, unknown>;
        field = {
          favorites: privacy.favorites !== false,
          activity: privacy.activity !== false,
          friends: privacy.friends !== false,
          fans: privacy.fans !== false,
          works: privacy.works !== false,
          groups: privacy.groups !== false,
          ratings: privacy.ratings !== false,
          achievements: privacy.achievements !== false,
        };
      }
      if (key === "isProfileCompleted" && raw === true) {
        fields.hasSkippedOnboarding = value(false);
      }
      fields[key] = value(field);
    }
    if (Object.keys(fields).length) {
      writes.push({
        update: { name: userDocument(base, uid), fields },
        updateMask: { fieldPaths: Object.keys(fields) },
        currentDocument: { exists: true },
      });
    }
    if (currentUsername && currentUsername !== nextUsername) {
      const previousClaim = await readDocument(usernameDocument(base, currentUsername), serviceToken, transaction);
      if (decodeString(previousClaim, "uid") === uid) {
        writes.push({ delete: usernameDocument(base, currentUsername), currentDocument: { exists: true } });
      }
    }
    await commit(base, serviceToken, transaction, writes);
    return response({ ok: true, username: nextUsername || null });
  }

  return response({ error: "Unknown identity operation." }, 404);
}
