import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import { resetJwksCache } from '../src/auth.js';
import {
  createSigner,
  jwksFetcher,
  createFakeBucket,
  fileFrom,
  JPEG_HEAD,
} from './helpers/harness.js';

const BASE = 'https://media.example.com';
const PROJECT = 'pubget-aaf27';

let signer;
let bucket;
let env;
let realFetch;

beforeEach(async () => {
  signer = await createSigner();
  bucket = createFakeBucket();
  env = {
    MEDIA: bucket,
    FIREBASE_PROJECT_ID: PROJECT,
    ALLOWED_ORIGINS: 'https://pubget-aaf27.web.app',
  };
  realFetch = globalThis.fetch;
  globalThis.fetch = jwksFetcher(signer.jwk);
  resetJwksCache();
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

function withEnv(overrides) {
  return { ...env, ...overrides };
}

async function token(overrides = {}) {
  return signer.signToken(overrides);
}

async function upload(kind, bytes, name, type, { token: bearer, env: requestEnv = env } = {}) {
  const form = new FormData();
  form.set('file', fileFrom(bytes, name, type));
  const headers = bearer ? { Authorization: `Bearer ${bearer}` } : {};
  const request = new Request(`${BASE}/upload?kind=${kind}`, {
    method: 'POST',
    headers,
    body: form,
  });
  return worker.fetch(request, requestEnv);
}

test('healthz reports readiness and presign capability', async () => {
  const response = await worker.fetch(new Request(`${BASE}/healthz`), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(body.presignConfigured, false);
});

test('unknown routes 404', async () => {
  const response = await worker.fetch(new Request(`${BASE}/nope`), env);
  assert.equal(response.status, 404);
});

test('upload requires authentication', async () => {
  const response = await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg');
  assert.equal(response.status, 401);
});

test('upload stores under images/<uid>/ with owner metadata', async () => {
  const bearer = await token({ sub: 'alice' });
  const response = await upload('image', JPEG_HEAD, 'holiday.jpg', 'image/jpeg', {
    token: bearer,
  });
  assert.equal(response.status, 201);
  const body = await response.json();
  assert.match(body.key, /^images\/alice\/[0-9a-f-]{36}\.jpg$/);

  const stored = bucket.objects.get(body.key);
  assert.ok(stored, 'object was written');
  assert.equal(stored.httpMetadata.contentType, 'image/jpeg');
  assert.equal(stored.customMetadata['owner-uid'], 'alice');
});

test('upload uses the id, not the client file name', async () => {
  const bearer = await token({ sub: 'alice' });
  const response = await upload('image', JPEG_HEAD, '../../evil.jpg', 'image/jpeg', {
    token: bearer,
  });
  assert.equal(response.status, 201);
  const { key } = await response.json();
  assert.ok(!key.includes('evil'));
  assert.ok(!key.includes('..'));
});

test('upload accepts the Flutter client shape (form fields, octet-stream file)', async () => {
  const bearer = await token({ sub: 'alice' });
  const form = new FormData();
  form.set('kind', 'image');
  form.set('contentType', 'image/jpeg');
  form.set('ext', 'jpg');
  form.set('file', fileFrom(JPEG_HEAD, 'upload.jpg', 'application/octet-stream'));

  const response = await worker.fetch(
    new Request(`${BASE}/upload`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${bearer}` },
      body: form,
    }),
    env,
  );
  assert.equal(response.status, 201);
  const { key } = await response.json();
  assert.match(key, /^images\/alice\/[0-9a-f-]{36}\.jpg$/);
  assert.equal(bucket.objects.get(key).httpMetadata.contentType, 'image/jpeg');
});

test('upload rejects bytes that do not match the declared type', async () => {
  const bearer = await token({ sub: 'alice' });
  const html = new TextEncoder().encode('<html><script>alert(1)</script></html>');
  const response = await upload('image', html, 'x.jpg', 'image/jpeg', { token: bearer });
  assert.equal(response.status, 415);
});

test('upload rejects a disallowed content type', async () => {
  const bearer = await token({ sub: 'alice' });
  const response = await upload('image', JPEG_HEAD, 'x.svg', 'image/svg+xml', {
    token: bearer,
  });
  assert.equal(response.status, 415);
});

test('upload enforces the reels size ceiling', async () => {
  const bearer = await token({ sub: 'alice' });
  const big = new Uint8Array(5 * 1024 * 1024 + 1);
  big.set([0x1a, 0x45, 0xdf, 0xa3]);
  const response = await upload('reels', big, 'clip.webm', 'video/webm', { token: bearer });
  assert.equal(response.status, 413);
});

test('delete removes the owner\'s object', async () => {
  const bearer = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: bearer })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${bearer}` },
    }),
    env,
  );
  assert.equal(response.status, 204);
  assert.equal(bucket.objects.has(key), false);
});

test('delete of another user\'s object is a 404 and leaves it in place', async () => {
  const alice = await token({ sub: 'alice' });
  const bob = await token({ sub: 'bob' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${bob}` },
    }),
    env,
  );
  assert.equal(response.status, 404);
  assert.equal(bucket.objects.has(key), true);
});

test('list only returns the caller\'s objects', async () => {
  const alice = await token({ sub: 'alice' });
  const bob = await token({ sub: 'bob' });
  await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice });
  await upload('image', JPEG_HEAD, 'b.jpg', 'image/jpeg', { token: bob });

  const response = await worker.fetch(
    new Request(`${BASE}/list?kind=image`, { headers: { Authorization: `Bearer ${alice}` } }),
    env,
  );
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.items.length, 1);
  assert.match(body.items[0].key, /^images\/alice\//);
});

test('list refuses to read another user\'s prefix', async () => {
  const bob = await token({ sub: 'bob' });
  const response = await worker.fetch(
    new Request(`${BASE}/list?kind=image&ownerUid=alice`, {
      headers: { Authorization: `Bearer ${bob}` },
    }),
    env,
  );
  assert.equal(response.status, 403);
});

test('media read streams with the stored content type', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(new Request(`${BASE}/media/${key}`), env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'image/jpeg');
  assert.equal(
    response.headers.get('Cache-Control'),
    'public, max-age=31536000, immutable',
  );
  assert.equal(response.headers.get('Accept-Ranges'), 'bytes');
  const body = new Uint8Array(await response.arrayBuffer());
  assert.deepEqual([...body], [...JPEG_HEAD]);
});

test('media read falls back to the extension for the content type', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();
  bucket.objects.get(key).httpMetadata = {};

  const response = await worker.fetch(new Request(`${BASE}/media/${key}`), env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Type'), 'image/jpeg');
});

test('media read answers a byte range with 206 and Content-Range', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, { headers: { Range: 'bytes=2-4' } }),
    env,
  );
  assert.equal(response.status, 206);
  assert.equal(response.headers.get('Content-Range'), `bytes 2-4/${JPEG_HEAD.length}`);
  assert.equal(response.headers.get('Content-Length'), '3');
  assert.equal(response.headers.get('Accept-Ranges'), 'bytes');
  const body = new Uint8Array(await response.arrayBuffer());
  assert.deepEqual([...body], [...JPEG_HEAD.slice(2, 5)]);
});

test('media read answers a suffix range (last N bytes)', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, { headers: { Range: 'bytes=-2' } }),
    env,
  );
  assert.equal(response.status, 206);
  assert.equal(
    response.headers.get('Content-Range'),
    `bytes ${JPEG_HEAD.length - 2}-${JPEG_HEAD.length - 1}/${JPEG_HEAD.length}`,
  );
});

test('media read rejects an out-of-range byte range with 416', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, { headers: { Range: 'bytes=9999-' } }),
    env,
  );
  assert.equal(response.status, 416);
  assert.equal(response.headers.get('Content-Range'), `bytes */${JPEG_HEAD.length}`);
});

test('HEAD returns the size and type without a body', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`, { method: 'HEAD' }),
    env,
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Content-Length'), String(JPEG_HEAD.length));
  assert.equal(response.headers.get('Content-Type'), 'image/jpeg');
});

test('media read 404s for a missing object', async () => {
  const response = await worker.fetch(
    new Request(`${BASE}/media/images/alice/missing.jpg`),
    env,
  );
  assert.equal(response.status, 404);
});

test('media read redirects when a public base URL is configured', async () => {
  const alice = await token({ sub: 'alice' });
  const { key } = await (await upload('image', JPEG_HEAD, 'a.jpg', 'image/jpeg', { token: alice })).json();

  const response = await worker.fetch(
    new Request(`${BASE}/media/${key}`),
    withEnv({ PUBLIC_BASE_URL: 'https://media.mydomain.com/' }),
  );
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('Location'), `https://media.mydomain.com/${key}`);
});

test('media read rejects a malformed key', async () => {
  const response = await worker.fetch(new Request(`${BASE}/media/not-a-key`), env);
  assert.equal(response.status, 400);
});

test('presign is 501 until R2 credentials are configured', async () => {
  const alice = await token({ sub: 'alice' });
  const response = await worker.fetch(
    new Request(`${BASE}/presign?kind=image&contentType=image/jpeg&ext=jpg&sizeBytes=1000`, {
      headers: { Authorization: `Bearer ${alice}` },
    }),
    env,
  );
  assert.equal(response.status, 501);
});

test('presign returns a signed URL and the exact required headers', async () => {
  const alice = await token({ sub: 'alice' });
  const response = await worker.fetch(
    new Request(`${BASE}/presign?kind=reels&contentType=video/mp4&ext=mp4&sizeBytes=1000`, {
      headers: { Authorization: `Bearer ${alice}` },
    }),
    withEnv({ R2_ACCOUNT_ID: 'acct', R2_ACCESS_KEY_ID: 'AKID', R2_SECRET_ACCESS_KEY: 'SECRET' }),
  );
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.match(body.key, /^reels\/alice\/[0-9a-f-]{36}\.mp4$/);
  assert.ok(body.uploadUrl.includes('X-Amz-Signature='));
  assert.equal(body.headers['content-length'], '1000');
  assert.equal(body.headers['x-amz-meta-owner-uid'], 'alice');
  assert.equal(body.expiresInSeconds, 900);
});

test('presign refuses an oversized reels request', async () => {
  const alice = await token({ sub: 'alice' });
  const response = await worker.fetch(
    new Request(`${BASE}/presign?kind=reels&contentType=video/mp4&ext=mp4&sizeBytes=9999999`, {
      headers: { Authorization: `Bearer ${alice}` },
    }),
    withEnv({ R2_ACCOUNT_ID: 'acct', R2_ACCESS_KEY_ID: 'AKID', R2_SECRET_ACCESS_KEY: 'SECRET' }),
  );
  assert.equal(response.status, 413);
});

test('an invalid token is rejected before any work happens', async () => {
  const response = await worker.fetch(
    new Request(`${BASE}/list?kind=image`, { headers: { Authorization: 'Bearer nope' } }),
    env,
  );
  assert.equal(response.status, 401);
});
