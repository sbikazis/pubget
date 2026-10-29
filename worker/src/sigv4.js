// AWS Signature Version 4, query-string variant, for presigned PUTs to R2.
//
// R2's presigned URLs are an S3 API feature: signing requires an R2 API token
// (access key id + secret). Those live only as worker secrets and are never
// sent to the app. This module is dependency-free: it uses WebCrypto, so it
// runs both in a Worker and under `node --test`.

const ALGORITHM = 'AWS4-HMAC-SHA256';
const SERVICE = 's3';

function toBytes(input) {
  if (typeof input === 'string') return new TextEncoder().encode(input);
  return input instanceof Uint8Array ? input : new Uint8Array(input);
}

async function sha256Hex(input) {
  const digest = await crypto.subtle.digest('SHA-256', toBytes(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function hmac(keyBytes, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    toBytes(keyBytes),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, toBytes(message));
  return new Uint8Array(signature);
}

async function signingKey(secretAccessKey, dateStamp) {
  const kDate = await hmac(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = await hmac(kDate, 'auto');
  const kService = await hmac(kRegion, SERVICE);
  return hmac(kService, 'aws4_request');
}

/** RFC 3986 encoding; `/` is preserved when `keepSlash` is true. */
export function uriEncode(value, keepSlash = false) {
  const encoded = encodeURIComponent(value).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  return keepSlash ? encoded.replace(/%2F/g, '/') : encoded;
}

function canonicalQueryString(params) {
  return Object.keys(params)
    .sort()
    .map((key) => `${uriEncode(key)}=${uriEncode(String(params[key]))}`)
    .join('&');
}

/** `2026-10-17T12:34:56Z` -> `{ amzDate: '20261017T123456Z', dateStamp: '20261017' }` */
export function formatAmzDate(date) {
  const iso = date.toISOString().replace(/[:-]|\.\d{3}/g, '');
  return { amzDate: iso, dateStamp: iso.slice(0, 8) };
}

/**
 * Builds the canonical request string. Exported so tests can assert it
 * against a hand-written expectation.
 */
export function buildCanonicalRequest({ method, path, query, headers, signedHeaders }) {
  const canonicalHeaders = signedHeaders
    .map((name) => `${name}:${String(headers[name]).trim().replace(/\s+/g, ' ')}\n`)
    .join('');
  return [
    method,
    path,
    canonicalQueryString(query),
    canonicalHeaders,
    signedHeaders.join(';'),
    'UNSIGNED-PAYLOAD',
  ].join('\n');
}

/**
 * Creates a presigned PUT URL.
 *
 * `headers` are the values the uploader MUST send verbatim; they are part of
 * the signature, so a client cannot upload a different content type, a
 * different size (when Content-Length is signed), or claim another owner.
 *
 * @param {object} input
 * @param {string} input.accountId
 * @param {string} input.bucket
 * @param {string} input.key            `images/<uid>/<uuid>.<ext>`
 * @param {string} input.accessKeyId
 * @param {string} input.secretAccessKey
 * @param {number} input.expiresInSeconds
 * @param {Record<string,string>} input.headers  e.g. { 'content-type', 'content-length', 'x-amz-meta-owner-uid' }
 * @param {Date} [input.date]
 */
export async function presignPut({
  accountId,
  bucket,
  key,
  accessKeyId,
  secretAccessKey,
  expiresInSeconds,
  headers,
  date = new Date(),
}) {
  const host = `${accountId}.r2.cloudflarestorage.com`;
  const { amzDate, dateStamp } = formatAmzDate(date);
  const scope = `${dateStamp}/auto/${SERVICE}/aws4_request`;

  const signedHeaders = ['host', ...Object.keys(headers)].sort();
  const allHeaders = { host, ...headers };

  const query = {
    'X-Amz-Algorithm': ALGORITHM,
    'X-Amz-Credential': `${accessKeyId}/${scope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': String(expiresInSeconds),
    'X-Amz-SignedHeaders': signedHeaders.join(';'),
  };

  const path = `/${bucket}/${key.split('/').map((s) => uriEncode(s)).join('/')}`;
  const canonicalRequest = buildCanonicalRequest({
    method: 'PUT',
    path,
    query,
    headers: allHeaders,
    signedHeaders,
  });

  const stringToSign = [
    ALGORITHM,
    amzDate,
    scope,
    await sha256Hex(canonicalRequest),
  ].join('\n');

  const key_ = await signingKey(secretAccessKey, dateStamp);
  const signatureBytes = await hmac(key_, stringToSign);
  const signature = [...signatureBytes].map((b) => b.toString(16).padStart(2, '0')).join('');

  const finalQuery = canonicalQueryString({ ...query, 'X-Amz-Signature': signature });
  return {
    url: `https://${host}${path}?${finalQuery}`,
    host,
    signedHeaders,
    expiresInSeconds,
    signature,
  };
}
