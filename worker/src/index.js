// Authenticated media gateway in front of the `pubget-media` R2 bucket.
//
// Routes
//   GET    /healthz              liveness + whether presigning is configured
//   POST   /upload?kind=…        authenticated proxied upload (binding)
//   GET    /presign?kind=…       authenticated short-lived presigned PUT (S3 API)
//   GET    /media/<key>          public read: redirect (preferred) or stream
//   DELETE /media/<key>          authenticated delete, owner only
//   GET    /list?kind=…          authenticated listing of the caller's objects
//
// Auth is a Firebase ID token (Authorization: Bearer …), verified against
// Google's public JWKS. See auth.js.

import { authenticate, AuthError } from './auth.js';
import { createRateLimiter, RATE_LIMITS } from './ratelimit.js';
import { buildKey, parseKey, keyOwnedBy } from './keys.js';
import { KINDS } from './kinds.js';
import { matchesDeclaredKind } from './sniff.js';
import { presignPut } from './sigv4.js';
import {
  validateUploadRequest,
  validateStoredObject,
} from './validation.js';
import {
  json,
  errorResponse,
  corsHeaders,
  preflight,
  readConfig,
  presignConfigured,
} from './http.js';
import {
  IMMUTABLE_CACHE_CONTROL,
  contentTypeFor,
  parseRange,
} from './read.js';

const PRESIGN_TTL_SECONDS = 15 * 60;
const MAX_LIST_LIMIT = 200;

const limiter = createRateLimiter();

function newUuid() {
  return crypto.randomUUID();
}

/** First non-empty string of [primary]/[fallback], else ''. */
function fieldOr(primary, fallback) {
  if (typeof primary === 'string' && primary.length > 0) return primary;
  if (typeof fallback === 'string' && fallback.length > 0) return fallback;
  return '';
}

function rateLimitOrResponse(request, config, action, uid) {
  const spec = RATE_LIMITS[action];
  const limit =
    action === 'presign'
      ? config.presignPerMinute
      : action === 'upload'
        ? config.uploadsPerHour
        : config.listPerMinute;
  const result = limiter.check(`${action}:${uid}`, limit, spec.windowSeconds);
  if (result.allowed) return null;
  return errorResponse(429, 'Too many requests. Please slow down.', {
    retryAfterSeconds: result.retryAfterSeconds,
    headers: { 'Retry-After': String(result.retryAfterSeconds) },
  });
}

async function handleHealth(env, config) {
  return json({ ok: true, presignConfigured: presignConfigured(config) });
}

async function handlePresign(request, env, config) {
  const { uid } = await authenticate(request, { projectId: config.projectId });
  const limited = rateLimitOrResponse(request, config, 'presign', uid);
  if (limited) return limited;

  if (!presignConfigured(config)) {
    return errorResponse(
      501,
      'Direct uploads are not enabled on this server yet.',
    );
  }

  const url = new URL(request.url);
  const kind = url.searchParams.get('kind') || '';
  const contentType = url.searchParams.get('contentType') || '';
  const ext = url.searchParams.get('ext') || '';
  const sizeBytes = Number.parseInt(url.searchParams.get('sizeBytes') || '', 10);

  const check = validateUploadRequest({
    kind,
    contentType,
    ext,
    sizeBytes,
    env,
    requireSize: true,
  });
  if (!check.ok) return errorResponse(check.status, check.error);

  const key = buildKey({ kind, uid, extension: check.ext, uuid: newUuid() });

  const headers = {
    'content-type': check.contentType,
    'content-length': String(sizeBytes),
    'x-amz-meta-owner-uid': uid,
  };

  const { url: uploadUrl, expiresInSeconds } = await presignPut({
    accountId: config.accountId,
    bucket: config.bucket,
    key,
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
    expiresInSeconds: PRESIGN_TTL_SECONDS,
    headers,
  });

  return json({ key, uploadUrl, headers, expiresInSeconds });
}

async function handleUpload(request, env, config) {
  const { uid } = await authenticate(request, { projectId: config.projectId });
  const limited = rateLimitOrResponse(request, config, 'upload', uid);
  if (limited) return limited;

  const url = new URL(request.url);

  let form;
  try {
    form = await request.formData();
  } catch {
    return errorResponse(400, 'Expected a multipart/form-data body.');
  }
  const file = form.get('file');
  if (!file || typeof file === 'string' || typeof file.arrayBuffer !== 'function') {
    return errorResponse(400, 'Missing file field.');
  }

  // The client sends kind/contentType/ext as form fields; `kind` may also ride
  // in the query string. The file's own Content-Type is only a fallback — some
  // clients send application/octet-stream — the bytes are sniffed below.
  const kind = fieldOr(form.get('kind'), url.searchParams.get('kind'));
  const declaredContentType = fieldOr(form.get('contentType'), file.type || '');
  const declaredExt = fieldOr(
    form.get('ext'),
    (file.name || '').split('.').pop() || '',
  );

  const check = validateUploadRequest({
    kind,
    contentType: declaredContentType,
    ext: declaredExt,
    sizeBytes: file.size,
    env,
    requireSize: true,
  });
  if (!check.ok) return errorResponse(check.status, check.error);

  const stored = validateStoredObject({
    kind,
    contentType: declaredContentType,
    sizeBytes: file.size,
    env,
  });
  if (!stored.ok) return errorResponse(stored.status, stored.error);

  const head = new Uint8Array(await file.slice(0, 32).arrayBuffer());
  const sniffed = matchesDeclaredKind(head, kind);
  if (!sniffed.ok) {
    return errorResponse(415, 'The file contents do not match its type.');
  }

  const key = buildKey({ kind, uid, extension: check.ext, uuid: newUuid() });

  await env.MEDIA.put(key, file.stream(), {
    httpMetadata: { contentType: stored.contentType },
    customMetadata: { 'owner-uid': uid },
  });

  return json({ key, sizeBytes: file.size, contentType: stored.contentType }, { status: 201 });
}

function objectEtag(head) {
  if (head?.httpEtag) return head.httpEtag;
  if (head?.etag) return `"${head.etag}"`;
  return undefined;
}

/** Headers every read response carries, before per-request CORS. */
function readHeaders(key, head) {
  const headers = new Headers();
  headers.set('Content-Type', contentTypeFor(key, head));
  headers.set('Cache-Control', IMMUTABLE_CACHE_CONTROL);
  headers.set('Accept-Ranges', 'bytes');
  const etag = objectEtag(head);
  if (etag) headers.set('ETag', etag);
  return headers;
}

function edgeCacheAvailable() {
  return typeof caches !== 'undefined' && Boolean(caches.default);
}

function withCors(headers, cors) {
  const merged = new Headers(headers);
  for (const [name, value] of Object.entries(cors)) merged.set(name, value);
  return merged;
}

async function handleRead(request, env, config, key, ctx) {
  const parsed = parseKey(key);
  if (!parsed) return errorResponse(400, 'Malformed key.');

  if (config.publicBaseUrl) {
    return Response.redirect(`${config.publicBaseUrl}/${key}`, 302);
  }

  const cors = corsHeaders(request, env);
  const head = await env.MEDIA.head(key);
  if (!head) return errorResponse(404, 'Not found.');
  const size = head.size;

  if (request.method === 'HEAD') {
    const headers = withCors(readHeaders(key, head), cors);
    headers.set('Content-Length', String(size));
    return new Response(null, { status: 200, headers });
  }

  const range = parseRange(request.headers.get('Range'), size);
  if (range && range.unsatisfiable) {
    const headers = withCors(readHeaders(key, head), cors);
    headers.set('Content-Range', `bytes */${size}`);
    return new Response(null, { status: 416, headers });
  }

  if (range) {
    const object = await env.MEDIA.get(key, {
      range: { offset: range.offset, length: range.length },
    });
    if (!object) return errorResponse(404, 'Not found.');
    const headers = withCors(readHeaders(key, head), cors);
    headers.set('Content-Range', `bytes ${range.offset}-${range.end}/${size}`);
    headers.set('Content-Length', String(range.length));
    return new Response(object.body, { status: 206, headers });
  }

  // Full body: try the edge cache so repeat reads never touch the bucket.
  const cacheable = edgeCacheAvailable();
  const cacheKey = cacheable
    ? new Request(
        `${new URL(request.url).origin}/__media-cache/${encodeURIComponent(key)}`,
        { method: 'GET' },
      )
    : null;
  if (cacheable) {
    const cached = await caches.default.match(cacheKey).catch(() => null);
    if (cached) {
      return new Response(cached.body, {
        status: cached.status,
        headers: withCors(cached.headers, cors),
      });
    }
  }

  const object = await env.MEDIA.get(key);
  if (!object) return errorResponse(404, 'Not found.');

  const headers = withCors(readHeaders(key, head), cors);
  headers.set('Content-Length', String(size));
  const response = new Response(object.body, { status: 200, headers });

  if (cacheable && ctx?.waitUntil) {
    const toStore = new Response(response.clone().body, {
      status: 200,
      headers: readHeaders(key, head),
    });
    ctx.waitUntil(caches.default.put(cacheKey, toStore).catch(() => undefined));
  }
  return response;
}

async function handleDelete(request, env, config, key) {
  const { uid, isAdmin } = await authenticate(request, { projectId: config.projectId });
  const parsed = parseKey(key);
  if (!parsed) return errorResponse(400, 'Malformed key.');

  if (!isAdmin && !keyOwnedBy(key, uid)) {
    // Not the owner: pretend there is nothing to delete rather than
    // confirming the object exists.
    return errorResponse(404, 'Not found.');
  }

  const object = await env.MEDIA.head(key);
  if (!object) return errorResponse(404, 'Not found.');

  const owner = object.customMetadata?.['owner-uid'];
  if (!isAdmin && owner && owner !== uid) {
    return errorResponse(404, 'Not found.');
  }

  await env.MEDIA.delete(key);
  return new Response(null, { status: 204, headers: corsHeaders(request, env) });
}

async function handleList(request, env, config) {
  const { uid, isAdmin } = await authenticate(request, { projectId: config.projectId });
  const limited = rateLimitOrResponse(request, config, 'list', uid);
  if (limited) return limited;

  const url = new URL(request.url);
  const kind = url.searchParams.get('kind') || '';
  const spec = KINDS[kind];
  if (!spec) return errorResponse(400, 'Unknown media kind.');

  const requestedOwner = url.searchParams.get('ownerUid');
  if (requestedOwner && requestedOwner !== uid && !isAdmin) {
    return errorResponse(403, 'Not allowed.');
  }
  const owner = requestedOwner || uid;

  const limitRaw = Number.parseInt(url.searchParams.get('limit') || '', 10);
  const limit = Number.isFinite(limitRaw)
    ? Math.min(Math.max(limitRaw, 1), MAX_LIST_LIMIT)
    : 50;
  const cursor = url.searchParams.get('cursor') || undefined;

  const listed = await env.MEDIA.list({
    prefix: `${spec.folder}/${owner}/`,
    limit,
    cursor,
  });

  const items = listed.objects.map((object) => ({
    key: object.key,
    sizeBytes: object.size,
    uploadedAt: object.uploaded?.toISOString?.() ?? null,
    etag: object.etag,
  }));

  return json({
    items,
    cursor: listed.truncated ? listed.cursor : null,
  });
}

export default {
  async fetch(request, env, ctx) {
    const config = readConfig(env);

    if (request.method === 'OPTIONS') {
      return preflight(request, env);
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';

    try {
      if (path === '/healthz' && request.method === 'GET') {
        return await handleHealth(env, config);
      }
      if (path === '/presign' && request.method === 'GET') {
        return await handlePresign(request, env, config);
      }
      if (path === '/upload' && request.method === 'POST') {
        return await handleUpload(request, env, config);
      }
      if (path === '/list' && request.method === 'GET') {
        return await handleList(request, env, config);
      }
      if (path.startsWith('/media/')) {
        const key = decodeURIComponent(path.slice('/media/'.length));
        if (request.method === 'GET' || request.method === 'HEAD') {
          return await handleRead(request, env, config, key, ctx);
        }
        if (request.method === 'DELETE') {
          return await handleDelete(request, env, config, key);
        }
        return errorResponse(405, 'Method not allowed.');
      }
      return errorResponse(404, 'Not found.');
    } catch (error) {
      if (error instanceof AuthError) {
        return errorResponse(error.status, error.message);
      }
      console.error('media worker error:', error && error.stack ? error.stack : error);
      return errorResponse(500, 'Internal error.');
    }
  },
};
