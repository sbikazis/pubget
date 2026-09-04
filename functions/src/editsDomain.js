"use strict";

const DAY = 24 * 60 * 60 * 1000;
const MAX_CAPTION = 1000;

function string(value, max) {
  return typeof value === "string" && value.trim().length <= max
    ? value.trim()
    : null;
}

function createEditsDomain({ db, FieldValue, HttpsError }) {
  function uid(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentication is required.");
    return request.auth.uid;
  }

  function editRef(editId) {
    return db.collection("edits").doc(editId);
  }

  async function startUpload(request) {
    const creatorId = uid(request);
    const caption = string(request.data?.caption || "", MAX_CAPTION);
    const animeTag = string(request.data?.animeTag || "", 128);
    if (caption === null || animeTag === null) {
      throw new HttpsError("invalid-argument", "Caption or anime tag is invalid.");
    }
    const editId = db.collection("edits").doc().id;
    await editRef(editId).create({
      creatorId, videoUrl: "", thumbnailUrl: "", videoPath: `edits/${creatorId}/${editId}.mp4`,
      caption, animeTag, likesCount: 0, commentsCount: 0, viewsCount: 0,
      qualifiedViewsCount: 0, score: 0, totalWatchSeconds: 0, completionCount: 0,
      sharesCount: 0, savesCount: 0, negativeFeedbackCount: 0,
      createdAt: FieldValue.serverTimestamp(), originalEditId: null, repostedBy: null,
      originalCreatorId: creatorId,
      status: "processing",
    });
    return { editId, videoPath: `edits/${creatorId}/${editId}.mp4` };
  }

  async function repost(request) {
    const creatorId = uid(request);
    const originalEditId = string(request.data?.editId, 128);
    if (!originalEditId) throw new HttpsError("invalid-argument", "editId is required.");
    const original = await editRef(originalEditId).get();
    if (!original.exists || original.data()?.status !== "published") {
      throw new HttpsError("not-found", "Edit not found.");
    }
    const source = original.data();
    const createdAt = source.createdAt?.toDate?.()?.getTime?.() || 0;
    if (!createdAt || Date.now() - createdAt > 30 * DAY) {
      throw new HttpsError("failed-precondition", "Reposts are available for 30 days.");
    }
    const ref = db.collection("edits").doc();
    await ref.create({
      ...source, creatorId, repostedBy: creatorId, originalEditId,
      originalCreatorId: source.originalCreatorId || source.creatorId,
      createdAt: FieldValue.serverTimestamp(), likesCount: 0, commentsCount: 0,
      viewsCount: 0, qualifiedViewsCount: 0, totalWatchSeconds: 0,
      completionCount: 0, score: 10, status: "published",
      sharesCount: 0, savesCount: 0, negativeFeedbackCount: 0,
    });
    return { editId: ref.id };
  }

  async function deleteEdit(request) {
    const creatorId = uid(request);
    const id = string(request.data?.editId, 128);
    if (!id) throw new HttpsError("invalid-argument", "editId is required.");
    const ref = editRef(id);
    const snap = await ref.get();
    if (!snap.exists) return { ok: true };
    if (snap.data()?.creatorId !== creatorId) {
      throw new HttpsError("permission-denied", "Only the creator can delete this edit.");
    }
    await ref.update({ status: "deleted", deletedAt: FieldValue.serverTimestamp() });
    return { ok: true };
  }

  async function like(request) {
    const actor = uid(request);
    const id = string(request.data?.editId, 128);
    const shouldLike = request.data?.like !== false;
    if (!id) throw new HttpsError("invalid-argument", "editId is required.");
    await db.runTransaction(async (tx) => {
      const ref = editRef(id);
      const likeRef = ref.collection("likes").doc(actor);
      const [edit, existing] = await Promise.all([tx.get(ref), tx.get(likeRef)]);
      if (!edit.exists || edit.data()?.status !== "published") {
        throw new HttpsError("not-found", "Edit not found.");
      }
      if (shouldLike && !existing.exists) {
        tx.create(likeRef, { userId: actor, createdAt: FieldValue.serverTimestamp() });
        tx.update(ref, {
          likesCount: FieldValue.increment(1),
          score: FieldValue.increment(4),
        });
      } else if (!shouldLike && existing.exists) {
        tx.delete(likeRef);
        tx.update(ref, {
          likesCount: FieldValue.increment(-1),
          score: FieldValue.increment(-4),
        });
      }
    });
    return { ok: true };
  }

  async function comment(request) {
    const authorId = uid(request);
    const editId = string(request.data?.editId, 128);
    const text = string(request.data?.text, 500);
    const replyRaw = request.data?.replyToCommentId;
    const replyToCommentId = replyRaw == null || replyRaw === ""
      ? null
      : string(replyRaw, 128);
    if (replyRaw && !replyToCommentId) {
      throw new HttpsError("invalid-argument", "Reply target is invalid.");
    }
    if (!editId || !text || text.length === 0) {
      throw new HttpsError("invalid-argument", "A comment is required.");
    }
    const ref = editRef(editId);
    const edit = await ref.get();
    if (!edit.exists || edit.data()?.status !== "published") {
      throw new HttpsError("not-found", "Edit not found.");
    }
    const commentRef = ref.collection("comments").doc();
    await db.runTransaction(async (tx) => {
      if (replyToCommentId) {
        const parent = await tx.get(ref.collection("comments").doc(replyToCommentId));
        if (!parent.exists) {
          throw new HttpsError("not-found", "The comment you are replying to is gone.");
        }
      }
      tx.create(commentRef, {
        authorId, text, likesCount: 0, replyToCommentId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        commentsCount: FieldValue.increment(1),
        score: FieldValue.increment(6),
      });
    });
    return { commentId: commentRef.id };
  }

  async function recordView(request) {
    const viewerId = uid(request);
    const editId = string(request.data?.editId, 128);
    const sessionId = string(request.data?.sessionId, 128);
    const percent = Number(request.data?.watchPercent);
    const watchSeconds = Math.max(0, Math.min(3600, Number(request.data?.watchSeconds) || 0));
    if (!editId || !sessionId || !Number.isFinite(percent) || percent < 0 || percent > 100) {
      throw new HttpsError("invalid-argument", "View data is invalid.");
    }
    const ref = editRef(editId);
    const viewerRef = ref.collection("viewers").doc(viewerId);
    const sessionRef = ref.collection("playbackSessions").doc(sessionId);
    await db.runTransaction(async (tx) => {
      const [edit, viewer, session] = await Promise.all([
        tx.get(ref), tx.get(viewerRef), tx.get(sessionRef),
      ]);
      if (!edit.exists || edit.data()?.status !== "published") {
        throw new HttpsError("not-found", "Edit not found.");
      }
      const sessionData = session.data() || {};
      const expires = sessionData.expiresAt?.toDate?.()?.getTime?.() || 0;
      if (!session.exists || sessionData.viewerId !== viewerId ||
          sessionData.consumed === true || expires < Date.now()) {
        throw new HttpsError("failed-precondition", "Playback session is invalid.");
      }
      const lastHeartbeat = sessionData.lastHeartbeatAt?.toDate?.()?.getTime?.() ||
        sessionData.startedAt?.toDate?.()?.getTime?.() || 0;
      const elapsedSeconds = Math.max(0, (Date.now() - lastHeartbeat) / 1000);
      const duration = Math.max(1, Number(edit.data()?.durationSeconds) || 180);
      const sessionCredited = Number(sessionData.creditedSeconds) || 0;
      const increment = Math.max(
        0,
        Math.min(watchSeconds - sessionCredited, elapsedSeconds + 2, 8),
      );
      const verifiedSeconds = Math.min(sessionCredited + increment, duration);
      const verifiedPercent = Math.min(percent, verifiedSeconds / duration * 100);
      const previous = viewer.data() || {};
      const last = previous.lastQualifiedAt?.toDate?.()?.getTime?.() || 0;
      // A qualified view is counted once per account/edit/day and is derived
      // from server elapsed time, not from client percentages alone.
      const qualified = verifiedPercent >= 10 && Date.now() - last >= DAY;
      const completed = verifiedPercent >= 90 && previous.completed !== true;
      const creditedBefore = Number(previous.creditedWatchSeconds) || 0;
      const watchCredit = increment;
      tx.set(viewerRef, {
        lastPercent: Math.max(previous.lastPercent || 0, verifiedPercent),
        lastQualifiedAt: qualified ? FieldValue.serverTimestamp() : previous.lastQualifiedAt || null,
        completed: previous.completed === true || completed,
        creditedWatchSeconds: creditedBefore + watchCredit,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.update(sessionRef, {
        creditedSeconds: verifiedSeconds,
        lastHeartbeatAt: FieldValue.serverTimestamp(),
        consumed: verifiedPercent >= 90,
      });
      const changes = { totalWatchSeconds: FieldValue.increment(watchCredit) };
      if (qualified) {
        changes.viewsCount = FieldValue.increment(1);
        changes.qualifiedViewsCount = FieldValue.increment(1);
        changes.score = FieldValue.increment(Math.min(5, 2 + watchCredit * 0.05));
      }
      if (completed) {
        changes.completionCount = FieldValue.increment(1);
        changes.score = FieldValue.increment(8);
      }
      tx.update(ref, changes);
    });
    return { ok: true };
  }

  async function startPlayback(request) {
    const viewerId = uid(request);
    const editId = string(request.data?.editId, 128);
    if (!editId) throw new HttpsError("invalid-argument", "editId is required.");
    const ref = editRef(editId);
    const edit = await ref.get();
    if (!edit.exists || edit.data()?.status !== "published") {
      throw new HttpsError("not-found", "Edit not found.");
    }
    const session = ref.collection("playbackSessions").doc(viewerId);
    await session.set({
      viewerId,
      startedAt: FieldValue.serverTimestamp(),
      lastHeartbeatAt: FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      creditedSeconds: 0,
      consumed: false,
    });
    return { sessionId: session.id };
  }

  async function signal(request) {
    const actor = uid(request);
    const editId = string(request.data?.editId, 128);
    const type = request.data?.type;
    const weights = { share: 3, save: 5, negative: -10 };
    if (!editId || !Object.hasOwn(weights, type)) {
      throw new HttpsError("invalid-argument", "Signal is invalid.");
    }
    const ref = editRef(editId);
    const signalRef = ref.collection("signals").doc(`${actor}_${type}`);
    await db.runTransaction(async (tx) => {
      const [edit, existing] = await Promise.all([tx.get(ref), tx.get(signalRef)]);
      if (!edit.exists || existing.exists) return;
      tx.create(signalRef, { actor, type, createdAt: FieldValue.serverTimestamp() });
      const changes = { score: FieldValue.increment(weights[type]) };
      if (type === "share") changes.sharesCount = FieldValue.increment(1);
      if (type === "save") changes.savesCount = FieldValue.increment(1);
      if (type === "negative") changes.negativeFeedbackCount = FieldValue.increment(1);
      tx.update(ref, changes);
    });
    return { ok: true };
  }

  async function commentAction(request) {
    const actor = uid(request);
    const editId = string(request.data?.editId, 128);
    const commentId = string(request.data?.commentId, 128);
    const action = request.data?.action;
    if (!editId || !commentId || !["like", "unlike", "delete"].includes(action)) {
      throw new HttpsError("invalid-argument", "Comment action is invalid.");
    }
    const edit = editRef(editId);
    const commentRef = edit.collection("comments").doc(commentId);
    await db.runTransaction(async (tx) => {
      const comment = await tx.get(commentRef);
      if (!comment.exists) return;
      if (action === "delete") {
        if (comment.data()?.authorId !== actor) {
          throw new HttpsError("permission-denied", "Only the author can delete this comment.");
        }
        tx.delete(commentRef);
        tx.update(edit, {
          commentsCount: FieldValue.increment(-1),
          score: FieldValue.increment(-6),
        });
        return;
      }
      const likeRef = commentRef.collection("likes").doc(actor);
      const existing = await tx.get(likeRef);
      if (action === "like" && !existing.exists) {
        tx.create(likeRef, { actor, createdAt: FieldValue.serverTimestamp() });
        tx.update(commentRef, { likesCount: FieldValue.increment(1) });
      } else if (action === "unlike" && existing.exists) {
        tx.delete(likeRef);
        tx.update(commentRef, { likesCount: FieldValue.increment(-1) });
      }
    });
    return { ok: true };
  }

  return {
    startUpload, repost, deleteEdit, like, comment, startPlayback, recordView, signal,
    commentAction,
  };
}

module.exports = { createEditsDomain };