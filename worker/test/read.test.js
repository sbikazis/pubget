import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  contentTypeFor,
  parseRange,
  IMMUTABLE_CACHE_CONTROL,
  CONTENT_TYPE_BY_EXT,
} from '../src/read.js';

test('contentTypeFor prefers stored metadata', () => {
  assert.equal(
    contentTypeFor('images/u/x.jpg', { httpMetadata: { contentType: 'image/png' } }),
    'image/png',
  );
});

test('contentTypeFor ignores an octet-stream metadata value', () => {
  assert.equal(
    contentTypeFor('images/u/x.jpg', {
      httpMetadata: { contentType: 'application/octet-stream' },
    }),
    'image/jpeg',
  );
});

test('contentTypeFor falls back to the extension', () => {
  assert.equal(contentTypeFor('reels/u/x.webm', {}), 'video/webm');
  assert.equal(contentTypeFor('audio/u/x.m4a', null), 'audio/mp4');
  assert.equal(contentTypeFor('images/u/x.unknown', null), 'application/octet-stream');
});

test('the extension map covers every kind extension', () => {
  for (const ext of ['jpg', 'png', 'mp4', 'webm', 'mp3', 'm4a']) {
    assert.ok(CONTENT_TYPE_BY_EXT[ext], `missing content type for ${ext}`);
  }
});

test('immutable cache control is a long public max-age', () => {
  assert.match(IMMUTABLE_CACHE_CONTROL, /^public, max-age=\d+, immutable$/);
});

test('parseRange returns null without a header', () => {
  assert.equal(parseRange(null, 100), null);
  assert.equal(parseRange('', 100), null);
  assert.equal(parseRange('items=1-2', 100), null);
});

test('parseRange parses an explicit window', () => {
  assert.deepEqual(parseRange('bytes=0-9', 100), { offset: 0, length: 10, end: 9 });
  assert.deepEqual(parseRange('bytes=5-', 100), { offset: 5, length: 95, end: 99 });
});

test('parseRange clamps an open-ended end to the object size', () => {
  assert.deepEqual(parseRange('bytes=90-200', 100), { offset: 90, length: 10, end: 99 });
});

test('parseRange parses a suffix range', () => {
  assert.deepEqual(parseRange('bytes=-10', 100), { offset: 90, length: 10, end: 99 });
  assert.deepEqual(parseRange('bytes=-500', 100), { offset: 0, length: 100, end: 99 });
});

test('parseRange flags a start past the end as unsatisfiable', () => {
  assert.deepEqual(parseRange('bytes=100-', 100), { unsatisfiable: true });
  assert.deepEqual(parseRange('bytes=200-300', 100), { unsatisfiable: true });
});
