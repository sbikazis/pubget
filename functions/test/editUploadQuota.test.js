'use strict';

// §15.2 upload quota enforcement in startUpload.
//
// The cap is server-side on purpose: a client pre-flight is advisory and can be
// bypassed by anyone calling the callable directly.

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  utcDayKey,
  quotaDocId,
  quotaVerdict,
  quotaExceededMessage,
} = require('../src/editUploadQuota');
const { EDIT_UPLOAD_QUOTA } = require('../src/editsConfig');

test('UTC day bucket rolls over at midnight UTC', () => {
  assert.equal(utcDayKey(new Date('2026-10-04T23:59:59.999Z')), '20261004');
  assert.equal(utcDayKey(new Date('2026-10-05T00:00:00.000Z')), '20261005');
  assert.equal(utcDayKey(new Date('2026-01-09T12:00:00Z')), '20260109');
});

test('day bucket is UTC, not local — quota must not reset by timezone', () => {
  // 23:30 UTC is already "tomorrow" for UTC+2 users and still "today" for UTC-5.
  const late = new Date('2026-10-04T23:30:00Z');
  assert.equal(utcDayKey(late), '20261004');
  assert.equal(utcDayKey(new Date(late.getTime() + 60 * 60 * 1000)), '20261005');
});

test('invalid dates are rejected instead of producing a garbage key', () => {
  assert.throws(() => utcDayKey(new Date('nope')), TypeError);
  assert.throws(() => utcDayKey('nope'), TypeError);
});

test('quota doc id is one bucket per creator per day', () => {
  assert.equal(quotaDocId('user1', '20261004'), 'user1_20261004');
  assert.notEqual(quotaDocId('user1', '20261004'), quotaDocId('user2', '20261004'));
});

test('the last slot is admitted and the next one is refused', () => {
  const limit = EDIT_UPLOAD_QUOTA.dailyUploads;
  const last = quotaVerdict(limit - 1);
  assert.equal(last.allowed, true);
  assert.equal(last.remaining, 1);
  assert.equal(last.used, limit - 1);

  const over = quotaVerdict(limit);
  assert.equal(over.allowed, false);
  assert.equal(over.remaining, 0);
  assert.equal(over.reason, 'quota-exhausted');
});

test('a counter above the cap stays refused', () => {
  const verdict = quotaVerdict(EDIT_UPLOAD_QUOTA.dailyUploads + 40);
  assert.equal(verdict.allowed, false);
});

test('missing or corrupt counters read as an empty bucket, not a block', () => {
  // A brand-new creator must be able to upload; only an explicit counter blocks.
  for (const missing of [undefined, null, 0]) {
    assert.equal(quotaVerdict(missing).allowed, true, `${missing} must be admitted`);
  }
  // A corrupt negative counter must never hand out extra slots.
  assert.equal(quotaVerdict(-5).used, 0);
});

test('limit is configurable and a zero limit blocks everything', () => {
  assert.equal(quotaVerdict(0, 0).allowed, false);
  assert.equal(quotaVerdict(0, 5).allowed, true);
});

test('exhaustion message names the real limit', () => {
  assert.match(quotaExceededMessage(EDIT_UPLOAD_QUOTA.dailyUploads), /20/);
  assert.match(quotaExceededMessage(), /daily upload limit/i);
});