'use strict';

const { EDIT_UPLOAD_QUOTA } = require('./editsConfig');

/**
 * §15.2 upload quota.
 *
 * The client pre-flight is advisory only; this is the enforcement point. Kept
 * as pure functions so the boundary logic is unit-testable without the emulator,
 * because a quota that is wrong is either a free-for-all or a hard product wall.
 */

/** UTC day bucket, e.g. 2026-10-04 -> "20261004". */
function utcDayKey(timestamp) {
  const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
  if (Number.isNaN(date.getTime())) {
    throw new TypeError('utcDayKey requires a valid Date');
  }
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

/** Quota document id — one bucket per creator per UTC day. */
function quotaDocId(creatorId, dayKey) {
  return `${creatorId}_${dayKey}`;
}

/**
 * Verdict for a reservation attempt against the current counter.
 *
 * `count` is the number already reserved, so the reservation being attempted
 * would become `count + 1`.
 */
function quotaVerdict(count, limit = EDIT_UPLOAD_QUOTA.dailyUploads) {
  const used = Math.max(0, Number(count) || 0);
  const cap = Math.max(0, Number(limit) || 0);
  if (used >= cap) {
    return {
      allowed: false,
      used,
      limit: cap,
      remaining: 0,
      reason: 'quota-exhausted',
    };
  }
  return { allowed: true, used, limit: cap, remaining: cap - used, reason: null };
}

function quotaExceededMessage(limit = EDIT_UPLOAD_QUOTA.dailyUploads) {
  return `You have reached your daily upload limit (${limit}). Try again tomorrow.`;
}

module.exports = {
  utcDayKey,
  quotaDocId,
  quotaVerdict,
  quotaExceededMessage,
};