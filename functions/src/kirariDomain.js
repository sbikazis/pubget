"use strict";

const KIRARI = Object.freeze({
  schemaVersion: 1,
  minDurationSeconds: 3,
  maxDurationSeconds: 60,
  maxBytes: 500 * 1024 * 1024,
  dailyUploadLimit: 10,
  qualifiedViewSeconds: 3,
  completionPercent: 95,
  feedPageSize: 8,
  maxCaption: 2200,
  maxHashtags: 12,
  maxComment: 500,
  uploadLockMs: 2 * 60 * 60 * 1000,
  playbackSessionMs: 10 * 60 * 1000,
  maxWatchEventSeconds: 10,
  explorationRatio: 0.2,
});

const TERMINAL = new Set(["published", "failed", "rejected", "deleted"]);
const TRANSITIONS = Object.freeze({
  uploading: new Set(["processing", "failed", "rejected", "deleted"]),
  processing: new Set(["preparing", "failed", "rejected", "deleted"]),
  preparing: new Set(["published", "failed", "rejected", "deleted"]),
  published: new Set(["deleted"]),
  failed: new Set(["uploading", "processing", "deleted"]),
  rejected: new Set(["deleted"]),
  deleted: new Set(),
});

function cleanString(value, max, field) {
  if (typeof value !== "string") throw new Error(`${field} must be a string`);
  const result = value.trim();
  if (result.length > max) throw new Error(`${field} is too long`);
  return result;
}

function normalizeTags(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > KIRARI.maxHashtags) {
    throw new Error("hashtags are invalid");
  }
  return [...new Set(value.map((item) =>
    cleanString(String(item).replace(/^#/, "").toLowerCase(), 40, "hashtag")
      .replace(/[^a-z0-9_\u0600-\u06ff]/g, ""),
  ).filter(Boolean))];
}

function transitionStatus(current, next) {
  if (current === next) return true;
  return Boolean(TRANSITIONS[current] && TRANSITIONS[current].has(next));
}

function clamp(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(min, Math.min(max, number)) : min;
}

function rankKirari(item, profile, now = Date.now()) {
  const created = item.publishedAt && typeof item.publishedAt.toMillis === "function"
    ? item.publishedAt.toMillis()
    : (item.createdAt && typeof item.createdAt.toMillis === "function"
      ? item.createdAt.toMillis() : Number(item.createdAt) || now);
  const ageHours = Math.max(0, (now - created) / 3600000);
  const freshness = 100 * Math.pow(0.5, ageHours / 72);
  const views = Math.max(1, Number(item.qualifiedViewsCount) || 0);
  const completion = clamp((Number(item.completionCount) || 0) / views * 100, 0, 100);
  const engagement = clamp(
    (Number(item.likesCount) || 0) * 2 +
    (Number(item.commentsCount) || 0) * 3 +
    (Number(item.savesCount) || 0) * 4 +
    (Number(item.sharesCount) || 0) * 3,
    0, 100,
  );
  const negative = clamp((Number(item.negativeFeedbackCount) || 0) * 5, 0, 40);
  const interests = new Set(profile.interests || []);
  const tags = [...(item.hashtags || []), item.audioId, item.animeId].filter(Boolean);
  const relevance = tags.length
    ? tags.filter((tag) => interests.has(tag)).length / tags.length * 100 : 25;
  const social = new Set(profile.creatorIds || []).has(item.creatorId) ? 100 : 0;
  const creatorQuality = clamp(item.creatorQuality || 0, 0, 100);
  return clamp(
    relevance * 0.25 + freshness * 0.15 + completion * 0.15 +
    engagement * 0.15 + social * 0.10 + creatorQuality * 0.10 -
    negative * 0.10,
    0, 100,
  );
}

function createKirariDomain({ db, FieldValue, HttpsError, bucket, processVideo }) {
  const reels = () => db.collection("kirari");
  const fail = (code, message) => { throw new HttpsError(code, message); };
  function auth(request) {
    if (!request.auth || !request.auth.uid) fail("unauthenticated", "Sign in to continue.");
    return request.auth.uid;
  }
  function reelRef(id) { return reels().doc(id); }
  function assertTransition(from, to) {
    if (!transitionStatus(from, to)) {
      fail("failed-precondition", `Invalid Kirari state transition: ${from} → ${to}.`);
    }
  }

  async function startUpload(request) {
    const uid = auth(request);
    let caption, hashtags;
    try {
      caption = cleanString(request.data?.caption || "", KIRARI.maxCaption, "caption");
      hashtags = normalizeTags(request.data?.hashtags);
    } catch (error) {
      fail("invalid-argument", error.message);
    }
    const idempotencyKey = cleanString(request.data?.idempotencyKey || "", 128, "idempotencyKey");
    if (!idempotencyKey) fail("invalid-argument", "An upload idempotency key is required.");
    const day = new Date().toISOString().slice(0, 10);
    const lockRef = db.collection("kirariUploadLocks").doc(uid);
    const quotaRef = db.collection("kirariUploadQuotas").doc(`${uid}_${day}`);
    const keyRef = db.collection("kirariUploadKeys").doc(`${uid}_${idempotencyKey}`);
    const ref = reels().doc();
    const now = Date.now();
    const storagePath = `kirari/${uid}/${ref.id}/source.mp4`;
    const result = await db.runTransaction(async (tx) => {
      const [lock, quota, key] = await Promise.all([
        tx.get(lockRef), tx.get(quotaRef), tx.get(keyRef),
      ]);
      if (key.exists) {
        const existing = key.data();
        return { reelId: existing.reelId, storagePath: existing.storagePath, reused: true };
      }
      const lockData = lock.data() || {};
      const lockUntil = lockData.expiresAt?.toMillis?.() || 0;
      if (lock.exists && lockUntil > now) {
        fail("resource-exhausted", "Another Kirari upload is already active.");
      }
      const used = Number(quota.data()?.count) || 0;
      if (used >= KIRARI.dailyUploadLimit) {
        fail("resource-exhausted", "You have reached today's Kirari upload limit.");
      }
      tx.create(ref, {
        creatorId: uid, caption, hashtags, status: "uploading",
        schemaVersion: KIRARI.schemaVersion,
        storagePath, originalStoragePath: storagePath,
        createdAt: FieldValue.serverTimestamp(),
        durationSeconds: 0, sourceBytes: 0,
        moderationStatus: "pending",
        counters: {
          impressions: 0, views: 0, qualifiedViews: 0,
          completions: 0, replays: 0, likes: 0, comments: 0, saves: 0, shares: 0,
        },
        impressionsCount: 0, viewsCount: 0, qualifiedViewsCount: 0,
        completionCount: 0, replayCount: 0, likesCount: 0,
        commentsCount: 0, savesCount: 0, sharesCount: 0,
        negativeFeedbackCount: 0, rankingScore: 0,
      });
      tx.set(lockRef, {
        reelId: ref.id, storagePath,
        expiresAt: new Date(now + KIRARI.uploadLockMs),
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(quotaRef, {
        uid, day, count: used + 1, updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.create(keyRef, {
        uid, reelId: ref.id, storagePath,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { reelId: ref.id, storagePath, reused: false };
    });
    return result;
  }

  async function finalizeUpload(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists) fail("not-found", "Kirari video not found.");
    const reel = snap.data();
    if (reel.creatorId !== uid) fail("permission-denied", "You do not own this upload.");
    if (reel.status === "published" || reel.status === "processing" ||
        reel.status === "preparing") {
      return { status: reel.status, reelId };
    }
    if (reel.status !== "uploading" && reel.status !== "failed") {
      fail("failed-precondition", "This upload cannot be finalized in its current state.");
    }
    const file = bucket.file(reel.originalStoragePath || reel.storagePath);
    const [exists] = await file.exists();
    if (!exists) fail("failed-precondition", "The uploaded video is missing.");
    const [meta] = await file.getMetadata();
    const size = Number(meta.size || 0);
    const type = String(meta.contentType || "");
    if (size <= 0 || size > KIRARI.maxBytes || !type.startsWith("video/")) {
      assertTransition(reel.status, "failed");
      await ref.update({
        status: "failed", failureReason: "invalid-source",
        failedAt: FieldValue.serverTimestamp(),
      });
      fail("invalid-argument", "Choose a supported video no larger than 500 MB.");
    }
    assertTransition(reel.status, "processing");
    await ref.update({
      status: "processing", sourceBytes: size,
      processingStartedAt: FieldValue.serverTimestamp(),
      failureReason: FieldValue.delete(),
    });
    return { status: "processing", reelId };
  }

  async function setProcessingState(reelId, next, patch = {}) {
    const ref = reelRef(reelId);
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return false;
      const current = snap.data().status;
      if (current === next) return true;
      assertTransition(current, next);
      tx.update(ref, { ...patch, status: next, updatedAt: FieldValue.serverTimestamp() });
      return true;
    });
  }

  async function deleteReel(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists) return { ok: true };
    if (snap.data().creatorId !== uid) fail("permission-denied", "Only the creator can delete this video.");
    if (snap.data().status !== "deleted") {
      assertTransition(snap.data().status, "deleted");
      await ref.update({ status: "deleted", deletedAt: FieldValue.serverTimestamp() });
    }
    const lockRef = db.collection("kirariUploadLocks").doc(uid);
    const lock = await lockRef.get();
    if (lock.exists && lock.data()?.reelId === reelId) await lockRef.delete();
    return { ok: true };
  }

  async function retryProcessing(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists) fail("not-found", "Kirari video not found.");
    const reel = snap.data();
    if (reel.creatorId !== uid) fail("permission-denied", "You do not own this video.");
    if (reel.status === "published") return { status: "published", reelId };
    if (reel.status !== "failed") fail("failed-precondition", "Only failed videos can be retried.");
    const storagePath = reel.originalStoragePath || reel.storagePath;
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (!exists) fail("failed-precondition", "The original video is missing. Upload it again.");
    assertTransition("failed", "processing");
    await ref.update({
      status: "processing",
      failureReason: FieldValue.delete(),
      processingStartedAt: FieldValue.serverTimestamp(),
    });
    if (typeof processVideo !== "function") {
      fail("unavailable", "Kirari processing is temporarily unavailable.");
    }
    await processVideo({ data: { name: storagePath, bucket: bucket.name } });
    const latest = await ref.get();
    return { status: latest.data()?.status || "processing", reelId };
  }

  async function action(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const kind = request.data?.kind;
    const allowed = new Set(["like", "unlike", "save", "unsave", "share", "not_interested", "report"]);
    if (!allowed.has(kind)) fail("invalid-argument", "Unsupported Kirari action.");
    const ref = reelRef(reelId);
    const actionRef = ref.collection("actions").doc(`${uid}_${kind === "unlike" ? "like" : kind === "unsave" ? "save" : kind}`);
    await db.runTransaction(async (tx) => {
      const [reel, existing] = await Promise.all([tx.get(ref), tx.get(actionRef)]);
      if (!reel.exists || reel.data().status !== "published") fail("not-found", "Kirari video not found.");
      if (kind === "report") {
        if (!existing.exists) tx.create(actionRef, {
          uid, kind, reason: cleanString(request.data?.reason || "unspecified", 200, "reason"),
          createdAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      if (kind === "not_interested") {
        if (!existing.exists) tx.create(actionRef, { uid, kind, createdAt: FieldValue.serverTimestamp() });
        return;
      }
      const positive = kind === "like" || kind === "save" || kind === "share";
      if (positive && existing.exists) return;
      if (!positive && !existing.exists) return;
      const counter = kind === "like" || kind === "unlike" ? "likesCount"
        : kind === "save" || kind === "unsave" ? "savesCount" : "sharesCount";
      const amount = kind === "share" || positive ? 1 : -1;
      if (positive) tx.create(actionRef, { uid, kind, createdAt: FieldValue.serverTimestamp() });
      else tx.delete(actionRef);
      tx.update(ref, {
        [counter]: FieldValue.increment(amount),
        [`counters.${counter.replace("Count", "").toLowerCase()}`]: FieldValue.increment(amount),
        rankingScore: FieldValue.increment(kind === "like" ? 2 : kind === "save" ? 4 : kind === "share" ? 3 : -2),
      });
    });
    return { ok: true };
  }

  async function addComment(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    let text;
    try { text = cleanString(request.data?.text, KIRARI.maxComment, "text"); }
    catch (error) { fail("invalid-argument", error.message); }
    if (!text) fail("invalid-argument", "A comment cannot be empty.");
    const parentId = request.data?.parentId
      ? cleanString(request.data.parentId, 128, "parentId") : null;
    const ref = reelRef(reelId);
    const reel = await ref.get();
    if (!reel.exists || reel.data().status !== "published") fail("not-found", "Kirari video not found.");
    const commentRef = ref.collection("comments").doc();
    await db.runTransaction(async (tx) => {
      if (parentId) {
        const parent = await tx.get(ref.collection("comments").doc(parentId));
        if (!parent.exists || parent.data().status === "deleted") {
          fail("not-found", "The comment you're replying to is unavailable.");
        }
      }
      tx.create(commentRef, {
        authorId: uid, text, parentId,
        createdAt: FieldValue.serverTimestamp(),
        likesCount: 0, status: "published",
        creatorComment: uid === reel.data().creatorId,
      });
      tx.update(ref, {
        commentsCount: FieldValue.increment(1),
        "counters.comments": FieldValue.increment(1),
        rankingScore: FieldValue.increment(3),
      });
    });
    return { commentId: commentRef.id };
  }

  async function commentAction(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const commentId = cleanString(request.data?.commentId, 128, "commentId");
    const kind = request.data?.kind;
    if (!["like", "unlike", "delete", "pin", "report"].includes(kind)) {
      fail("invalid-argument", "Unsupported comment action.");
    }
    const ref = reelRef(reelId);
    const commentRef = ref.collection("comments").doc(commentId);
    const actionRef = commentRef.collection("likes").doc(uid);
    await db.runTransaction(async (tx) => {
      const [reel, comment, like] = await Promise.all([
        tx.get(ref), tx.get(commentRef), tx.get(actionRef),
      ]);
      if (!reel.exists || !comment.exists) fail("not-found", "Comment not found.");
      const data = comment.data();
      if (kind === "delete") {
        if (data.authorId !== uid && reel.data().creatorId !== uid) {
          fail("permission-denied", "You cannot delete this comment.");
        }
        if (data.status !== "deleted") {
          tx.update(commentRef, { status: "deleted", deletedAt: FieldValue.serverTimestamp() });
          tx.update(ref, { commentsCount: FieldValue.increment(-1), "counters.comments": FieldValue.increment(-1) });
        }
      } else if (kind === "pin") {
        if (reel.data().creatorId !== uid) fail("permission-denied", "Only the creator can pin a comment.");
        tx.update(commentRef, { pinned: true, pinnedAt: FieldValue.serverTimestamp() });
      } else if (kind === "report") {
        const reportRef = commentRef.collection("reports").doc(uid);
        const report = await tx.get(reportRef);
        if (!report.exists) tx.create(reportRef, { uid, createdAt: FieldValue.serverTimestamp() });
      } else if (kind === "like" && !like.exists) {
        tx.create(actionRef, { uid, createdAt: FieldValue.serverTimestamp() });
        tx.update(commentRef, { likesCount: FieldValue.increment(1) });
      } else if (kind === "unlike" && like.exists) {
        tx.delete(actionRef);
        tx.update(commentRef, { likesCount: FieldValue.increment(-1) });
      }
    });
    return { ok: true };
  }

  async function startPlayback(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists || snap.data().status !== "published") fail("not-found", "Kirari video not found.");
    const sessionRef = ref.collection("playbackSessions").doc();
    const viewerRef = ref.collection("viewers").doc(uid);
    const viewer = await viewerRef.get();
    const replaySession = viewer.exists && viewer.data()?.completed === true;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (!current.exists || current.data().status !== "published") {
        fail("not-found", "Kirari video not found.");
      }
      tx.create(sessionRef, {
        viewerId: uid,
        startedAt: FieldValue.serverTimestamp(),
        lastHeartbeatAt: FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + KIRARI.playbackSessionMs),
        creditedSeconds: 0, qualified: false, completed: false,
        replaySession, replayCounted: false, viewCounted: false,
      });
      if (current.data().creatorId !== uid) {
        tx.update(ref, {
          impressionsCount: FieldValue.increment(1),
          "counters.impressions": FieldValue.increment(1),
        });
      }
    });
    return { sessionId: sessionRef.id };
  }

  async function recordPlayback(request) {
    const uid = auth(request);
    const reelId = cleanString(request.data?.reelId, 128, "reelId");
    const sessionId = cleanString(request.data?.sessionId, 128, "sessionId");
    const watchSeconds = clamp(request.data?.watchSeconds, 0, KIRARI.maxWatchEventSeconds);
    const clientPercent = clamp(request.data?.percent, 0, 100);
    const eventId = cleanString(request.data?.eventId, 128, "eventId");
    if (!eventId) fail("invalid-argument", "Playback event id is required.");
    const ref = reelRef(reelId);
    const sessionRef = ref.collection("playbackSessions").doc(sessionId);
    const eventRef = sessionRef.collection("events").doc(eventId);
    const viewerRef = ref.collection("viewers").doc(uid);
    await db.runTransaction(async (tx) => {
      const [reel, session, event, viewer] = await Promise.all([
        tx.get(ref), tx.get(sessionRef), tx.get(eventRef), tx.get(viewerRef),
      ]);
      if (!reel.exists || reel.data().status !== "published") fail("not-found", "Kirari video not found.");
      if (!session.exists || session.data().viewerId !== uid) fail("permission-denied", "Playback session is invalid.");
      if (event.exists) return;
      const data = session.data();
      if (data.expiresAt?.toMillis?.() < Date.now()) fail("failed-precondition", "Playback session expired.");
      const last = data.lastHeartbeatAt?.toMillis?.() || Date.now();
      const elapsed = clamp((Date.now() - last) / 1000, 0, KIRARI.maxWatchEventSeconds);
      const duration = Math.max(3, Number(reel.data().durationSeconds) || 60);
      const credited = Math.min(
        Number(data.creditedSeconds || 0) + Math.min(watchSeconds, elapsed + 1),
        duration,
      );
      const verifiedPercent = Math.min(clientPercent, credited / duration * 100);
      const viewerData = viewer.data() || {};
      const lastQualifiedAt = viewerData.lastQualifiedAt?.toMillis?.() || 0;
      const qualified = reel.data().creatorId !== uid &&
        !data.qualified && verifiedPercent >= 100 * KIRARI.qualifiedViewSeconds / duration &&
        Date.now() - lastQualifiedAt >= 24 * 60 * 60 * 1000;
      const completed = !data.completed && verifiedPercent >= KIRARI.completionPercent;
      const replayed = data.replaySession === true &&
        data.replayCounted !== true && verifiedPercent >= KIRARI.completionPercent;
      tx.update(sessionRef, {
        lastHeartbeatAt: FieldValue.serverTimestamp(),
        creditedSeconds: credited,
        qualified: data.qualified === true || qualified,
        completed: data.completed === true || completed,
        replayCounted: data.replayCounted === true || replayed,
      });
      if (qualified) {
        tx.update(ref, {
          qualifiedViewsCount: FieldValue.increment(1),
          viewsCount: FieldValue.increment(1),
          "counters.qualifiedViews": FieldValue.increment(1),
          "counters.views": FieldValue.increment(1),
        });
      }
      if (completed) {
        tx.update(ref, {
          completionCount: FieldValue.increment(1),
          "counters.completions": FieldValue.increment(1),
        });
      }
      if (replayed) {
        tx.update(ref, {
          replayCount: FieldValue.increment(1),
          "counters.replays": FieldValue.increment(1),
        });
      }
      if (qualified || completed) {
        tx.set(viewerRef, {
          ...(qualified ? { lastQualifiedAt: FieldValue.serverTimestamp() } : {}),
          ...(completed ? { completed: true, lastCompletedAt: FieldValue.serverTimestamp() } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      tx.create(eventRef, {
        viewerId: uid, watchSeconds, verifiedPercent,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function getFeed(request) {
    const uid = auth(request);
    const type = request.data?.type || "forYou";
    if (!["forYou", "following", "trending"].includes(type)) fail("invalid-argument", "Unknown Kirari feed.");
    const limit = Math.round(clamp(request.data?.limit || KIRARI.feedPageSize, 1, 12));
    const afterScore = Number(request.data?.afterScore);
    const afterId = request.data?.afterId || null;
    const profileSnap = await db.collection("users").doc(uid).get();
    const profile = profileSnap.data() || {};
    const [blocked, interests, follows] = await Promise.all([
      db.collection("friendships").where("userIds", "array-contains", uid).get().catch(() => ({ docs: [] })),
      db.collection("users").doc(uid).collection("kirariInterests").get().catch(() => ({ docs: [] })),
      db.collection("respects").where("fromUserId", "==", uid).get().catch(() => ({ docs: [] })),
    ]);
    const blockedIds = new Set((blocked.docs || [])
      .filter((doc) => doc.data()?.status === "blocked")
      .flatMap((doc) => (doc.data()?.userIds || []).filter((id) => id !== uid)));
    const creatorIds = new Set((follows.docs || [])
      .filter((doc) => Number(doc.data()?.value || 0) >= 5)
      .map((doc) => doc.data()?.toUserId).filter(Boolean));
    const interestIds = (interests.docs || []).map((doc) => doc.id);
    const query = reels().where("status", "==", "published")
      .orderBy(type === "trending" ? "velocityScore" : "rankingScore", "desc")
      .orderBy("publishedAt", "desc").limit(100);
    const snap = await query.get();
    let items = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => !blockedIds.has(item.creatorId) && item.creatorId !== uid);
    if (type === "following") items = items.filter((item) => creatorIds.has(item.creatorId));
    const now = Date.now();
    if (type === "forYou") {
      const profileData = { interests: interestIds, creatorIds: [...creatorIds] };
      items = items.map((item) => ({ ...item, _rank: rankKirari(item, profileData, now) }))
        .sort((a, b) => b._rank - a._rank);
      const seenSnap = await db.collection("users").doc(uid).collection("kirariSeen").limit(500).get();
      const seen = new Set(seenSnap.docs.map((doc) => doc.id));
      const fresh = items.filter((item) => !seen.has(item.id));
      const explored = fresh.filter((item) => !interestIds.some((tag) => (item.hashtags || []).includes(tag)));
      const relevant = fresh.filter((item) => !explored.includes(item));
      const exploreCount = Math.max(1, Math.round(limit * KIRARI.explorationRatio));
      items = [...relevant.slice(0, limit - exploreCount), ...explored.slice(0, exploreCount)]
        .sort((a, b) => b._rank - a._rank);
    }
    if (Number.isFinite(afterScore) && afterId) {
      const index = items.findIndex((item) => item.id === afterId);
      if (index >= 0) items = items.slice(index + 1);
    }
    const page = items.slice(0, limit).map(({ _rank, ...item }) => ({
      ...item, rankingScore: _rank ?? item.rankingScore ?? 0,
    }));
    const batch = db.batch();
    for (const item of page) {
      batch.set(db.collection("users").doc(uid).collection("kirariSeen").doc(item.id), {
        seenAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    if (page.length) await batch.commit();
    return {
      items: page,
      hasMore: items.length > limit,
      nextCursor: page.length ? { afterId: page[page.length - 1].id, afterScore: page[page.length - 1].rankingScore } : null,
    };
  }

  return {
    startUpload, finalizeUpload, retryProcessing, deleteReel, action, addComment, commentAction,
    startPlayback, recordPlayback, getFeed, setProcessingState,
  };
}

module.exports = {
  KIRARI, TRANSITIONS, transitionStatus, normalizeTags, rankKirari,
  createKirariDomain,
};
