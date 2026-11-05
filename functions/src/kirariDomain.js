"use strict";

const { moderateEditCopy } = require("./contentFilter");
const { randomUUID } = require("node:crypto");

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

function normalizeEditSettings(value) {
  const input = value && typeof value === "object" ? value : {};
  const speed = clamp(input.speed ?? 1, 0.5, 2);
  const filter = ["none", "warm", "cool", "mono", "vivid"].includes(input.filter)
    ? input.filter : "none";
  const overlayText = typeof input.overlayText === "string"
    ? input.overlayText.trim().slice(0, 80) : "";
  const trimStartSeconds = clamp(input.trimStartSeconds ?? 0, 0, 60);
  const trimEndSeconds = clamp(input.trimEndSeconds ?? 60, 3, 60);
  const coverTimeSeconds = clamp(input.coverTimeSeconds ?? trimStartSeconds, 0, 60);
  return {
    trimStartSeconds, trimEndSeconds, speed, filter,
    overlayText, coverTimeSeconds,
  };
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
  const views = Math.max(0, Number(item.qualifiedViewsCount) || 0);
  const priorViews = 5;
  const completion = clamp(
    ((Number(item.completionCount) || 0) + 0.5 * priorViews) / (views + priorViews) * 100,
    0, 100,
  );
  const engagement = clamp(
    (Number(item.likesCount) || 0) * 2 +
    (Number(item.commentsCount) || 0) * 3 +
    (Number(item.savesCount) || 0) * 4 +
    (Number(item.sharesCount) || 0) * 3,
    0, 100,
  );
  const negative = clamp((Number(item.negativeFeedbackCount) || 0) * 5, 0, 40);
  const interests = new Set(profile.interests || []);
  const tags = [...new Set([
    ...(item.hashtags || []), ...(item.animeIds || []), ...(item.characterIds || []),
    item.audioId, item.animeId,
  ].filter(Boolean))];
  const relevance = tags.length
    ? tags.filter((tag) => interests.has(tag)).length / tags.length * 100 : 25;
  const social = new Set(profile.creatorIds || []).has(item.creatorId) ? 100 : 0;
  const creatorQuality = clamp(item.creatorQuality || 0, 0, 100);
  // Only server-maintained aggregates are consumed here. Client-provided
  // playback percentages and counters are never ranking inputs.
  const watchSeconds = Math.max(0, Number(item.totalQualifiedWatchSeconds) || 0);
  const averageWatch = views > 0 ? watchSeconds / views : 0;
  const watchQuality = clamp(
    averageWatch / Math.max(3, Number(item.durationSeconds) || 15) * 100, 0, 100,
  );
  const skips = Math.max(0, Number(item.earlySkipCount) || 0);
  const skipRate = clamp(skips / Math.max(1, views) * 100, 0, 100);
  const replays = Math.max(0, Number(item.replayCount) || 0);
  const replayRate = clamp(replays / Math.max(1, views) * 100, 0, 100);
  return clamp(
    relevance * 0.24 + freshness * 0.10 + completion * 0.14 +
    watchQuality * 0.18 + replayRate * 0.07 + engagement * 0.10 +
    social * 0.07 + creatorQuality * 0.10 -
    negative * 0.10 - skipRate * 0.12,
    0, 100,
  );
}

function diversifyKirari(items, limit, explorationRatio = KIRARI.explorationRatio) {
  const pool = [...items];
  const relevant = pool.filter((item) => item._relevant === true);
  const explore = pool.filter((item) => item._relevant !== true);
  const exploreCount = Math.min(limit, Math.max(0, Math.round(limit * explorationRatio)));
  const targets = [
    ...relevant.slice(0, Math.max(0, limit - exploreCount)),
    ...explore.slice(0, exploreCount),
  ];
  const selected = [];
  const creatorCounts = new Map();
  const animeCounts = new Map();
  const deferred = [];
  for (const item of targets) {
    const creator = item.creatorId || item.id;
    const anime = item.animeId || (item.animeIds || [])[0] || null;
    if ((creatorCounts.get(creator) || 0) >= 2 ||
        (anime && (animeCounts.get(anime) || 0) >= 2)) {
      deferred.push(item);
      continue;
    }
    selected.push(item);
    creatorCounts.set(creator, (creatorCounts.get(creator) || 0) + 1);
    if (anime) animeCounts.set(anime, (animeCounts.get(anime) || 0) + 1);
    if (selected.length >= limit) break;
  }
  if (selected.length < limit) {
    for (const item of [...deferred, ...pool]) {
      if (selected.some((entry) => entry.id === item.id)) continue;
      const creator = item.creatorId || item.id;
      const anime = item.animeId || (item.animeIds || [])[0] || null;
      if ((creatorCounts.get(creator) || 0) >= 2 ||
          (anime && (animeCounts.get(anime) || 0) >= 2)) continue;
      selected.push(item);
      creatorCounts.set(creator, (creatorCounts.get(creator) || 0) + 1);
      if (anime) animeCounts.set(anime, (animeCounts.get(anime) || 0) + 1);
      if (selected.length >= limit) break;
    }
  }
  return selected;
}
function isFeedCursorAfter(score, id, afterScore, afterId) {
  if (!Number.isFinite(afterScore) || !afterId) return true;
  return score < afterScore || (score === afterScore && String(id).localeCompare(String(afterId)) > 0);
}

function createKirariDomain({ db, FieldValue, HttpsError, bucket, processVideo }) {
  const reels = () => db.collection("kirari");
  const fail = (code, message) => { throw new HttpsError(code, message); };
  function auth(request) {
    if (!request.auth || !request.auth.uid) fail("unauthenticated", "Sign in to continue.");
    return request.auth.uid;
  }
  function inputString(value, max, field) {
    try {
      return cleanString(value, max, field);
    } catch (error) {
      fail("invalid-argument", error.message);
    }
  }
  function inputId(value, field) {
    const id = inputString(value, 128, field);
    if (!/^[A-Za-z0-9_-]+$/.test(id)) {
      fail("invalid-argument", field + " contains unsupported characters.");
    }
    return id;
  }
  function reelRef(id) { return reels().doc(inputId(id, "reelId")); }
  function assertTransition(from, to) {
    if (!transitionStatus(from, to)) {
      fail("failed-precondition", `Invalid Kirari state transition: ${from} → ${to}.`);
    }
  }

  async function isBlockedPair(uid, otherUid) {
    if (!otherUid || uid === otherUid) return false;
    const [userA, userB] = [uid, otherUid].sort();
    const refs = [
      db.collection("friendships").doc(userA.length + ":" + userA + userB.length + ":" + userB),
      db.collection("friendships").doc(userA + "_" + userB),
    ];
    // Fail closed: a friendship lookup failure must never silently expose
    // content from a user who may have blocked the viewer (or vice versa).
    const docs = await Promise.all(refs.map((ref) => ref.get()));
    return docs.some((doc) => doc.exists && doc.data()?.status === "blocked");
  }

  async function excludedCreatorIds(uid) {
    // Privacy filters are security decisions, not optional personalization.
    // If any source is unavailable, reject the request rather than return an
    // unfiltered feed.
    const [blockedByA, blockedByB, blockedLegacy, muted] = await Promise.all([
      db.collection("friendships").where("userA", "==", uid).get(),
      db.collection("friendships").where("userB", "==", uid).get(),
      db.collection("friendships").where("userIds", "array-contains", uid).get(),
      db.collection("users").doc(uid).collection("kirariMutedCreators").get(),
    ]);
    const docs = [...(blockedByA.docs || []), ...(blockedByB.docs || []), ...(blockedLegacy.docs || [])];
    const blocked = docs.filter((doc) => doc.data()?.status === "blocked").flatMap((doc) => {
      const data = doc.data() || {};
      return (data.userIds || [data.userA, data.userB]).filter((id) => id && id !== uid);
    });
    return new Set([...blocked, ...(muted.docs || []).map((doc) => doc.id)]);
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
    const idempotencyKey = inputString(request.data?.idempotencyKey || "", 128, "idempotencyKey");
    if (!/^[A-Za-z0-9_-]{8,128}$/.test(idempotencyKey)) {
      fail("invalid-argument", "The upload idempotency key has an invalid format.");
    }
    const editSettings = normalizeEditSettings(request.data?.editSettings);
    const audioId = request.data?.audioId == null ? null : inputId(request.data.audioId, "audioId");
    if (audioId) {
      const audioSnap = await db.collection("kirariAudio").doc(audioId).get();
      if (!audioSnap.exists || audioSnap.data()?.status !== "approved" || audioSnap.data()?.allowReuse !== true) {
        fail("failed-precondition", "This audio track is not available for reuse.");
      }
    }
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
        creatorId: uid, caption, hashtags, audioId, editSettings, status: "uploading",
        idempotencyKey, quotaDay: day,
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
        negativeFeedbackCount: 0, earlySkipCount: 0,
        totalQualifiedWatchSeconds: 0, rankingScore: 0,
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
    const reelId = inputString(request.data?.reelId, 128, "reelId");
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
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists) return { ok: true };
    if (snap.data().creatorId !== uid) fail("permission-denied", "Only the creator can delete this video.");
    const reel = snap.data();
    if (reel.status !== "deleted") {
      assertTransition(reel.status, "deleted");
      await ref.update({ status: "deleted", deletedAt: FieldValue.serverTimestamp() });
    }
    if (["uploading", "failed"].includes(reel.status)) {
      if (reel.quotaDay) {
        const quotaRef = db.collection("kirariUploadQuotas").doc(uid + "_" + reel.quotaDay);
        const quota = await quotaRef.get();
        if (quota.exists) {
          await quotaRef.update({
            count: Math.max(0, Number(quota.data()?.count || 0) - 1),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      if (reel.idempotencyKey) {
        await db.collection("kirariUploadKeys").doc(uid + "_" + reel.idempotencyKey).delete().catch(() => {});
      }
    }
    const lockRef = db.collection("kirariUploadLocks").doc(uid);
    const lock = await lockRef.get();
    if (lock.exists && lock.data()?.reelId === reelId) await lockRef.delete();
    const paths = [
      reel.originalStoragePath || reel.storagePath,
      reel.coverPath,
      ...Object.values(reel.renditions || {}).map((item) => item && item.path),
    ].filter((value) => typeof value === "string" && value.length > 0);
    await Promise.all(paths.map((value) =>
      bucket.file(value).delete({ ignoreNotFound: true }).catch(() => {}),
    ));
    return { ok: true };
  }

  async function retryProcessing(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
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
    const [metadata] = await file.getMetadata();
    assertTransition("failed", "processing");
    await ref.update({
      status: "processing",
      failureReason: FieldValue.delete(),
      processingStartedAt: FieldValue.serverTimestamp(),
    });
    if (typeof processVideo !== "function") {
      fail("unavailable", "Kirari processing is temporarily unavailable.");
    }
    await processVideo({ data: {
      name: storagePath,
      bucket: bucket.name,
      size: Number(metadata.size || 0),
      contentType: metadata.contentType || "video/mp4",
    } });
    const latest = await ref.get();
    return { status: latest.data()?.status || "processing", reelId };
  }

  async function cancelUpload(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const lockRef = db.collection("kirariUploadLocks").doc(uid);
    const initial = await ref.get();
    if (!initial.exists) return { ok: true };
    const initialData = initial.data();
    if (initialData.creatorId !== uid) fail("permission-denied", "You do not own this upload.");
    if (!["uploading", "failed"].includes(initialData.status)) {
      fail("failed-precondition", "This upload can no longer be canceled.");
    }
    const quotaRef = initialData.quotaDay
      ? db.collection("kirariUploadQuotas").doc(uid + "_" + initialData.quotaDay) : null;
    const keyRef = initialData.idempotencyKey
      ? db.collection("kirariUploadKeys").doc(uid + "_" + initialData.idempotencyKey) : null;
    await db.runTransaction(async (tx) => {
      const reads = [tx.get(ref), tx.get(lockRef)];
      if (quotaRef) reads.push(tx.get(quotaRef));
      if (keyRef) reads.push(tx.get(keyRef));
      const snapshots = await Promise.all(reads);
      const current = snapshots[0];
      if (!current.exists || current.data().creatorId !== uid) {
        fail("not-found", "Kirari upload not found.");
      }
      if (!["uploading", "failed"].includes(current.data().status)) {
        fail("failed-precondition", "This upload can no longer be canceled.");
      }
      assertTransition(current.data().status, "deleted");
      tx.update(ref, { status: "deleted", deletedAt: FieldValue.serverTimestamp() });
      const lock = snapshots[1];
      if (lock.exists && lock.data()?.reelId === reelId) tx.delete(lockRef);
      let cursor = 2;
      if (quotaRef) {
        const quota = snapshots[cursor++];
        if (quota.exists) {
          tx.update(quotaRef, {
            count: Math.max(0, Number(quota.data()?.count || 0) - 1),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      if (keyRef && snapshots[cursor]?.exists) tx.delete(keyRef);
    });
    const storagePath = initialData.originalStoragePath || initialData.storagePath;
    if (storagePath) await bucket.file(storagePath).delete({ ignoreNotFound: true }).catch(() => {});
    return { ok: true };
  }

  async function revokeReelDownloadTokens(reel) {
    const paths = [
      reel.coverPath,
      ...Object.values(reel.renditions || {}).map((item) => item && item.path),
    ].filter((value) => typeof value === "string" && value.length > 0);
    await Promise.all(paths.map(async (storagePath) => {
      const file = bucket.file(storagePath);
      try {
        const [metadata] = await file.getMetadata();
        await file.setMetadata({
          metadata: {
            ...(metadata.metadata || {}),
            firebaseStorageDownloadTokens: randomUUID(),
          },
        });
      } catch (_) {
        // A missing rendition does not block moderation or deletion.
      }
    }));
  }

  async function action(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const kind = request.data?.kind;
    const allowed = new Set(["like", "unlike", "save", "unsave", "share", "not_interested", "undo_not_interested", "report"]);
    if (!allowed.has(kind)) fail("invalid-argument", "Unsupported Kirari action.");
    const ref = reelRef(reelId);
    const actionRef = ref.collection("actions").doc(`${uid}_${kind === "unlike" ? "like" : kind === "unsave" ? "save" : kind === "undo_not_interested" ? "not_interested" : kind}`);
    const parent = await ref.get();
    if (!parent.exists || parent.data()?.status !== "published" || parent.data()?.moderationStatus !== "approved" || (kind !== "report" && await isBlockedPair(uid, parent.data()?.creatorId))) fail("not-found", "Kirari video not found.");
    await db.runTransaction(async (tx) => {
      const [reel, existing] = await Promise.all([tx.get(ref), tx.get(actionRef)]);
      if (!reel.exists || reel.data().status !== "published") fail("not-found", "Kirari video not found.");
      if (kind !== "report" && reel.data().moderationStatus !== "approved") {
        fail("not-found", "Kirari video not found.");
      }
      if (kind === "report") {
        if (!existing.exists) {
          tx.create(actionRef, {
            uid, kind, reason: inputString(request.data?.reason || "unspecified", 200, "reason"),
            createdAt: FieldValue.serverTimestamp(),
          });
          const reportCount = Number(reel.data()?.reportsCount || 0) + 1;
          tx.update(ref, {
            reportsCount: FieldValue.increment(1),
            ...(reportCount >= 3 ? { moderationStatus: "review_pending" } : {}),
          });
          if (reportCount >= 3) {
            tx.set(db.collection("kirariModerationQueue").doc("reel_" + reelId), {
              contentType: "reel", reelId, status: "pending",
              reportCount, queuedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
          }
        }
        return;
      }
      if (kind === "not_interested") {
        if (!existing.exists) {
          tx.create(actionRef, { uid, kind, createdAt: FieldValue.serverTimestamp() });
          tx.update(ref, { negativeFeedbackCount: FieldValue.increment(1) });
        }
        tx.set(db.collection("users").doc(uid).collection("kirariNotInterested").doc(reelId), {
          createdAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      if (kind === "undo_not_interested") {
        if (existing.exists) {
          tx.delete(actionRef);
          tx.update(ref, { negativeFeedbackCount: FieldValue.increment(-1) });
        }
        tx.delete(db.collection("users").doc(uid).collection("kirariNotInterested").doc(reelId));
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
        velocityScore: FieldValue.increment(kind === "like" ? 2 : kind === "save" ? 4 : kind === "share" ? 3 : -2),
      });
    });
    if (kind === "report") {
      const updated = await ref.get();
      if (updated.exists && updated.data()?.moderationStatus === "review_pending") {
        await revokeReelDownloadTokens(updated.data());
      }
    }
    return { ok: true };
  }

  async function addComment(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    let text;
    try { text = inputString(request.data?.text, KIRARI.maxComment, "text"); }
    catch (error) { fail("invalid-argument", error.message); }
    if (!text) fail("invalid-argument", "A comment cannot be empty.");
    const moderation = moderateEditCopy({ caption: text, animeTag: "" });
    if (moderation.flagged) fail("failed-precondition", moderation.reason || "This comment needs moderation.");
    const parentId = request.data?.parentId
      ? inputId(request.data.parentId, "parentId") : null;
    const ref = reelRef(reelId);
    const reel = await ref.get();
    if (!reel.exists || reel.data().status !== "published" || reel.data().moderationStatus !== "approved" || await isBlockedPair(uid, reel.data().creatorId)) fail("not-found", "Kirari video not found.");
    const commentRef = ref.collection("comments").doc();
    const rateRef = db.collection("kirariCommentRateLimits").doc(uid);
    await db.runTransaction(async (tx) => {
      const rate = await tx.get(rateRef);
      const lastCommentAt = rate.data()?.lastCommentAt?.toMillis?.() || 0;
      if (Date.now() - lastCommentAt < 2000) {
        fail("resource-exhausted", "Please wait before posting another comment.");
      }
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
        velocityScore: FieldValue.increment(3),
      });
      tx.set(rateRef, { lastCommentAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    return { commentId: commentRef.id };
  }

  async function commentAction(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const commentId = inputId(request.data?.commentId, "commentId");
    const kind = request.data?.kind;
    if (!["like", "unlike", "delete", "pin", "report"].includes(kind)) {
      fail("invalid-argument", "Unsupported comment action.");
    }
    const ref = reelRef(reelId);
    const commentRef = ref.collection("comments").doc(commentId);
    const actionRef = commentRef.collection("likes").doc(uid);
    const parent = await ref.get();
    if (!parent.exists || parent.data()?.status !== "published" || parent.data()?.moderationStatus !== "approved" || await isBlockedPair(uid, parent.data()?.creatorId)) fail("not-found", "Comment not found.");
    await db.runTransaction(async (tx) => {
      const [reel, comment, like] = await Promise.all([
        tx.get(ref), tx.get(commentRef), tx.get(actionRef),
      ]);
      if (!reel.exists || reel.data()?.status !== "published" || reel.data()?.moderationStatus !== "approved" || !comment.exists) fail("not-found", "Comment not found.");
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
        if (!report.exists) {
          tx.create(reportRef, { uid, createdAt: FieldValue.serverTimestamp() });
          const reportCount = Number(data.reportsCount || 0) + 1;
          tx.update(commentRef, {
            reportsCount: FieldValue.increment(1),
            ...(reportCount >= 3 ? { status: "review_pending" } : {}),
          });
          if (reportCount >= 3) {
            tx.set(db.collection("kirariModerationQueue").doc("comment_" + reelId + "_" + commentId), {
              contentType: "comment", reelId, commentId, status: "pending",
              reportCount, queuedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
          }
        }
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
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const ref = reelRef(reelId);
    const snap = await ref.get();
    if (!snap.exists || snap.data().status !== "published" || snap.data().moderationStatus !== "approved" || await isBlockedPair(uid, snap.data().creatorId)) fail("not-found", "Kirari video not found.");
    const sessionRef = ref.collection("playbackSessions").doc();
    const viewerRef = ref.collection("viewers").doc(uid);
    const activeRef = db.collection("users").doc(uid)
      .collection("kirariPlaybackState").doc("active");
    await db.runTransaction(async (tx) => {
      const [current, viewer, active] = await Promise.all([
        tx.get(ref), tx.get(viewerRef), tx.get(activeRef),
      ]);
      if (!current.exists || current.data().status !== "published" ||
          current.data().moderationStatus !== "approved") {
        fail("not-found", "Kirari video not found.");
      }

      // A server-observed transition to another reel is the only skip signal.
      // We never accept a client "skip" flag or a client-supplied duration.
      const activeData = active.data() || {};
      if (active.exists && activeData.reelId && activeData.sessionId &&
          activeData.reelId !== reelId) {
        const previousRef = reelRef(activeData.reelId);
        const previousSessionRef = previousRef.collection("playbackSessions")
          .doc(activeData.sessionId);
        const [previousReel, previousSession] = await Promise.all([
          tx.get(previousRef), tx.get(previousSessionRef),
        ]);
        if (previousReel.exists && previousSession.exists) {
          const previous = previousSession.data() || {};
          const lastHeartbeat = previous.lastHeartbeatAt?.toMillis?.() ||
            previous.startedAt?.toMillis?.() || 0;
          const sinceHeartbeatMs = Date.now() - lastHeartbeat;
          const credited = Math.max(0, Number(previous.creditedSeconds) || 0);
          const shouldCountSkip = previous.viewerId === uid &&
            previous.qualified !== true && previous.skipCounted !== true &&
            credited < KIRARI.qualifiedViewSeconds &&
            sinceHeartbeatMs >= 500 && sinceHeartbeatMs <= 15000 &&
            previousReel.data()?.creatorId !== uid &&
            previousReel.data()?.status === "published";
          if (shouldCountSkip) {
            tx.update(previousSessionRef, {
              skipCounted: true,
              endedByNextPlaybackAt: FieldValue.serverTimestamp(),
            });
            tx.update(previousRef, {
              earlySkipCount: FieldValue.increment(1),
              velocityScore: FieldValue.increment(-0.25),
            });
          }
        }
      }

      const viewerData = viewer.data() || {};
      const replaySession = viewerData.completed === true;
      const lastImpressionAt = viewerData.lastImpressionAt?.toMillis?.() || 0;
      const countImpression = current.data().creatorId !== uid &&
        Date.now() - lastImpressionAt >= 24 * 60 * 60 * 1000;
      tx.create(sessionRef, {
        viewerId: uid,
        startedAt: FieldValue.serverTimestamp(),
        lastHeartbeatAt: FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + KIRARI.playbackSessionMs),
        creditedSeconds: 0, qualified: false, completed: false,
        replaySession, replayCounted: false, viewCounted: false,
        skipCounted: false,
      });
      tx.set(activeRef, {
        reelId, sessionId: sessionRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (countImpression) {
        tx.update(ref, {
          impressionsCount: FieldValue.increment(1),
          "counters.impressions": FieldValue.increment(1),
        });
        tx.set(viewerRef, { lastImpressionAt: FieldValue.serverTimestamp() }, { merge: true });
      }
    });
    return { sessionId: sessionRef.id };
  }

  async function recordPlayback(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const sessionId = inputId(request.data?.sessionId, "sessionId");
    const watchSeconds = clamp(request.data?.watchSeconds, 0, KIRARI.maxWatchEventSeconds);
    const clientPercent = clamp(request.data?.percent, 0, 100);
    const eventId = inputId(request.data?.eventId, "eventId");
    if (!eventId) fail("invalid-argument", "Playback event id is required.");
    const ref = reelRef(reelId);
    const sessionRef = ref.collection("playbackSessions").doc(sessionId);
    const eventRef = sessionRef.collection("events").doc(eventId);
    const viewerRef = ref.collection("viewers").doc(uid);
    const seenRef = db.collection("users").doc(uid).collection("kirariSeen").doc(reelId);
    await db.runTransaction(async (tx) => {
      const [reel, session, event, viewer, seen] = await Promise.all([
        tx.get(ref), tx.get(sessionRef), tx.get(eventRef), tx.get(viewerRef), tx.get(seenRef),
      ]);
      if (!reel.exists || reel.data().status !== "published" || reel.data().moderationStatus !== "approved") fail("not-found", "Kirari video not found.");
      if (!session.exists || session.data().viewerId !== uid) fail("permission-denied", "Playback session is invalid.");
      if (event.exists) return;
      const data = session.data();
      if (data.expiresAt?.toMillis?.() < Date.now()) fail("failed-precondition", "Playback session expired.");
      const last = data.lastHeartbeatAt?.toMillis?.() || Date.now();
      const elapsed = clamp((Date.now() - last) / 1000, 0, KIRARI.maxWatchEventSeconds);
      const duration = Math.max(3, Number(reel.data().durationSeconds) || 60);
      const previousCredited = Math.max(0, Number(data.creditedSeconds || 0));
      const credited = Math.min(
        previousCredited + Math.min(watchSeconds, elapsed + 1),
        duration,
      );
      const creditedDelta = Math.max(0, credited - previousCredited);
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
      if (qualified || (data.qualified === true && creditedDelta > 0)) {
        tx.update(ref, {
          ...(qualified ? {
            qualifiedViewsCount: FieldValue.increment(1),
            viewsCount: FieldValue.increment(1),
            "counters.qualifiedViews": FieldValue.increment(1),
            "counters.views": FieldValue.increment(1),
            velocityScore: FieldValue.increment(1),
          } : {}),
          totalQualifiedWatchSeconds: FieldValue.increment(creditedDelta),
        });
      }
      if (completed) {
        tx.update(ref, {
          completionCount: FieldValue.increment(1),
          "counters.completions": FieldValue.increment(1),
          velocityScore: FieldValue.increment(2),
        });
      }
      if (replayed) {
        tx.update(ref, {
          replayCount: FieldValue.increment(1),
          "counters.replays": FieldValue.increment(1),
          velocityScore: FieldValue.increment(1),
        });
      }
      if (qualified || completed) {
        tx.set(viewerRef, {
          ...(qualified ? { lastQualifiedAt: FieldValue.serverTimestamp() } : {}),
          ...(completed ? { completed: true, lastCompletedAt: FieldValue.serverTimestamp() } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      // A reel becomes "seen" only after server-credited qualified playback,
      // never merely because the feed response was fetched or prefetched.
      if (qualified && !seen.exists) {
        tx.set(seenRef, { seenAt: FieldValue.serverTimestamp() }, { merge: true });
      }
      tx.create(eventRef, {
        viewerId: uid, watchSeconds, verifiedPercent,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function reviewContent(request) {
    if (!request.auth || request.auth.token?.admin !== true) {
      fail("permission-denied", "Administrator access is required.");
    }
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const decision = request.data?.decision;
    if (!["approved", "rejected"].includes(decision)) {
      fail("invalid-argument", "Decision must be approved or rejected.");
    }
    const commentId = request.data?.commentId
      ? inputId(request.data.commentId, "commentId") : null;
    const reelRefValue = reelRef(reelId);
    if (commentId) {
      const commentRef = reelRefValue.collection("comments").doc(commentId);
      const queueRef = db.collection("kirariModerationQueue").doc("comment_" + reelId + "_" + commentId);
      await db.runTransaction(async (tx) => {
        const [reel, comment] = await Promise.all([tx.get(reelRefValue), tx.get(commentRef)]);
        if (!reel.exists || !comment.exists) fail("not-found", "Reported comment not found.");
        if (comment.data()?.status !== "review_pending") {
          fail("failed-precondition", "This comment is not awaiting moderation review.");
        }
        tx.update(commentRef, {
          status: decision === "approved" ? "published" : "rejected",
          moderationStatus: decision,
          reviewedBy: request.auth.uid,
          reviewedAt: FieldValue.serverTimestamp(),
        });
        tx.set(queueRef, {
          status: "resolved", decision, reviewedBy: request.auth.uid,
          resolvedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });
    } else {
      const queueRef = db.collection("kirariModerationQueue").doc("reel_" + reelId);
      let reviewedReel = null;
      await db.runTransaction(async (tx) => {
        const reel = await tx.get(reelRefValue);
        if (!reel.exists) fail("not-found", "Reported video not found.");
        if (!["published", "rejected"].includes(reel.data()?.status) ||
            reel.data()?.moderationStatus !== "review_pending") {
          fail("failed-precondition", "This video is not awaiting moderation review.");
        }
        reviewedReel = reel.data();
        tx.update(reelRefValue, {
          status: decision === "approved" ? "published" : "rejected",
          moderationStatus: decision,
          moderationReviewedBy: request.auth.uid,
          moderationReviewedAt: FieldValue.serverTimestamp(),
        });
        tx.set(queueRef, {
          status: "resolved", decision, reviewedBy: request.auth.uid,
          resolvedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });
      if (decision === "rejected" && reviewedReel) {
        await revokeReelDownloadTokens(reviewedReel);
      }
    }
    return { ok: true, decision };
  }

  async function getModerationQueue(request) {
    if (!request.auth || request.auth.token?.admin !== true) {
      fail("permission-denied", "Administrator access is required.");
    }
    const limit = Math.round(clamp(request.data?.limit || 50, 1, 100));
    const snap = await db.collection("kirariModerationQueue")
      .where("status", "==", "pending")
      .orderBy("queuedAt", "asc").limit(limit).get();
    const items = await Promise.all(snap.docs.map(async (doc) => {
      const queue = { id: doc.id, ...doc.data() };
      if (queue.contentType === "comment") {
        const comment = await reelRef(queue.reelId).collection("comments").doc(queue.commentId).get();
        return { ...queue, content: comment.exists ? comment.data()?.text || "" : "[Comment unavailable]" };
      }
      const reel = await reelRef(queue.reelId).get();
      if (!reel.exists) return { ...queue, content: "[Video unavailable]" };
      const data = reel.data();
      const firstRendition = data.renditions?.["540"] || data.renditions?.["360"] || data.renditions?.["720"];
      const videoPath = firstRendition?.path;
      const previewPath = data.coverPath;
      const [videoPreviewUrl, coverPreviewUrl] = await Promise.all([
        videoPath ? bucket.file(videoPath).getSignedUrl({
          action: "read", expires: Date.now() + 5 * 60 * 1000,
        }).then(([url]) => url).catch(() => null) : null,
        previewPath ? bucket.file(previewPath).getSignedUrl({
          action: "read", expires: Date.now() + 5 * 60 * 1000,
        }).then(([url]) => url).catch(() => null) : null,
      ]);
      return {
        ...queue,
        content: data.caption || "",
        creatorId: data.creatorId,
        videoPreviewUrl,
        coverPreviewUrl,
        durationSeconds: data.durationSeconds,
      };
    }));
    return { items };
  }

  async function getCreatorReels(request) {
    const uid = auth(request);
    const creatorId = inputId(request.data?.creatorId || uid, "creatorId");
    if (creatorId !== uid) {
      const profile = await db.collection("public_profiles").doc(creatorId).get();
      if (!profile.exists || profile.data()?.sectionPrivacy?.works === false) {
        fail("permission-denied", "This creator's works are private.");
      }
      if (await isBlockedPair(uid, creatorId)) fail("not-found", "Creator not found.");
    }
    const limit = Math.round(clamp(request.data?.limit || 20, 1, 40));
    const snap = await reels().where("creatorId", "==", creatorId)
      .where("status", "==", "published")
      .where("moderationStatus", "==", "approved")
      .orderBy("publishedAt", "desc").limit(limit).get();
    return { items: snap.docs.map((doc) => ({ id: doc.id, ...doc.data() })) };
  }

  async function getAudioLibrary(request) {
    auth(request);
    const limit = Math.round(clamp(request.data?.limit || 30, 1, 50));
    const snap = await db.collection("kirariAudio")
      .where("status", "==", "approved")
      .where("allowReuse", "==", true)
      .orderBy("publishedAt", "desc")
      .limit(limit).get();
    return {
      items: snap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    };
  }

  async function publishAudioTrack(request) {
    if (!request.auth || request.auth.token?.admin !== true) {
      fail("permission-denied", "Administrator access is required.");
    }
    const audioId = inputId(request.data?.audioId, "audioId");
    const title = inputString(request.data?.title, 120, "title");
    const artist = inputString(request.data?.artist || "Unknown artist", 120, "artist");
    const license = inputString(request.data?.license, 160, "license");
    const attribution = inputString(request.data?.attribution, 500, "attribution");
    const creatorId = request.data?.creatorId
      ? inputId(request.data.creatorId, "creatorId") : null;
    const audioPath = inputString(request.data?.audioPath, 300, "audioPath");
    if (!title || !license || !attribution) {
      fail("invalid-argument", "Title, license and attribution are required.");
    }
    if (request.data?.approved !== true || request.data?.allowReuse !== true) {
      fail("failed-precondition", "Audio must be explicitly approved for reuse.");
    }
    const allowedAudioPaths = ["mp3", "m4a", "aac", "ogg"]
      .map((extension) => `kirari-audio/${audioId}/audio.${extension}`);
    if (!allowedAudioPaths.includes(audioPath)) {
      fail("invalid-argument", "Audio path must use the approved Kirari audio location.");
    }
    let metadata;
    try {
      [metadata] = await bucket.file(audioPath).getMetadata();
    } catch (_) {
      fail("not-found", "Audio file was not found in Storage.");
    }
    const size = Number(metadata.size || 0);
    const contentType = String(metadata.contentType || "");
    if (size <= 0 || size > 25 * 1024 * 1024 || !contentType.startsWith("audio/")) {
      fail("invalid-argument", "Audio must be a valid audio file no larger than 25 MB.");
    }
    await db.collection("kirariAudio").doc(audioId).set({
      title, artist, license, attribution, creatorId, audioPath,
      allowReuse: true, status: "approved",
      approvedBy: request.auth.uid,
      approvedAt: FieldValue.serverTimestamp(),
      publishedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true, audioId };
  }

  async function getReel(request) {
    const uid = auth(request);
    const reelId = inputId(request.data?.reelId, "reelId");
    const snap = await reelRef(reelId).get();
    if (!snap.exists) fail("not-found", "Kirari video not found.");
    const reel = snap.data();
    if (reel.status !== "published" || reel.moderationStatus !== "approved" ||
        await isBlockedPair(uid, reel.creatorId)) {
      fail("not-found", "Kirari video not found.");
    }
    return { id: snap.id, ...reel };
  }

  async function getReelsByAudio(request) {
    const uid = auth(request);
    const audioId = inputId(request.data?.audioId, "audioId");
    const limit = Math.round(clamp(request.data?.limit || 24, 1, 50));
    const snap = await reels().where("status", "==", "published")
      .where("moderationStatus", "==", "approved")
      .where("audioId", "==", audioId)
      .orderBy("publishedAt", "desc").limit(limit).get();
    const excluded = await excludedCreatorIds(uid);
    return { items: snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => !excluded.has(item.creatorId)) };
  }

  async function getComments(request) {
    const uid = auth(request);
    const reelId = inputString(request.data?.reelId, 128, "reelId");
    const limit = Math.round(clamp(request.data?.limit || 30, 1, 50));
    const ref = reelRef(reelId);
    const reel = await ref.get();
    if (!reel.exists || reel.data()?.status !== "published" || reel.data()?.moderationStatus !== "approved" || await isBlockedPair(uid, reel.data()?.creatorId)) {
      fail("not-found", "Kirari video not found.");
    }
    let query = ref.collection("comments")
      .where("status", "==", "published")
      .orderBy("createdAt", "desc").limit(limit + 1);
    if (request.data?.before) {
      const before = await ref.collection("comments").doc(
        inputId(request.data.before, "before"),
      ).get();
      if (before.exists) query = query.startAfter(before);
    }
    const snap = await query.get();
    const docs = snap.docs.slice(0, limit);
    return {
      items: docs.map((doc) => ({ id: doc.id, ...doc.data() })),
      hasMore: snap.docs.length > limit,
      nextCursor: docs.length ? docs[docs.length - 1].id : null,
    };
  }

  async function setCreatorMute(request) {
    const uid = auth(request);
    const creatorId = inputId(request.data?.creatorId, "creatorId");
    if (!creatorId || creatorId === uid) fail("invalid-argument", "Creator id is invalid.");
    const muted = request.data?.muted !== false;
    const ref = db.collection("users").doc(uid).collection("kirariMutedCreators").doc(creatorId);
    if (muted) await ref.set({ creatorId, mutedAt: FieldValue.serverTimestamp() });
    else await ref.delete();
    return { ok: true, muted };
  }

  async function getHashtagFeed(request) {
    const uid = auth(request);
    const hashtag = inputString(request.data?.hashtag, 40, "hashtag").replace(/^#/, "").toLowerCase();
    if (!hashtag) fail("invalid-argument", "Hashtag is required.");
    const limit = Math.round(clamp(request.data?.limit || KIRARI.feedPageSize, 1, 12));
    const snap = await reels().where("status", "==", "published")
      .where("moderationStatus", "==", "approved")
      .where("hashtags", "array-contains", hashtag)
      .orderBy("rankingScore", "desc").orderBy("publishedAt", "desc")
      .limit(limit + 1).get();
    const excluded = await excludedCreatorIds(uid);
    const items = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => !excluded.has(item.creatorId));
    return { items: items.slice(0, limit), hasMore: items.length > limit };
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
    const userRef = db.collection("users").doc(uid);
    const [blockedByA, blockedByB, blockedByLegacy, interests, follows, muted, notInterested] = await Promise.all([
      db.collection("friendships").where("userA", "==", uid).get(),
      db.collection("friendships").where("userB", "==", uid).get(),
      db.collection("friendships").where("userIds", "array-contains", uid).get(),
      userRef.collection("kirariInterests").get(),
      db.collection("respects").where("fromUserId", "==", uid).get(),
      userRef.collection("kirariMutedCreators").get(),
      userRef.collection("kirariNotInterested").get(),
    ]);
    const blockedDocs = [...(blockedByA.docs || []), ...(blockedByB.docs || []), ...(blockedByLegacy.docs || [])];
    const blockedIds = new Set(blockedDocs
      .filter((doc) => doc.data()?.status === "blocked")
      .flatMap((doc) => {
        const data = doc.data() || {};
        return (data.userIds || [data.userA, data.userB]).filter((id) => id && id !== uid);
      }));
    const mutedIds = new Set((muted.docs || []).map((doc) => doc.id));
    const notInterestedIds = new Set((notInterested.docs || []).map((doc) => doc.id));
    const creatorIds = new Set((follows.docs || [])
      .filter((doc) => Number(doc.data()?.value || 0) >= 5)
      .map((doc) => doc.data()?.toUserId).filter(Boolean));
    const interestIds = [...new Set([
      ...(interests.docs || []).map((doc) => doc.id),
      ...(Array.isArray(profile.favoriteAnimeIds) ? profile.favoriteAnimeIds : []),
    ])];
    const query = reels().where("status", "==", "published")
      .where("moderationStatus", "==", "approved")
      .orderBy(type === "trending" ? "velocityScore" : "rankingScore", "desc")
      .orderBy("publishedAt", "desc").limit(100);
    const snap = await query.get();
    let items = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => !blockedIds.has(item.creatorId) &&
        !mutedIds.has(item.creatorId) && !notInterestedIds.has(item.id) &&
        item.creatorId !== uid)
      .map((item) => ({
        ...item,
        _rank: type === "trending"
          ? clamp(item.velocityScore, 0, 1000000000)
          : clamp(item.rankingScore, 0, 100),
      }));
    if (type === "following") items = items.filter((item) => creatorIds.has(item.creatorId));
    const now = Date.now();
    if (type === "forYou") {
      const profileData = { interests: interestIds, creatorIds: [...creatorIds] };
      items = items.map((item) => ({ ...item, _rank: rankKirari(item, profileData, now) }))
        .sort((a, b) => b._rank - a._rank);
      const seenSnap = await db.collection("users").doc(uid).collection("kirariSeen")
        .orderBy("seenAt", "asc").limit(550).get();
      const seen = new Set(seenSnap.docs.map((doc) => doc.id));
      if (seenSnap.docs.length > 500) {
        const prune = db.batch();
        for (const doc of seenSnap.docs.slice(0, seenSnap.docs.length - 500)) prune.delete(doc.ref);
        await prune.commit();
      }
      const fresh = items.filter((item) => !seen.has(item.id)).map((item) => ({
        ...item,
        _relevant: interestIds.length > 0 && [
          ...(item.hashtags || []), ...(item.animeIds || []),
          ...(item.characterIds || []), item.animeId, item.audioId,
        ].some((tag) => tag && interestIds.includes(tag)),
      }));
      items = fresh.sort((a, b) => b._rank - a._rank || a.id.localeCompare(b.id));
      items = diversifyKirari(items, limit, KIRARI.explorationRatio);
    }
    // Stable keyset cursor: descending score, then ascending document id.
    // Do not search for afterId inside a freshly fetched top-N window; it may
    // have moved or fallen outside that window since the prior request.
    items.sort((a, b) => b._rank - a._rank || a.id.localeCompare(b.id));
    if (Number.isFinite(afterScore) && afterId) {
      items = items.filter((item) => isFeedCursorAfter(item._rank, item.id, afterScore, afterId));
    }
    const page = items.slice(0, limit).map(({ _rank, _relevant, ...item }) => ({
      ...item, rankingScore: _rank ?? item.rankingScore ?? 0,
    }));
    return {
      items: page,
      hasMore: items.length > limit,
      nextCursor: page.length ? { afterId: page[page.length - 1].id, afterScore: page[page.length - 1].rankingScore } : null,
    };
  }

  return {
    startUpload, finalizeUpload, retryProcessing, cancelUpload, deleteReel, action, addComment, commentAction,
    startPlayback, recordPlayback, getFeed, getHashtagFeed, getAudioLibrary, publishAudioTrack, getComments, getReelsByAudio, getCreatorReels, getReel, reviewContent, getModerationQueue, setCreatorMute, setProcessingState,
  };
}

module.exports = {
  KIRARI, TRANSITIONS, transitionStatus, normalizeTags, normalizeEditSettings, rankKirari,
  isFeedCursorAfter, diversifyKirari, createKirariDomain,
};
