"use strict";

const GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs";

function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(normalized + "=".repeat((4 - normalized.length % 4) % 4));
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

async function authenticateKirariService(
  request,
  expected,
  fetchImpl = fetch,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return false;

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return false;

    const header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1])));
    if (
      header.alg !== "RS256" ||
      typeof header.kid !== "string" ||
      claims.iss !== "https://accounts.google.com" ||
      claims.aud !== expected.audience ||
      claims.email !== expected.serviceAccountEmail ||
      claims.email_verified !== true ||
      typeof claims.sub !== "string" ||
      !claims.sub ||
      !Number.isSafeInteger(claims.iat) ||
      !Number.isSafeInteger(claims.exp) ||
      claims.iat > nowSeconds + 60 ||
      claims.exp <= nowSeconds ||
      claims.exp <= claims.iat ||
      claims.exp - claims.iat > 3600
    ) {
      return false;
    }

    const response = await fetchImpl(GOOGLE_CERTS_URL);
    if (!response.ok) return false;
    const jwks = await response.json();
    const jwk = jwks.keys?.find((key) => key.kid === header.kid);
    if (!jwk) return false;

    const publicKey = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    return crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      decodeBase64Url(parts[2]),
      new TextEncoder().encode(parts[0] + "." + parts[1]),
    );
  } catch {
    return false;
  }
}

module.exports = { authenticateKirariService, GOOGLE_CERTS_URL };
