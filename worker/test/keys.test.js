import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildKey, parseKey, keyOwnedBy, keyMatchesKindRules } from '../src/keys.js';

test('buildKey places the owner uid in the key, never the file name', () => {
  const key = buildKey({ kind: 'image', uid: 'user123', extension: 'jpeg', uuid: 'abc-123' });
  assert.equal(key, 'images/user123/abc-123.jpg');
});

test('buildKey rejects unknown kinds', () => {
  assert.throws(() => buildKey({ kind: 'video', uid: 'u', extension: 'mp4', uuid: 'x' }));
});

test('parseKey round-trips a valid key', () => {
  const parsed = parseKey('reels/user123/abc-123.webm');
  assert.deepEqual(parsed, {
    kind: 'reels',
    folder: 'reels',
    uid: 'user123',
    name: 'abc-123.webm',
  });
});

test('parseKey rejects traversal and unknown folders', () => {
  assert.equal(parseKey('images/../etc/passwd'), null);
  assert.equal(parseKey('images/user123/../../secret.jpg'), null);
  assert.equal(parseKey('secrets/user123/a.jpg'), null);
  assert.equal(parseKey('images/user123'), null);
  assert.equal(parseKey('images/user123/sub/a.jpg'), null);
  assert.equal(parseKey('images/user123/a.jpg.exe'), null);
  assert.equal(parseKey(42), null);
});

test('keyOwnedBy compares the owner segment', () => {
  assert.equal(keyOwnedBy('audio/alice/x.mp3', 'alice'), true);
  assert.equal(keyOwnedBy('audio/bob/x.mp3', 'alice'), false);
  assert.equal(keyOwnedBy('nonsense', 'alice'), false);
});

test('keyMatchesKindRules checks the extension allowlist', () => {
  assert.equal(keyMatchesKindRules('images/u/a.jpg'), true);
  assert.equal(keyMatchesKindRules('images/u/a.svg'), false);
  assert.equal(keyMatchesKindRules('reels/u/a.mp4'), true);
  assert.equal(keyMatchesKindRules('reels/u/a.html'), false);
});
