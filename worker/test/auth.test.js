import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  verifyFirebaseIdToken,
  readBearerToken,
  authenticate,
  resetJwksCache,
  AuthError,
} from '../src/auth.js';
import { createSigner, jwksFetcher } from './helpers/harness.js';

let signer;
let fetcher;

beforeEach(async () => {
  signer = await createSigner();
  fetcher = jwksFetcher(signer.jwk);
  resetJwksCache();
});

test('accepts a well-formed token and returns the uid', async () => {
  const token = await signer.signToken({ sub: 'alice' });
  const payload = await verifyFirebaseIdToken(token, {
    projectId: 'pubget-aaf27',
    fetcher,
  });
  assert.equal(payload.uid, 'alice');
  assert.equal(payload.isAdmin, false);
});

test('surfaces the admin claim', async () => {
  const token = await signer.signToken({ sub: 'root', admin: true });
  const payload = await verifyFirebaseIdToken(token, {
    projectId: 'pubget-aaf27',
    fetcher,
  });
  assert.equal(payload.isAdmin, true);
});

test('rejects a token signed by a different key', async () => {
  const other = await createSigner();
  const token = await other.signToken();
  await assert.rejects(
    () => verifyFirebaseIdToken(token, { projectId: 'pubget-aaf27', fetcher }),
    (error) => error instanceof AuthError && /signature/i.test(error.message),
  );
});

test('rejects a wrong audience', async () => {
  const token = await signer.signToken({ aud: 'some-other-project' });
  await assert.rejects(
    () => verifyFirebaseIdToken(token, { projectId: 'pubget-aaf27', fetcher }),
    (error) => /audience/i.test(error.message),
  );
});

test('rejects a wrong issuer', async () => {
  const token = await signer.signToken({ iss: 'https://evil.example.com' });
  await assert.rejects(
    () => verifyFirebaseIdToken(token, { projectId: 'pubget-aaf27', fetcher }),
    (error) => /issuer/i.test(error.message),
  );
});

test('rejects an expired token', async () => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const token = await signer.signToken({ iat: nowSeconds - 7200, exp: nowSeconds - 3600 });
  await assert.rejects(
    () => verifyFirebaseIdToken(token, { projectId: 'pubget-aaf27', fetcher }),
    (error) => /expired/i.test(error.message),
  );
});

test('rejects a malformed token', async () => {
  await assert.rejects(
    () => verifyFirebaseIdToken('not-a-jwt', { projectId: 'pubget-aaf27', fetcher }),
    (error) => error instanceof AuthError && error.status === 401,
  );
});

test('reads the bearer token', () => {
  const request = new Request('https://example.com', {
    headers: { Authorization: 'Bearer abc.def.ghi' },
  });
  assert.equal(readBearerToken(request), 'abc.def.ghi');
  assert.equal(readBearerToken(new Request('https://example.com')), null);
});

test('authenticate requires a token', async () => {
  await assert.rejects(
    () => authenticate(new Request('https://example.com'), { projectId: 'pubget-aaf27', fetcher }),
    (error) => /Authentication required/i.test(error.message),
  );
});
