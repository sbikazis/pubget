"use strict";

// Phase 10 / Phase 06 — the report queue is a single, server-owned collection.
// Deterministic IDs prevent duplicate cases per reporter and target. The write
// is transactional so two first-time reports arriving together cannot race:
// one creates the case and the other increments its repeat count.

const MAX_CASE_ID = 200;
const MAX_SEGMENT = 120;

const CASE_TYPES = Object.freeze([
  "edit",
  "fanWork",
  "animeReview",
  "anime",
  "groupMessage",
  "privateMessage",
  "event",
  "editComment",
  "fanWorkComment",
]);

const CASE_TYPE_SET = new Set(CASE_TYPES);

function sanitizeSegment(value) {
  return String(value == null ? "" : value)
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, MAX_SEGMENT);
}

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

  return db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) {
      transaction.update(ref, {
        reason,
        detail: normalizeText(details, 500),
        updatedAt: FieldValue.serverTimestamp(),
        repeatCount: FieldValue.increment(1),
      });
      return { caseId: ref.id, alreadyReported: true };
    }

    transaction.set(ref, {
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
  });
}

module.exports = {
  CASE_TYPES,
  CASE_TYPE_SET,
  moderationCaseId,
  enqueueModerationCase,
};
