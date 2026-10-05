'use strict';

// §15 viewer visibility.
//
// Blocking used to write `friendships.status == "blocked"` while the feed never
// read it, so a blocked creator kept appearing in every Reels scope. These tests
// pin the guarantee that a block or mute removes the creator's content.

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  buildHiddenCreatorSet,
  applyVisibility,
  hiddenIdChunks,
  chunks,
  MAX_IN_CHUNK,
} = require('../src/reelVisibility');

const row = (creatorId, editId = 'e1') => ({
  id: editId,
  data: { creatorId, status: 'published' },
});

test('a block hides the other creator', () => {
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [
      { data: { userIds: ['alice', 'bob'], status: 'blocked', blockedBy: 'alice' } },
    ],
  });
  assert.equal(hidden.has('bob'), true);
  assert.equal(hidden.has('alice'), false);
});

test('being blocked also hides the blocker', () => {
  // Someone who blocked you must not keep serving you their Reels.
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [
      { data: { userIds: ['alice', 'bob'], status: 'blocked', blockedBy: 'bob' } },
    ],
  });
  assert.equal(hidden.has('bob'), true);
});

test('pending friend requests and accepted friendships hide nothing', () => {
  for (const status of ['pending', 'accepted', 'friends', undefined, null]) {
    const hidden = buildHiddenCreatorSet({
      viewerId: 'alice',
      blockDocs: [{ data: { userIds: ['alice', 'bob'], status } }],
    });
    assert.equal(hidden.size, 0, `status ${status} must not hide anyone`);
  }
});

test('mute hides only the muted creator and only for that viewer', () => {
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    muteDocs: ['bob'],
  });
  assert.equal(hidden.has('bob'), true);
  assert.equal(hidden.has('carol'), false);
});

test('block and mute combine', () => {
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [
      { data: { userIds: ['alice', 'bob'], status: 'blocked', blockedBy: 'alice' } },
    ],
    muteDocs: ['carol'],
  });
  assert.deepEqual([...hidden].sort(), ['bob', 'carol']);
});

test('the viewer is never hidden from their own content', () => {
  // Even a malformed row naming the viewer must not hide the viewer's own work.
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [
      { data: { userIds: ['alice', 'bob'], status: 'blocked', blockedBy: 'alice' } },
    ],
    muteDocs: ['alice'],
  });
  assert.equal(hidden.has('alice'), false);
});

test('missing viewer hides nobody rather than hiding everyone', () => {
  const hidden = buildHiddenCreatorSet({ blockDocs: [], muteDocs: [] });
  assert.equal(hidden.size, 0);
});

test('malformed block rows cannot hide the viewer', () => {
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [{ data: { status: 'blocked' } }, { data: null }, undefined],
  });
  assert.equal(hidden.size, 0);
});

test('blocked creators are dropped from feed candidates', () => {
  const hidden = buildHiddenCreatorSet({
    viewerId: 'alice',
    blockDocs: [
      { data: { userIds: ['alice', 'bob'], status: 'blocked', blockedBy: 'alice' } },
    ],
  });
  const candidates = [row('alice', 'mine'), row('bob', 'theirs'), row('carol', 'other')];
  const visible = applyVisibility(candidates, hidden, 'alice');
  assert.deepEqual(visible.map((item) => item.id), ['mine', 'other']);
});

test('the viewer always keeps their own Reels in the feed', () => {
  const hidden = buildHiddenCreatorSet({ viewerId: 'alice', muteDocs: ['alice'] });
  const visible = applyVisibility([row('alice', 'mine')], hidden, 'alice');
  assert.equal(visible.length, 1);
});

test('rows with no creatorId are kept, not dropped', () => {
  // Defensive: a malformed row must not become a way to hide content wholesale.
  const hidden = buildHiddenCreatorSet({ viewerId: 'alice', muteDocs: [] });
  const visible = applyVisibility([{ id: 'x', data: {} }], hidden, 'alice');
  assert.equal(visible.length, 1);
});

test('an empty hidden set is a no-op', () => {
  const candidates = [row('bob'), row('carol')];
  assert.deepEqual(applyVisibility(candidates, new Set(), 'alice'), candidates);
  assert.deepEqual(applyVisibility(candidates, null, 'alice'), candidates);
});

test('hidden ids chunk to Firestore`s 30-value `in` limit', () => {
  const ids = new Set(Array.from({ length: 71 }, (_, i) => `u${i}`));
  const parts = hiddenIdChunks(ids, 'alice');
  assert.equal(parts.length, 3);
  assert.equal(parts[0].length, 30);
  assert.equal(parts[1].length, 30);
  assert.equal(parts[2].length, 11);
  assert.deepEqual(chunks(Array.from({ length: 60 }, (_, i) => i)).length, 2);
});

test('hidden id chunks omit the viewer and are empty when nothing is hidden', () => {
  // An empty `not-in` array is a Firestore client error, not a no-op.
  assert.deepEqual(hiddenIdChunks(new Set(), 'alice'), []);
  assert.deepEqual(hiddenIdChunks(new Set(['alice']), 'alice'), []);
  assert.deepEqual(hiddenIdChunks(new Set(['alice', 'bob']), 'alice'), [['bob']]);
});

test('chunk size limit is the documented 30', () => {
  assert.equal(MAX_IN_CHUNK, 30);
});
