import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRateLimiter } from '../src/ratelimit.js';

test('allows up to the limit then blocks, with a retry hint', () => {
  let now = 0;
  const limiter = createRateLimiter({ now: () => now });

  assert.equal(limiter.check('presign:u1', 2, 60).allowed, true);
  assert.equal(limiter.check('presign:u1', 2, 60).allowed, true);

  const blocked = limiter.check('presign:u1', 2, 60);
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.retryAfterSeconds, 60);
});

test('the window resets afterwards', () => {
  let now = 0;
  const limiter = createRateLimiter({ now: () => now });
  limiter.check('k', 1, 60);
  assert.equal(limiter.check('k', 1, 60).allowed, false);
  now = 61_000;
  assert.equal(limiter.check('k', 1, 60).allowed, true);
});

test('keys are independent', () => {
  const limiter = createRateLimiter({ now: () => 0 });
  limiter.check('presign:a', 1, 60);
  assert.equal(limiter.check('presign:b', 1, 60).allowed, true);
});
