"use strict";

const { createHash } = require("node:crypto");

const CASE_TYPES = Object.freeze([
  "edit", "fanWork", "animeReview", "anime", "groupMessage",
  "privateMessage", "event", "editComment", "fanWorkComment",
]);
const CASE_TYPE_SET = new Set(CASE_TYPES);

function legacySanitizeSegment(value) {
  return String(value == null ? "" : value)
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, 120);
}

function legacyModerationCaseId({ type, targetId, reporterId }) {
  return legacySanitizeSegment(type) + "_" +
    legacySanitizeSegment(targetId) + "_" +
    legacySanitizeSegment(reporterId);
}

/**
 * Hash the complete tuple instead of sanitizing/truncating user-controlled
 * IDs. Sanitization is not injective: "a/b" and "a_b" previously mapped to
 * the same queue document and could overwrite another reporter's case.
 */
function moderationCaseId({ type, targetId, reporterId }) {
  const tuple = JSON.stringify([type, targetId, reporterId]);
  const digest = createHash("sha256").update(tuple, "utf8").digest("hex");
  return "mc_" + digest;
}

function normalizeText(value, max) {
  if (value == null || typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, max) : null;
}

async function enqueueModerationCase({
  db, FieldValue, type, targetId, targetParentId = null, reporterId,
  creatorId = null, reason, details = null, sourcePath = null,
}) {
  if (!CASE_TYPE_SET.has(type)) throw new Error("Unknown moderation case type: " + type);
  if (typeof targetId !== "string" || !targetId.trim() ||
      typeof reporterId !== "string" || !reporterId.trim()) {
    throw new Error("A moderation case needs both targetId and reporterId.");
  }

  const identity = { type, targetId: targetId.trim(), reporterId: reporterId.trim() };
  const ref = db.collection("moderation_cases").doc(moderationCaseId(identity));
  // Reuse pre-migration rows only after verifying their full identity.
  const legacyRef = db.collection("moderation_cases").doc(legacyModerationCaseId(identity));

  return db.runTransaction(async (transaction) => {
    const [existing, legacy] = await Promise.all([
      transaction.get(ref), transaction.get(legacyRef),
    ]);
    const existingRef = existing.exists
      ? ref
      : (legacy.exists &&
          legacy.data()?.type === identity.type &&
          legacy.data()?.targetId === identity.targetId &&
          legacy.data()?.reporterId === identity.reporterId
        ? legacyRef
        : null);

    if (existingRef) {
      transaction.update(existingRef, {
        reason,
        detail: normalizeText(details, 500),
        updatedAt: FieldValue.serverTimestamp(),
        repeatCount: FieldValue.increment(1),
      });
      return { caseId: existingRef.id, alreadyReported: true };
    }

    transaction.set(ref, {
      ...identity, targetParentId, creatorId, reason,
      detail: normalizeText(details, 500), sourcePath,
      status: "open", resolution: null, resolvedBy: null,
      resolvedAt: null, resolutionNote: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      repeatCount: 1,
    });
    return { caseId: ref.id, alreadyReported: false };
  });
}

module.exports = { CASE_TYPES, CASE_TYPE_SET, moderationCaseId, enqueueModerationCase };
