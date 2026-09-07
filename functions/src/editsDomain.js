"use strict";

const { moderateEditCopy } = require("./contentFilter");
const { scoreEdit } = require("./ranking");
const { EDITS_CONFIG } = require("./editsConfig");

function string(value, max) {
  return typeof value === "string" && value.trim().length <= max
    ? value.trim()
    : null;
}

function emptyCounters() {
  return {
    likes: 0,
    comments: 0,
    shares: 0,
    saves: 0,
    respectReceived: 0,
    impressions: 0,
    views: 0,
    qualifiedViews: 0,
    completions: 0,
    replays: 0,
  };
}

function millis(value) {
  if (!value) return 0;
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? 0 : parsed.getTime();
}

function serializeEdit(id, data) {
  return {
    id,
    ...data,
    createdAt: millis(data.createdAt) || null,
    publishedAt: millis(data.publishedAt) || null,
    processedAt: millis(data.processedAt) || null,
  };
}

function createEditsDomain({ db, FieldValue, HttpsError, achievements, processEdit }) {
  function uid(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentication is required.");
    return request.auth.uid;
  }

  function editRef(editId) {
    return db.collection("edits").doc(editId);
  }

  function bump(changes, flatKey, nestedKey, amount) {
    changes[flatKey] = FieldValue.increment(amount);
    changes[`counters.${nestedKey}`] = FieldValue.increment(amount);
  }

  async function startUpload(request) {
    const creatorId = uid(request);
    const caption = string(request.data?.caption || "", EDITS_CONFIG.captionMax);
    const animeTag = string(request.data?.animeTag || "", 128);
    if (caption === null || animeTag === null) {
      throw new HttpsError("invalid-argument", "Caption or anime tag is invalid.");
    }
    const idempotencyKey = string(request.data?.idempotencyKey || "", 128);
    if (idempotencyKey) {
      const keySnap = await db.collection("editUploadKeys")
        .doc(`${creatorId}_${idempotencyKey}`).get();
      if (keySnap.exists && keySnap.data()?.editId) {
        const existingId = keySnap.data().editId;
        return { editId: existingId, videoPath: `edits/${creatorId}/${existingId}.mp4` };
      }
    }
    const editId = db.collection("edits").doc().id;
    const videoPath = `edits/${creatorId}/${editId}.mp4`;
    const payload = {
      creatorId,
      videoUrl: "",
      thumbnailUrl: "",
      videoPath,
      originalStoragePath: videoPath,
      processedStoragePath: "",
      thumbnailStoragePath: "",
      caption,
      animeTag,
      likesCount: 0,
      commentsCount: 0,
      viewsCount: 0,
      qualifiedViewsCount: 0,
      score: 0,
      totalWatchSeconds: 0,
      completionCount: 0,
      sharesCount: 0,
      savesCount: 0,
      negativeFeedbackCount: 0,
      impressionsCount: 0,
      replaysCount: 0,
      respectReceivedCount: 0,
      counters: emptyCounters(),
      createdAt: FieldValue.serverTimestamp(),
      publishedAt: null,
      originalEditId: null,
      repostedBy: null,
      originalCreatorId: creatorId,
      isRepost: false,
      status: "uploading",
      moderationStatus: "pending",
      moderationReason: null,
      schemaVersion: EDITS_CONFIG.schemaVersion,
    };
    const writes = [editRef(editId).create(payload)];
    if (idempotencyKey) {
      writes.push(db.collection("editUploadKeys").doc(`${creatorId}_${idempotencyKey}`).create({
        creatorId, editId, createdAt: FieldValue.serverTimestamp(),
      }));
    }
    await Promise.all(writes);
    return { editId, videoPath };
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
    const decision = moderateEditCopy({
      caption: source.caption, animeTag: source.animeTag,
    });
    if (decision.flagged) {
      throw new HttpsError(
        "failed-precondition",
        decision.reason || "This Edit cannot be reposted.",
      );
    }
    const originMs = millis(source.publishedAt) || millis(source.createdAt);
    if (!originMs || Date.now() - originMs > EDITS_CONFIG.repostWindowMs) {
      throw new HttpsError("failed-precondition", "Reposts are available for 30 days.");
    }
    if (source.creatorId === creatorId) {
      throw new HttpsError("failed-precondition", "You cannot repost your own Edit.");
    }
    const originalCreatorId = source.originalCreatorId || source.creatorId;
    const ref = db.collection("edits").doc();
    await ref.create({
      ...source,
      creatorId,
      repostedBy: creatorId,
      originalEditId,
      originalCreatorId,
      isRepost: true,
      createdAt: FieldValue.serverTimestamp(),
      publishedAt: FieldValue.serverTimestamp(),
      likesCount: 0,
      commentsCount: 0,
      viewsCount: 0,
      qualifiedViewsCount: 0,
      totalWatchSeconds: 0,
      completionCount: 0,
      score: 10,
      status: "published",
      sharesCount: 0,
      savesCount: 0,
      negativeFeedbackCount: 0,
      impressionsCount: 0,
      replaysCount: 0,
      respectReceivedCount: 0,
      counters: emptyCounters(),
      moderationStatus: "approved",
      moderationReason: null,
      schemaVersion: EDITS_CONFIG.schemaVersion,
    });
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "edit_published",
        userId: creatorId,
        source: "edit",
        metadata: { editId: ref.id, originalEditId },
      });
    }
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
    await ref.update({
      status: "deleted",
      deletedAt: FieldValue.serverTimestamp(),
    });
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
        const changes = { score: FieldValue.increment(4) };
        bump(changes, "likesCount", "likes", 1);
        tx.update(ref, changes);
      } else if (!shouldLike && existing.exists) {
        tx.delete(likeRef);
        const changes = { score: FieldValue.increment(-4) };
        bump(changes, "likesCount", "likes", -1);
        tx.update(ref, changes);
      }
    });
    return { ok: true };
  }

  async function comment(request) {
    const authorId = uid(request);
    const editId = string(request.data?.editId, 128);
    const kind = request.data?.kind === "sticker" ? "sticker" : "text";
    const max = kind === "sticker" ? EDITS_CONFIG.stickerMax : EDITS_CONFIG.commentMax;
    const text = string(request.data?.text, max);
    const replyRaw = request.data?.replyToCommentId;
    const replyToCommentId = replyRaw == null || replyRaw === ""
      ? null
      : string(replyRaw, 128);
    const mentions = Array.isArray(request.data?.mentions)
      ? request.data.mentions
        .filter((item) => typeof item === "string" && item.trim().length <= 32)
        .map((item) => item.trim())
        .slice(0, EDITS_CONFIG.mentionMax)
      : [];
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
        authorId, text, likesCount: 0, replyToCommentId, kind, mentions,
        createdAt: FieldValue.serverTimestamp(),
      });
      const changes = { score: FieldValue.increment(6) };
      bump(changes, "commentsCount", "comments", 1);
      tx.update(ref, changes);
    });
    return { commentId: commentRef.id };
  }

  async function recordImpressionOnly(tx, ref, viewerId, edit) {
    const impressionRef = ref.collection("impressions").doc(viewerId);
    const existing = await tx.get(impressionRef);
    const last = existing.data()?.lastAt?.toDate?.()?.getTime?.() || 0;
    if (existing.exists && Date.now() - last < EDITS_CONFIG.viewabilityMs) {
      return { ok: true, counted: false };
    }
    if (existing.exists && Date.now() - last < 60 * 1000) {
      return { ok: true, counted: false };
    }
    tx.set(impressionRef, {
      viewerId,
      lastAt: FieldValue.serverTimestamp(),
      count: FieldValue.increment(1),
    }, { merge: true });
    if (edit.data()?.creatorId !== viewerId) {
      const changes = {};
      bump(changes, "impressionsCount", "impressions", 1);
      tx.update(ref, changes);
    }
    return { ok: true, counted: true };
  }

  async function recordView(request) {
    const viewerId = uid(request);
    const editId = string(request.data?.editId, 128);
    const sessionId = string(request.data?.sessionId || "", 128);
    const eventType = typeof request.data?.eventType === "string"
      ? request.data.eventType
      : "progress";
    const percent = Number(request.data?.watchPercent);
    const watchSeconds = Math.max(0, Math.min(3600, Number(request.data?.watchSeconds) || 0));
    if (!editId || !Number.isFinite(percent) || percent < 0 || percent > 100) {
      throw new HttpsError("invalid-argument", "View data is invalid.");
    }
    const ref = editRef(editId);
    if (eventType === "impression") {
      await db.runTransaction(async (tx) => {
        const edit = await tx.get(ref);
        if (!edit.exists || edit.data()?.status !== "published") {
          throw new HttpsError("not-found", "Edit not found.");
        }
        await recordImpressionOnly(tx, ref, viewerId, edit);
      });
      return { ok: true };
    }
    if (!sessionId) {
      throw new HttpsError("invalid-argument", "View data is invalid.");
    }
    const viewerRef = ref.collection("viewers").doc(viewerId);
    const sessionRef = ref.collection("playbackSessions").doc(sessionId);
    await db.runTransaction(async (tx) => {
      const [edit, viewer, session] = await Promise.all([
        tx.get(ref), tx.get(viewerRef), tx.get(sessionRef),
      ]);
      if (!edit.exists || edit.data()?.status !== "published") {
        throw new HttpsError("not-found", "Edit not found.");
      }
      const isSelf = edit.data()?.creatorId === viewerId;
      const sessionData = session.data() || {};
      const expires = sessionData.expiresAt?.toDate?.()?.getTime?.() || 0;
      if (!session.exists || sessionData.viewerId !== viewerId ||
          sessionData.consumed === true || expires < Date.now()) {
        throw new HttpsError("failed-precondition", "Playback session is invalid.");
      }
      const lastHeartbeat = sessionData.lastHeartbeatAt?.toDate?.()?.getTime?.() ||
        sessionData.startedAt?.toDate?.()?.getTime?.() || 0;
      const elapsedSeconds = Math.max(0, (Date.now() - lastHeartbeat) / 1000);
      if (elapsedSeconds < 0.15 && eventType === "progress") {
        return;
      }
      if (eventType === "view" && sessionData.viewCounted !== true && !isSelf) {
        const changes = {};
        bump(changes, "viewsCount", "views", 1);
        tx.update(ref, changes);
        tx.update(sessionRef, {
          viewCounted: true,
          lastHeartbeatAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      if (eventType === "replay") {
        if (sessionData.replayCounted !== true && !isSelf) {
          const changes = {};
          bump(changes, "replaysCount", "replays", 1);
          tx.update(ref, changes);
        }
        tx.update(sessionRef, {
          replayCounted: true,
          lastHeartbeatAt: FieldValue.serverTimestamp(),
        });
        return;
      }
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
      const qualified = !isSelf &&
        verifiedPercent >= EDITS_CONFIG.qualifiedViewPercent &&
        Date.now() - last >= 24 * 60 * 60 * 1000;
      const completed = !isSelf &&
        verifiedPercent >= EDITS_CONFIG.completionPercent &&
        previous.completed !== true;
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
        consumed: verifiedPercent >= EDITS_CONFIG.completionPercent,
      });
      const changes = { totalWatchSeconds: FieldValue.increment(watchCredit) };
      if (qualified) {
        bump(changes, "qualifiedViewsCount", "qualifiedViews", 1);
        changes.score = FieldValue.increment(Math.min(5, 2 + watchCredit * 0.05));
      }
      if (completed) {
        bump(changes, "completionCount", "completions", 1);
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
    const previous = await session.get();
    const prior = previous.data() || {};
    const isReplay = previous.exists &&
      (prior.consumed === true || Number(prior.creditedSeconds) > 0);
    await session.set({
      viewerId,
      startedAt: FieldValue.serverTimestamp(),
      lastHeartbeatAt: FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      creditedSeconds: 0,
      consumed: false,
      viewCounted: false,
      replayCounted: false,
    });
    if (isReplay && edit.data()?.creatorId !== viewerId) {
      const changes = {};
      bump(changes, "replaysCount", "replays", 1);
      await ref.update(changes);
    }
    return { sessionId: session.id };
  }

  async function signal(request) {
    const actor = uid(request);
    const editId = string(request.data?.editId, 128);
    const type = request.data?.type;
    const weights = { share: 3, save: 5, unsave: 0, negative: -10 };
    if (!editId || !Object.hasOwn(weights, type)) {
      throw new HttpsError("invalid-argument", "Signal is invalid.");
    }
    const ref = editRef(editId);
    const signalRef = ref.collection("signals").doc(`${actor}_${type === "unsave" ? "save" : type}`);
    await db.runTransaction(async (tx) => {
      const [edit, existing] = await Promise.all([tx.get(ref), tx.get(signalRef)]);
      if (!edit.exists) return;
      if (type === "unsave") {
        if (!existing.exists) return;
        tx.delete(signalRef);
        const changes = { score: FieldValue.increment(-5) };
        bump(changes, "savesCount", "saves", -1);
        tx.update(ref, changes);
        return;
      }
      if (existing.exists) return;
      tx.create(signalRef, { actor, type, createdAt: FieldValue.serverTimestamp() });
      const changes = { score: FieldValue.increment(weights[type]) };
      if (type === "share") bump(changes, "sharesCount", "shares", 1);
      if (type === "save") bump(changes, "savesCount", "saves", 1);
      if (type === "negative") {
        changes.negativeFeedbackCount = FieldValue.increment(1);
      }
      tx.update(ref, changes);
    });
    return { ok: true };
  }

  async function commentAction(request) {
    const actor = uid(request);
    const editId = string(request.data?.editId, 128);
    const commentId = string(request.data?.commentId, 128);
    const action = request.data?.action;
    if (!editId || !commentId || !["like", "unlike", "delete", "report"].includes(action)) {
      throw new HttpsError("invalid-argument", "Comment action is invalid.");
    }
    const edit = editRef(editId);
    const commentRef = edit.collection("comments").doc(commentId);
    await db.runTransaction(async (tx) => {
      const comment = await tx.get(commentRef);
      if (!comment.exists) return;
      if (action === "report") {
        const reportRef = commentRef.collection("reports").doc(actor);
        const existing = await tx.get(reportRef);
        if (existing.exists) return;
        tx.create(reportRef, { actor, createdAt: FieldValue.serverTimestamp() });
        return;
      }
      if (action === "delete") {
        if (comment.data()?.authorId !== actor) {
          throw new HttpsError("permission-denied", "Only the author can delete this comment.");
        }
        tx.delete(commentRef);
        const changes = { score: FieldValue.increment(-6) };
        bump(changes, "commentsCount", "comments", -1);
        tx.update(edit, changes);
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

  async function getEditFeed(request) {
    const viewerId = uid(request);
    const limit = Math.max(1, Math.min(12, Number(request.data?.limit) || EDITS_CONFIG.feedPageSize));
    const afterId = string(request.data?.afterId || "", 128);
    const [userSnap, respectsSnap, listsSnap, published] = await Promise.all([
      db.collection("users").doc(viewerId).get(),
      db.collection("respects").where("fromUserId", "==", viewerId).get().catch(() => ({ docs: [] })),
      db.collection("users").doc(viewerId).collection("animeList").get().catch(() => ({ docs: [] })),
      db.collection("edits")
        .where("status", "==", "published")
        .orderBy("score", "desc")
        .orderBy("createdAt", "desc")
        .limit(80)
        .get(),
    ]);
    const user = userSnap.data() || {};
    const creatorIds = new Set();
    (respectsSnap.docs || []).forEach((doc) => {
      const value = Number(doc.data()?.value) || 0;
      const toUserId = doc.data()?.toUserId;
      if (toUserId && value >= EDITS_CONFIG.fanThreshold) creatorIds.add(toUserId);
    });
    const animeIds = [
      ...((user.favoriteAnimeIds || []).filter(Boolean)),
      ...((listsSnap.docs || []).map((doc) => doc.id)),
    ];
    const profile = {
      userId: viewerId,
      animeIds,
      creatorIds,
      seenIds: new Set(),
      creatorQuality: 0,
    };
    const now = new Date();
    const ranked = (published.docs || [])
      .map((doc) => {
        const data = doc.data() || {};
        return {
          id: doc.id,
          data,
          rank: scoreEdit({ id: doc.id, ...data }, profile, now),
        };
      })
      .sort((a, b) => b.rank - a.rank || String(b.id).localeCompare(String(a.id)));
    let start = 0;
    if (afterId) {
      const index = ranked.findIndex((item) => item.id === afterId);
      start = index >= 0 ? index + 1 : 0;
    }
    const page = ranked.slice(start, start + limit);
    return {
      items: page.map((item) => serializeEdit(item.id, { ...item.data, score: item.rank })),
      hasMore: start + page.length < ranked.length,
    };
  }

  async function retryProcessing(request) {
    const creatorId = uid(request);
    const editId = string(request.data?.editId, 128);
    if (!editId) throw new HttpsError("invalid-argument", "editId is required.");
    const ref = editRef(editId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Edit not found.");
    const data = snap.data() || {};
    if (data.creatorId !== creatorId) {
      throw new HttpsError("permission-denied", "Only the creator can retry this Edit.");
    }
    if (!["failed", "rejected", "uploading"].includes(data.status)) {
      throw new HttpsError("failed-precondition", "This Edit is not waiting for a retry.");
    }
    const videoPath = data.originalStoragePath || data.videoPath;
    if (!videoPath) {
      throw new HttpsError("failed-precondition", "The original video is missing.");
    }
    await ref.update({
      status: "processing",
      failureReason: null,
      processingStartedAt: FieldValue.serverTimestamp(),
    });
    if (typeof processEdit === "function") {
      await processEdit({
        data: { name: videoPath, contentType: "video/mp4", size: EDITS_CONFIG.maxBytes },
      });
    }
    return { ok: true, videoPath };
  }

  return {
    startUpload, repost, deleteEdit, like, comment, startPlayback, recordView, signal,
    commentAction, getEditFeed, retryProcessing,
  };
}

module.exports = { createEditsDomain };
