"use strict";

// Phase 10 (spec axis 23) — the missing half of the report pipeline.
//
// Before this module every report callable ended at a per-content
// subcollection (`edits/{id}/reports`, `fanWorks/{id}/reports`, …). Those rows
// were reachable only by an admin client and nothing ever listed them, so a
// report was written, incremented a counter, and was then unreachable. There
// was no queue, no triage, and no way to mark a report resolved.
//
// `moderation_cases` is that queue: one flat, server-owned collection so a
// moderator can read across every content type in a single ordered query
// instead of fanning out to six different parent paths server-side.
//
// The id is deterministic (`type_target_reporter`) which makes enqueueing
// idempotent: re-reporting the same target bumps `repeatCount` and refreshes
// the reason rather than creating a second case. That mirrors the
// one-report-per-reporter rule each source callable already enforces.

const MAX_CASE_ID = 200;
const MAX_SEGMENT = 120;

/** Case types the queue accepts. Keep in sync with `CASE_TYPES`. */
const CASE_TYPES = Object.freeze([
  "edit",
  "fanWork",
  "animeReview",
  "anime",
  "groupMessage",
  "privateMessage",
  "event",
]);

const CASE_TYPE_SET = new Set(CASE_TYPES);

function sanitizeSegment(value) {
  return String(value == null ? "" : value)
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, MAX_SEGMENT);
}

/** Deterministic case id: one open case per (type, target, reporter). */
function moderationCaseId({ type, targetId, reporterId }) {
  const id = `${sanitizeSegment(type)}_${sanitizeSegment(targetId)}_${sanitizeSegment(
    reporterId,
  )}`;
  return id.length <= MAX_CASE_ID ? id : id.slice(0, MAX_CASE_ID);
}

function normalizeText(value, max) {
  if (value == null) return null;
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, max);
}

/**
 * Enqueue (or bump) a moderation case.
 *
 * Called from inside the existing report callables. Those callables have
 * already validated auth, target existence, self-report, and rate limits
 * before this runs, so this function only records what it is given — it does
 * not re-authorise. Errors are deliberately *not* swallowed: a report that
 * cannot be queued is a report nobody will see, and a silent failure here is
 * exactly the original bug wearing a different hat.
 */
async function enqueueModerationCase({
  db,
  FieldValue,
  type,
  targetId,
  targetParentId = null,
  reporterId,
  creatorId = null,
  reason,
  details = null,
  sourcePath = null,
}) {
  if (!CASE_TYPE_SET.has(type)) {
    throw new Error(`Unknown moderation case type: ${type}`);
  }
  if (!targetId || !reporterId) {
    throw new Error("A moderation case needs both targetId and reporterId.");
  }

  const ref = db
    .collection("moderation_cases")
    .doc(moderationCaseId({ type, targetId, reporterId }));
  const existing = await ref.get();

  if (existing.exists) {
    await ref.set(
      {
        reason,
        detail: normalizeText(details, 500),
        updatedAt: FieldValue.serverTimestamp(),
        repeatCount: FieldValue.increment(1),
      },
      { merge: true },
    );
    return { caseId: ref.id, alreadyReported: true };
  }

  await ref.set({
    type,
    targetId,
    targetParentId,
    reporterId,
    creatorId,
    reason,
    detail: normalizeText(details, 500),
    sourcePath,
    status: "open",
    resolution: null,
    resolvedBy: null,
    resolvedAt: null,
    resolutionNote: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    repeatCount: 1,
  });

  return { caseId: ref.id, alreadyReported: false };
}

module.exports = {
  CASE_TYPES,
  CASE_TYPE_SET,
  moderationCaseId,
  enqueueModerationCase,
};
