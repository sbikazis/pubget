"use strict";

// Phase 10 — moderation & admin surface (spec axis 23).
//
// Design constraints, all of them from the spec:
//
//  1. Staff identity lives in **custom claims**, never in a writable Firestore
//     document. A Firestore `role` field can be forged by whoever can write the
//     document; a custom claim can only be set by the Admin SDK.
//  2. Nothing here weakens `firestore.rules`. Content visibility is still
//     decided by `moderationStatus`, which is what the existing read rules
//     already key off. Takedowns flip that field; they do not open a hole.
//  3. Every mutation writes an append-only audit row, because "who removed
//     this and why" is the difference between moderation and vandalism.
//  4. Restores are real: a takedown stores the previous moderation state so it
//     can be reversed without guessing.

const { enqueueModerationCase, CASE_TYPES, CASE_TYPE_SET } = require("./moderationQueue");

const MAX_ID = 200;
const MAX_NOTE = 500;
const MAX_REASON = 64;
const DEFAULT_LIMIT = 25;
const MAX_LIMIT = 100;

/** Content kinds a moderator can remove / restore. */
const REMOVABLE_KINDS = Object.freeze([
  "edit",
  "fanWork",
  "animeReview",
  "groupMessage",
  "privateMessage",
  "event",
]);

const REMOVABLE_KIND_SET = new Set(REMOVABLE_KINDS);

/** `needs_review` sweep targets. */
const REVIEW_KINDS = Object.freeze(["edit", "fanWork", "animeReview"]);
const REVIEW_KIND_SET = new Set(REVIEW_KINDS);

const CASE_STATUSES = Object.freeze(["open", "resolved", "dismissed"]);
const CASE_STATUS_SET = new Set(CASE_STATUSES);

const RESOLUTIONS = Object.freeze(["dismiss", "action_taken", "removed"]);
const RESOLUTION_SET = new Set(RESOLUTIONS);

function isTrueFlag(value) {
  return value === true || value === "true";
}

function validId(value, max = MAX_ID) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= max;
}

function clampLimit(raw) {
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) return DEFAULT_LIMIT;
  return Math.min(value, MAX_LIMIT);
}

function toMillis(value, fallback = 0) {
  if (value == null) return fallback;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (typeof value._seconds === "number") {
    return value._seconds * 1000 + Math.floor((value._nanoseconds || 0) / 1e6);
  }
  if (typeof value.seconds === "number") return value.seconds * 1000;
  return fallback;
}

function createModerationDomain({
  db,
  FieldValue,
  HttpsError,
  syncModeratorClaim = null,
  now = () => new Date(),
}) {
  function requireAuth(request) {
    if (!request || !request.auth || !validId(request.auth.uid)) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth;
  }

  /**
   * Staff gate. Admin implies moderator; both come from the token, never from
   * Firestore. A missing/None claim is a plain user.
   */
  function requireStaff(request) {
    const auth = requireAuth(request);
    const token = auth.token || {};
    if (isTrueFlag(token.admin)) return { uid: auth.uid, role: "admin" };
    if (isTrueFlag(token.moderator)) return { uid: auth.uid, role: "moderator" };
    throw new HttpsError(
      "permission-denied",
      "Moderator access is required for this action.",
    );
  }

  function requireAdmin(request) {
    const auth = requireAuth(request);
    const token = auth.token || {};
    if (!isTrueFlag(token.admin)) {
      throw new HttpsError(
        "permission-denied",
        "Only a platform admin can manage moderator roles.",
      );
    }
    return auth.uid;
  }

  function caseRef(caseId) {
    return db.collection("moderation_cases").doc(caseId);
  }

  function auditRef() {
    return db.collection("moderation_audit");
  }

  async function writeAudit({
    actorId,
    action,
    caseId = null,
    kind = null,
    targetId = null,
    note = null,
    previous = null,
  }) {
    await auditRef().add({
      actorId,
      action,
      caseId,
      kind,
      targetId,
      note,
      previous,
      at: FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------- reads ---

  /**
   * The report queue. Ordered newest-first so a moderator works the freshest
   * harm first; `status` defaults to "open" because a resolved case is history,
   * not work.
   */
  async function listCases(request) {
    requireStaff(request);
    const data = request.data || {};
    const status = CASE_STATUS_SET.has(data.status) ? data.status : "open";
    const type = CASE_TYPE_SET.has(data.type) ? data.type : null;
    const limit = clampLimit(data.limit);

    let query = db.collection("moderation_cases").where("status", "==", status);
    if (type) query = query.where("type", "==", type);
    query = query.orderBy("createdAt", "desc").limit(limit);

    const snapshot = await query.get();
    const cases = (snapshot.docs || []).map((doc) => ({
      caseId: doc.id,
      ...(doc.data() || {}),
    }));
    return {
      status,
      type,
      cases,
      // A cursor is the last row's createdAt + id; present only when a full
      // page came back, so the client knows there may be more.
      nextCursor:
        cases.length === limit
          ? { createdAt: toMillis(cases[cases.length - 1].createdAt, 0), caseId: cases[cases.length - 1].caseId }
          : null,
    };
  }

  async function getCase(request) {
    requireStaff(request);
    const caseId = request.data && request.data.caseId;
    if (!validId(caseId)) {
      throw new HttpsError("invalid-argument", "caseId is required.");
    }
    const snapshot = await caseRef(caseId).get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Report not found.");
    return { caseId, report: snapshot.data() || {} };
  }

  /**
   * The `needs_review` sweep for content the automated gate held but never
   * queued. This is the half of the pipeline that made "needs_review" a dead
   * end: the edit pipeline and fan-work publication set the status and nothing
   * could ever clear it.
   */
  async function listNeedsReview(request) {
    requireStaff(request);
    const data = request.data || {};
    if (!REVIEW_KIND_SET.has(data.kind)) {
      throw new HttpsError(
        "invalid-argument",
        "kind must be one of: edit, fanWork, animeReview.",
      );
    }
    const limit = clampLimit(data.limit);

    if (data.kind === "edit") {
      const snapshot = await db
        .collection("edits")
        .where("moderationStatus", "in", ["needs_review", "flagged"])
        .limit(limit)
        .get();
      return {
        kind: "edit",
        items: (snapshot.docs || []).map((doc) => ({ id: doc.id, ...(doc.data() || {}) })),
      };
    }

    if (data.kind === "fanWork") {
      const snapshot = await db
        .collection("fanWorks")
        .where("moderationStatus", "in", ["needs_review", "flagged"])
        .limit(limit)
        .get();
      return {
        kind: "fanWork",
        items: (snapshot.docs || []).map((doc) => ({ id: doc.id, ...(doc.data() || {}) })),
      };
    }

    // Anime reviews live under anime_stats/{animeId}/reviews/{uid}; a
    // collection-group read is the only way to sweep them all at once.
    const snapshot = await db
      .collectionGroup("reviews")
      .where("moderationStatus", "in", ["needs_review", "flagged"])
      .limit(limit)
      .get();
    return {
      kind: "animeReview",
      items: (snapshot.docs || []).map((doc) => ({
        id: doc.id,
        parentId: doc.ref && doc.ref.parent && doc.ref.parent.parent
          ? doc.ref.parent.parent.id
          : null,
        ...(doc.data() || {}),
      })),
    };
  }

  // ------------------------------------------------------------- takedown ---

  function targetRefFor(kind, targetId, targetParentId) {
    if (kind === "edit") return db.collection("edits").doc(targetId);
    if (kind === "fanWork") return db.collection("fanWorks").doc(targetId);
    if (kind === "event") return db.collection("events").doc(targetId);
    if (kind === "animeReview") {
      if (!validId(targetParentId)) {
        throw new HttpsError(
          "invalid-argument",
          "An anime review takedown needs the anime id (targetParentId).",
        );
      }
      return db
        .collection("anime_stats")
        .doc(targetParentId)
        .collection("reviews")
        .doc(targetId);
    }
    if (kind === "groupMessage") {
      if (!validId(targetParentId)) {
        throw new HttpsError(
          "invalid-argument",
          "A group message takedown needs the group id (targetParentId).",
        );
      }
      return db
        .collection("groups")
        .doc(targetParentId)
        .collection("messages")
        .doc(targetId);
    }
    if (kind === "privateMessage") {
      if (!validId(targetParentId)) {
        throw new HttpsError(
          "invalid-argument",
          "A private message takedown needs the chat id (targetParentId).",
        );
      }
      return db
        .collection("privateChats")
        .doc(targetParentId)
        .collection("messages")
        .doc(targetId);
    }
    throw new HttpsError("invalid-argument", "Unsupported content kind.");
  }

  function previousStateOf(kind, data) {
    return {
      moderationStatus: data.moderationStatus == null ? null : data.moderationStatus,
      status: data.status == null ? null : data.status,
      visibility: data.visibility == null ? null : data.visibility,
      text: data.text == null ? null : data.text,
      caption: data.caption == null ? null : data.caption,
      deletedAt: data.deletedAt == null ? null : data.deletedAt,
    };
  }

  async function applyRemoval({ kind, ref, data, actorId, reason }) {
    const previous = previousStateOf(kind, data);
    const patch = {
      moderationStatus: "removed",
      moderationReason: reason,
      moderatedAt: FieldValue.serverTimestamp(),
      moderatedBy: actorId,
      updatedAt: FieldValue.serverTimestamp(),
    };
    // A removed message must stop rendering its payload immediately; keeping
    // the text "hidden" only by a status flag means every client that already
    // holds the document keeps showing it.
    if (kind === "groupMessage" || kind === "privateMessage") {
      patch.text = null;
      patch.mediaUrl = null;
      patch.thumbnailUrl = null;
    }
    if (kind === "fanWork") {
      patch.visibility = "unpublished";
    }
    await ref.update(patch);
    return { previous, patch };
  }

  async function removeContent(request) {
    const staff = requireStaff(request);
    const data = request.data || {};
    const kind = data.kind;
    const targetId = data.targetId;
    if (!REMOVABLE_KIND_SET.has(kind)) {
      throw new HttpsError("invalid-argument", "Unsupported content kind.");
    }
    if (!validId(targetId)) {
      throw new HttpsError("invalid-argument", "targetId is required.");
    }
    const reason = validId(data.reason, MAX_REASON) ? data.reason.trim() : "policy_violation";

    const ref = targetRefFor(kind, targetId.trim(), data.targetParentId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Content not found.");

    const current = snapshot.data() || {};
    if (current.moderationStatus === "removed") {
      return { ok: true, alreadyRemoved: true };
    }

    const { previous } = await applyRemoval({
      kind,
      ref,
      data: current,
      actorId: staff.uid,
      reason,
    });

    await writeAudit({
      actorId: staff.uid,
      action: "content_removed",
      kind,
      targetId: ref.id,
      note: reason,
      previous,
    });

    return { ok: true, previous };
  }

  async function restoreContent(request) {
    const staff = requireStaff(request);
    const data = request.data || {};
    const kind = data.kind;
    const targetId = data.targetId;
    if (!REMOVABLE_KIND_SET.has(kind)) {
      throw new HttpsError("invalid-argument", "Unsupported content kind.");
    }
    if (!validId(targetId)) {
      throw new HttpsError("invalid-argument", "targetId is required.");
    }
    const note = typeof data.note === "string" ? data.note.trim().slice(0, MAX_NOTE) : null;
    const previous =
      data.previous && typeof data.previous === "object" ? data.previous : null;

    const ref = targetRefFor(kind, targetId.trim(), data.targetParentId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Content not found.");
    const current = snapshot.data() || {};

    // Prefer the caller-supplied snapshot (the case row holds it) and fall back
    // to `approved`, which is the only status the read rules will serve. It
    // never silently restores to "pending": unapproved content would stay
    // invisible while looking restored.
    const restoredStatus =
      previous && typeof previous.moderationStatus === "string"
        ? previous.moderationStatus
        : "approved";
    const patch = {
      moderationStatus: restoredStatus || "approved",
      moderationReason: null,
      moderatedAt: FieldValue.serverTimestamp(),
      moderatedBy: staff.uid,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (kind === "groupMessage" || kind === "privateMessage") {
      if (previous && typeof previous.text === "string") patch.text = previous.text;
    }
    if (kind === "fanWork" && previous && typeof previous.visibility === "string") {
      patch.visibility = previous.visibility;
    }
    await ref.update(patch);

    await writeAudit({
      actorId: staff.uid,
      action: "content_restored",
      kind,
      targetId: ref.id,
      note,
      previous: previousStateOf(kind, current),
    });

    return { ok: true, restoredTo: patch.moderationStatus };
  }

  // --------------------------------------------------------------- resolve ---

  /**
   * Close a report. `dismiss` records that the report was reviewed and found
   * not action-worthy — that is not the same as deleting it, and keeping it is
   * what lets a repeat reporter be recognised later.
   */
  async function resolveCase(request) {
    const staff = requireStaff(request);
    const data = request.data || {};
    const caseId = data.caseId;
    const resolution = data.resolution;
    if (!validId(caseId)) {
      throw new HttpsError("invalid-argument", "caseId is required.");
    }
    if (!RESOLUTION_SET.has(resolution)) {
      throw new HttpsError(
        "invalid-argument",
        "resolution must be one of: dismiss, action_taken, removed.",
      );
    }
    const note = typeof data.note === "string" ? data.note.trim().slice(0, MAX_NOTE) : null;

    const ref = caseRef(caseId);
    const result = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Report not found.");
      const current = snapshot.data() || {};
      if (current.status !== "open") {
        return { ok: true, alreadyResolved: true, status: current.status };
      }
      transaction.update(ref, {
        status: resolution === "dismiss" ? "dismissed" : "resolved",
        resolution,
        resolutionNote: note,
        resolvedBy: staff.uid,
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { ok: true, status: resolution === "dismiss" ? "dismissed" : "resolved" };
    });

    await writeAudit({
      actorId: staff.uid,
      action: "case_resolved",
      caseId,
      note: note || resolution,
    });

    return result;
  }

  // --------------------------------------------------------------- account ---

  async function restrictUser(request) {
    const staff = requireStaff(request);
    const data = request.data || {};
    const userId = data.userId;
    if (!validId(userId)) {
      throw new HttpsError("invalid-argument", "userId is required.");
    }
    if (userId === staff.uid) {
      throw new HttpsError("failed-precondition", "You cannot restrict your own account.");
    }
    const reason = validId(data.reason, MAX_REASON) ? data.reason.trim() : "policy_violation";
    const hours = Number(data.hours);
    const restrictedUntil =
      Number.isFinite(hours) && hours > 0
        ? new Date(now().getTime() + Math.min(hours, 24 * 365) * 60 * 60 * 1000)
        : null;

    const ref = db.collection("users").doc(userId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "User not found.");

    await ref.set(
      {
        moderationState: "restricted",
        moderationReason: reason,
        restrictedUntil,
        moderatedAt: FieldValue.serverTimestamp(),
        moderatedBy: staff.uid,
      },
      { merge: true },
    );

    await writeAudit({
      actorId: staff.uid,
      action: "user_restricted",
      kind: "user",
      targetId: userId,
      note: reason,
      previous: { restrictedUntil },
    });

    return {
      ok: true,
      restrictedUntil: restrictedUntil ? restrictedUntil.toISOString() : null,
    };
  }

  async function unrestrictUser(request) {
    const staff = requireStaff(request);
    const data = request.data || {};
    const userId = data.userId;
    if (!validId(userId)) {
      throw new HttpsError("invalid-argument", "userId is required.");
    }
    const note = typeof data.note === "string" ? data.note.trim().slice(0, MAX_NOTE) : null;

    const ref = db.collection("users").doc(userId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError("not-found", "User not found.");

    await ref.set(
      {
        moderationState: "clear",
        moderationReason: null,
        restrictedUntil: null,
        moderatedAt: FieldValue.serverTimestamp(),
        moderatedBy: staff.uid,
      },
      { merge: true },
    );

    await writeAudit({
      actorId: staff.uid,
      action: "user_unrestricted",
      kind: "user",
      targetId: userId,
      note,
    });

    return { ok: true };
  }

  /**
   * Grant/revoke the platform-moderator claim.
   *
   * This is why moderator identity is a custom claim: the only way to set it is
   * through the Admin SDK from here, behind an admin-only gate. A Firestore
   * `role: "moderator"` field would be writable by anyone who can write the
   * document, which is precisely the escalation the spec forbids.
   */
  async function setModeratorRole(request) {
    const adminId = requireAdmin(request);
    const data = request.data || {};
    const userId = data.userId;
    const moderator = data.moderator;
    if (!validId(userId)) {
      throw new HttpsError("invalid-argument", "userId is required.");
    }
    if (typeof moderator !== "boolean") {
      throw new HttpsError("invalid-argument", "moderator must be a boolean.");
    }
    if (userId === adminId && moderator === false) {
      throw new HttpsError("failed-precondition", "You cannot revoke your own admin claim here.");
    }
    if (typeof syncModeratorClaim !== "function") {
      throw new HttpsError(
        "failed-precondition",
        "Moderator role management is not configured on this deployment.",
      );
    }

    await syncModeratorClaim({ uid: userId, moderator });

    await writeAudit({
      actorId: adminId,
      action: moderator ? "moderator_granted" : "moderator_revoked",
      kind: "user",
      targetId: userId,
      note: null,
    });

    return { ok: true, userId, moderator };
  }

  /** Header counts for the moderation surface. Never returns content. */
  async function getModerationSummary(request) {
    requireStaff(request);
    const open = await db
      .collection("moderation_cases")
      .where("status", "==", "open")
      .count()
      .get();
    const total =
      open && typeof open.data === "function" ? Number(open.data().count) || 0 : 0;
    return { openCases: total };
  }

  return {
    listCases,
    getCase,
    listNeedsReview,
    removeContent,
    restoreContent,
    resolveCase,
    restrictUser,
    unrestrictUser,
    setModeratorRole,
    getModerationSummary,
  };
}

module.exports = {
  createModerationDomain,
  REMOVABLE_KINDS,
  REVIEW_KINDS,
  CASE_STATUSES,
  RESOLUTIONS,
  enqueueModerationCase,
  CASE_TYPES,
};
