import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, createHash } from 'node:crypto';
import {
  presignPut,
  uriEncode,
  formatAmzDate,
  buildCanonicalRequest,
} from '../src/sigv4.js';

test('uriEncode keeps unreserved characters and encodes the rest', () => {
  assert.equal(uriEncode('abc-_.~'), 'abc-_.~');
  assert.equal(uriEncode('a b'), 'a%20b');
  assert.equal(uriEncode('a/b'), 'a%2Fb');
  assert.equal(uriEncode('a/b', true), 'a/b');
  assert.equal(uriEncode("!'()*"), '%21%27%28%29%2A');
});

test('formatAmzDate produces the SigV4 timestamp pair', () => {
  const date = new Date('2026-10-17T12:34:56.000Z');
  assert.deepEqual(formatAmzDate(date), {
    amzDate: '20261017T123456Z',
    dateStamp: '20261017',
  });
});

test('canonical request is deterministic and well-formed', () => {
  const canonical = buildCanonicalRequest({
    method: 'PUT',
    path: '/pubget-media/images/u/a.jpg',
    query: { 'X-Amz-Algorithm': 'AWS4-HMAC-SHA256', 'X-Amz-Expires': '900' },
    headers: { host: 'acct.r2.cloudflarestorage.com', 'content-type': 'image/jpeg' },
    signedHeaders: ['content-type', 'host'],
  });
  const lines = canonical.split('\n');
  assert.equal(lines[0], 'PUT');
  assert.equal(lines[1], '/pubget-media/images/u/a.jpg');
  assert.equal(lines[2], 'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=900');
  assert.equal(lines[3], 'content-type:image/jpeg');
  assert.equal(lines[4], 'host:acct.r2.cloudflarestorage.com');
  assert.equal(lines[5], '', 'canonical headers are separated from signed headers by a blank line');
  assert.equal(lines[6], 'content-type;host');
  assert.equal(lines[7], 'UNSIGNED-PAYLOAD');
});

test('signature matches an independent node:crypto implementation', async () => {
  const date = new Date('2026-10-17T12:34:56.000Z');
  const params = {
    accountId: 'acct',
    bucket: 'pubget-media',
    key: 'images/user123/abc.jpg',
    accessKeyId: 'AKIDEXAMPLE',
    secretAccessKey: 'SECRETEXAMPLE',
    expiresInSeconds: 900,
    headers: {
      'content-type': 'image/jpeg',
      'content-length': '1234',
      'x-amz-meta-owner-uid': 'user123',
    },
    date,
  };

  const result = await presignPut(params);
  const { amzDate, dateStamp } = formatAmzDate(date);
  const scope = `${dateStamp}/auto/s3/aws4_request`;
  const signedHeaders = ['content-length', 'content-type', 'host', 'x-amz-meta-owner-uid'];
  const query = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `AKIDEXAMPLE/${scope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': '900',
    'X-Amz-SignedHeaders': signedHeaders.join(';'),
  };
  const canonical = buildCanonicalRequest({
    method: 'PUT',
    path: '/pubget-media/images/user123/abc.jpg',
    query,
    headers: {
      host: 'acct.r2.cloudflarestorage.com',
      'content-type': 'image/jpeg',
      'content-length': '1234',
      'x-amz-meta-owner-uid': 'user123',
    },
    signedHeaders,
  });

  const hmac = (key, data) => createHmac('sha256', key).update(data).digest();
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    scope,
    createHash('sha256').update(canonical).digest('hex'),
  ].join('\n');
  const kDate = hmac('AWS4SECRETEXAMPLE', dateStamp);
  const kRegion = hmac(kDate, 'auto');
  const kService = hmac(kRegion, 's3');
  const kSigning = hmac(kService, 'aws4_request');
  const expected = createHmac('sha256', kSigning).update(stringToSign).digest('hex');

  assert.equal(result.signature, expected);
  assert.deepEqual(result.signedHeaders, signedHeaders);
  assert.ok(result.url.startsWith('https://acct.r2.cloudflarestorage.com/pubget-media/images/user123/abc.jpg?'));
  assert.ok(result.url.includes('X-Amz-Signature='));
});

test('the signed headers are exactly the ones the uploader must send', async () => {
  const result = await presignPut({
    accountId: 'acct',
    bucket: 'pubget-media',
    key: 'audio/user123/x.mp3',
    accessKeyId: 'k',
    secretAccessKey: 's',
    expiresInSeconds: 900,
    headers: { 'content-type': 'audio/mpeg', 'content-length': '10', 'x-amz-meta-owner-uid': 'user123' },
    date: new Date('2026-10-17T12:34:56.000Z'),
  });
  assert.deepEqual(result.signedHeaders, [
    'content-length',
    'content-type',
    'host',
    'x-amz-meta-owner-uid',
  ]);
});
