// Firebase ID token verification using Google's public JWKS and WebCrypto.
//
// No secret is required to *verify* a Firebase ID token: the tokens are
// RS256-signed and the public keys are published by Google. That is what lets
// this worker authenticate callers without holding any Google credential.
//
// Verified: signature, alg, iss, aud, exp, iat (with small clock skew).
// The caller's uid is `payload.sub`.

export const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const CLOCK_SKEW_SECONDS = 60;
const JWKS_TTL_MS = 60 * 60 * 1000;

let cachedJwks = { keys: null, fetchedAt: 0 };

export class AuthError extends Error {
  constructor(message, status = 401) {
    super(message);
    this.name = 'AuthError';
    this.status = status;
  }
}

function base64UrlToBytes(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/');
  const padding = padded.length % 4 === 0 ? '' : '='.repeat(4 - (padded.length % 4));
  const binary = atob(padded + padding);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJson(segment) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment)));
}

async function loadJwks({ fetcher, now, force }) {
  const fresh = cachedJwks.keys && now - cachedJwks.fetchedAt < JWKS_TTL_MS;
  if (fresh && !force) return cachedJwks.keys;
  const response = await fetcher(FIREBASE_JWKS_URL);
  if (!response.ok) throw new AuthError('Could not load token keys.', 503);
  const body = await response.json();
  if (!body || !Array.isArray(body.keys)) {
    throw new AuthError('Token key set is malformed.', 503);
  }
  cachedJwks = { keys: body.keys, fetchedAt: now };
  return body.keys;
}

/** Clears the JWKS cache — test/ops helper. */
export function resetJwksCache() {
  cachedJwks = { keys: null, fetchedAt: 0 };
}

/**
 * Verifies a Firebase ID token and returns its payload (with `uid`).
 *
 * @param {string} token
 * @param {object} options
 * @param {string} options.projectId
 * @param {typeof fetch} [options.fetcher]
 * @param {() => number} [options.now]   epoch ms, injectable for tests
 */
export async function verifyFirebaseIdToken(token, { projectId, fetcher = fetch, now = Date.now }) {
  if (typeof token !== 'string' || token.split('.').length !== 3) {
    throw new AuthError('Missing or malformed token.');
  }
  const [headerSegment, payloadSegment, signatureSegment] = token.split('.');

  let header;
  let payload;
  try {
    header = decodeJson(headerSegment);
    payload = decodeJson(payloadSegment);
  } catch {
    throw new AuthError('Missing or malformed token.');
  }

  if (header.alg !== 'RS256') throw new AuthError('Unsupported token algorithm.');

  const header64 = `${headerSegment}.${payloadSegment}`;
  const signature = base64UrlToBytes(signatureSegment);
  const data = new TextEncoder().encode(header64);

  const verifyWithKey = async (jwk) => {
    const key = await crypto.subtle.importKey(
      'jwk',
      jwk,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    return crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, signature, data);
  };

  let keys = await loadJwks({ fetcher, now: now() });
  let jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) {
    keys = await loadJwks({ fetcher, now: now(), force: true });
    jwk = keys.find((k) => k.kid === header.kid);
  }
  if (!jwk) throw new AuthError('Unknown token signing key.');

  const signatureValid = await verifyWithKey(jwk);
  if (!signatureValid) throw new AuthError('Invalid token signature.');

  const seconds = Math.floor(now() / 1000);
  if (payload.aud !== projectId) throw new AuthError('Token audience mismatch.');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new AuthError('Token issuer mismatch.');
  }
  if (typeof payload.exp !== 'number' || payload.exp <= seconds - CLOCK_SKEW_SECONDS) {
    throw new AuthError('Token expired.');
  }
  if (typeof payload.iat !== 'number' || payload.iat > seconds + CLOCK_SKEW_SECONDS) {
    throw new AuthError('Token not yet valid.');
  }
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new AuthError('Token has no subject.');
  }

  return { ...payload, uid: payload.sub, isAdmin: payload.admin === true };
}

/** Extracts `Authorization: Bearer <token>` or returns null. */
export function readBearerToken(request) {
  const header = request.headers.get('Authorization') || '';
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/**
 * Authenticates a request. Returns the verified payload or throws AuthError.
 */
export async function authenticate(request, { projectId, fetcher, now }) {
  const token = readBearerToken(request);
  if (!token) throw new AuthError('Authentication required.');
  return verifyFirebaseIdToken(token, { projectId, fetcher, now });
}
