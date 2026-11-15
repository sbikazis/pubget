const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const CLOCK_SKEW_SECONDS = 60;
const MAX_ASSERTION_SECONDS = 3600;

type FirebaseClaims = {
  aud?: unknown;
  iss?: unknown;
  sub?: unknown;
  exp?: unknown;
  iat?: unknown;
  auth_time?: unknown;
};

type JwkSet = { keys: Array<JsonWebKey & { kid?: string }> };
let jwksCache: { keys: JwkSet; expiresAt: number } | undefined;
let jwksRequest: Promise<JwkSet> | undefined;
const accessTokenCache = new Map<string, { token: string; expiresAt: number }>();

function decodeBase64Url(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("Invalid base64url.");
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(normalized + "=".repeat((4 - normalized.length % 4) % 4));
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

function encodeBase64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function getFirebaseJwks(fetcher: typeof fetch, forceRefresh = false): Promise<JwkSet> {
  const now = Date.now();
  if (!forceRefresh && jwksCache && jwksCache.expiresAt > now) return jwksCache.keys;
  if (!forceRefresh && jwksRequest) return jwksRequest;

  jwksRequest = (async () => {
    const response = await fetcher(FIREBASE_JWKS_URL, { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error("Firebase signing keys unavailable.");
    const body = await response.json() as JwkSet;
    if (!Array.isArray(body.keys) || body.keys.length === 0) {
      throw new Error("Firebase signing keys response is invalid.");
    }
    const cacheControl = response.headers.get("cache-control") ?? "";
    const maxAge = Number(cacheControl.match(/(?:^|, )max-age=(\d+)/i)?.[1] ?? 300);
    jwksCache = { keys: body, expiresAt: Date.now() + Math.max(60, Math.min(maxAge, 3600)) * 1000 };
    return body;
  })();

  try {
    return await jwksRequest;
  } finally {
    jwksRequest = undefined;
  }
}

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
  fetcher: typeof fetch = fetch,
  nowSeconds = Math.floor(Date.now() / 1000),
  maxAuthAgeSeconds?: number,
): Promise<{ uid: string; claims: FirebaseClaims } | null> {
  try {
    const parts = token.split(".");
    if (parts.length !== 3 || parts.some((part) => !part)) return null;
    const header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0]))) as {
      alg?: string; kid?: string; typ?: string;
    };
    if (header.alg !== "RS256" || typeof header.kid !== "string" || !header.kid) return null;

    const claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1]))) as FirebaseClaims;
    const validNumericClaim = (value: unknown): value is number =>
      typeof value === "number" && Number.isSafeInteger(value);
    if (
      claims.aud !== projectId ||
      claims.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof claims.sub !== "string" || claims.sub.length === 0 || claims.sub.length > 128 ||
      !validNumericClaim(claims.exp) || claims.exp <= nowSeconds - CLOCK_SKEW_SECONDS ||
      !validNumericClaim(claims.iat) || claims.iat > nowSeconds + CLOCK_SKEW_SECONDS ||
      !validNumericClaim(claims.auth_time) || claims.auth_time > nowSeconds + CLOCK_SKEW_SECONDS ||
      claims.auth_time > claims.iat + CLOCK_SKEW_SECONDS
    ) return null;
    if (maxAuthAgeSeconds !== undefined &&
        (!Number.isSafeInteger(maxAuthAgeSeconds) || maxAuthAgeSeconds < 0 ||
         nowSeconds - (claims.auth_time as number) > maxAuthAgeSeconds + CLOCK_SKEW_SECONDS)) {
      return null;
    }

    let keys = await getFirebaseJwks(fetcher);
    let jwk = keys.keys.find((key) => key.kid === header.kid);
    if (!jwk) {
      keys = await getFirebaseJwks(fetcher, true);
      jwk = keys.keys.find((key) => key.kid === header.kid);
    }
    if (!jwk) return null;

    const publicKey = await crypto.subtle.importKey(
      "jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"],
    );
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", publicKey, decodeBase64Url(parts[2]),
      new TextEncoder().encode(parts[0] + "." + parts[1]),
    );
    return valid ? { uid: claims.sub, claims } : null;
  } catch {
    return null;
  }
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN [A-Z ]+-----|-----END [A-Z ]+-----|\s/g, "");
  return decodeBase64(body);
}

function decodeBase64(value: string): Uint8Array {
  const raw = atob(value);
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

export async function getGoogleAccessToken(
  serviceAccountEmail: string,
  privateKeyPem: string,
  scopes: string[],
  fetcher: typeof fetch = fetch,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<string> {
  const allowedScopes = new Set([
    "https://www.googleapis.com/auth/datastore",
    "https://www.googleapis.com/auth/devstorage.read_only",
  ]);
  if (!serviceAccountEmail.includes("@") || !privateKeyPem ||
      scopes.length === 0 || scopes.some((scope) => !allowedScopes.has(scope))) {
    throw new Error("Invalid service account OAuth configuration.");
  }
  const normalizedScopes = [...new Set(scopes)].sort();
  const cacheKey = serviceAccountEmail + "|" + normalizedScopes.join(" ");
  const cached = accessTokenCache.get(cacheKey);
  if (cached && cached.expiresAt > nowSeconds + 60) return cached.token;

  const assertionHeader = encodeBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const assertionClaims = encodeBase64Url(JSON.stringify({
    iss: serviceAccountEmail,
    scope: normalizedScopes.join(" "),
    aud: GOOGLE_TOKEN_URL,
    iat: nowSeconds,
    exp: nowSeconds + MAX_ASSERTION_SECONDS,
  }));
  const unsigned = assertionHeader + "." + assertionClaims;
  const privateKey = await crypto.subtle.importKey(
    "pkcs8", pemToBytes(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", privateKey, new TextEncoder().encode(unsigned),
  ));
  const assertion = unsigned + "." + encodeBase64Url(signature);
  const response = await fetcher(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("Google OAuth token exchange failed.");
  const body = await response.json() as { access_token?: string; expires_in?: number; token_type?: string };
  if (typeof body.access_token !== "string" || !body.access_token ||
      typeof body.expires_in !== "number" || body.expires_in <= 0 ||
      body.token_type?.toLowerCase() !== "bearer") {
    throw new Error("Google OAuth token response is invalid.");
  }
  accessTokenCache.set(cacheKey, {
    token: body.access_token,
    expiresAt: nowSeconds + Math.min(body.expires_in, MAX_ASSERTION_SECONDS),
  });
  return body.access_token;
}

export const FIREBASE_SIGNING_KEYS_URL = FIREBASE_JWKS_URL;
export const GOOGLE_OAUTH_TOKEN_URL = GOOGLE_TOKEN_URL;
