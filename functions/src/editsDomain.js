"use strict";

const { moderateEditCopy } = require("./contentFilter");
const {
  scoreEdit,
  scoreReelTrending,
  applyFeedDiversity,
  mixExploration,
} = require("./ranking");
const { EDITS_CONFIG, TAG_LIMITS } = require("./editsConfig");
const {
  utcDayKey,
  quotaDocId,
  quotaVerdict,
  quotaExceededMessage,
} = require("./editUploadQuota");
const {
  buildHiddenCreatorSet,
  applyVisibility,
} = require("./reelVisibility");

function string(value, max) {
  return typeof value === "string" && value.trim().length <= max
    ? value.trim()
    : null;
}

function boundedList(value, maxItems, maxItemLength) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > maxItems) return null;
  const normalized = value.map((item) => string(item, maxItemLength));
  return normalized.every(Boolean) ? normalized : null;
}

/** §15.16 — client sends one of three strategies; unknown values are For You. */
function normalizeFeedType(raw) {
  const value = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (value === "following" || value === "trending" || value === "foryou") {
    return value;
  }
  return "forYou";
}

/** §15.16 — a scope is one of audio / anime / character / hashtag / creator. */
function normalizeFeedScope(data) {
  return {
    audioId: string(data?.audioId || "", 128),
    animeId: string(data?.animeId || "", 128),
    characterId: string(data?.characterId || "", 128),
    hashtag: (string(data?.hashtag || "", TAG_LIMITS.hashtagMaxLength) || "")
      .replace(/^#+/, "")
      .toLowerCase() || null,
    creatorId: string(data?.creatorId || "", 128),
  };
}

  function matchesScope(edit, scope) {
    if (scope.audioId && String(edit.audioId || "") !== scope.audioId) return false;
    if (scope.animeId && String(edit.animeId || "") !== scope.animeId) return false;
    if (scope.creatorId && String(edit.creatorId || "") !== scope.creatorId) return false;
    if (scope.characterId) {
      const ids = Array.isArray(edit.characterIds) ? edit.characterIds : [];
      if (!ids.includes(scope.characterId)) return false;
    }
    if (scope.hashtag) {
      const tags = Array.isArray(edit.hashtags) ? edit.hashtags : [];
      if (!tags.includes(scope.hashtag)) return false;
    }
    return true;
  }

// Firestore caps `in` at 30 values.
const MAX_IN_VALUES = 30;

/**
 * Builds the candidate pool for a feed.
 *
 * The scope and the followed-creator set are applied *in the query*, not by
 * filtering a global top-200 afterwards. Fetching the global top-200 and then
 * filtering starved scoped and following feeds: a hashtag carried by 400 Reels
 * returns empty whenever those Reels rank below position 200, and the viewer
 * is shown "no results" for content that exists. §15.16 wants an empty
 * Following feed only when the viewer genuinely follows nobody.
 */
async function loadFeedCandidates({ db, collectionName, feedType, scope, creatorIds }) {
  let query = db.collection(collectionName).where("status", "==", "published");

  if (scope.audioId) query = query.where("audioId", "==", scope.audioId);
  if (scope.animeId) query = query.where("animeId", "==", scope.animeId);
  if (scope.creatorId) query = query.where("creatorId", "==", scope.creatorId);
  if (scope.hashtag) query = query.where("hashtags", "array-contains", scope.hashtag);
  if (scope.characterId) query = query.where("characterIds", "array-contains", scope.characterId);

  if (feedType === "following" && creatorIds.size > 0 && !scope.creatorId) {
    // Query in chunks so a viewer who follows more than 30 creators still
    // gets their full feed instead of a silent truncation.
    const chunks = [];
    const ids = [...creatorIds];
    for (let i = 0; i < ids.length; i += MAX_IN_VALUES) {
      chunks.push(ids.slice(i, i + MAX_IN_VALUES));
    }
    const snapshots = await Promise.all(
      chunks.map((chunk) =>
        applyFeedOrder(query.where("creatorId", "in", chunk), feedType).limit(200).get(),
      ),
    );
    return { docs: snapshots.flatMap((snap) => snap.docs || []) };
  }

  return applyFeedOrder(query, feedType).limit(200).get();
}

/**
 * Applies the ordering the ranking layer expects.
 *
 * For You and Following consume the stored `score`, so they read the
 * highest-scored slice. Trending is re-scored by velocity in memory, so
 * reading only the top-scored slice would pin trending to whatever For You
 * happens to favour; it reads the newest published slice instead.
 */
function applyFeedOrder(query, feedType) {
  const ordered =
    feedType === "trending"
      ? query.orderBy("createdAt", "desc")
      : query.orderBy("score", "desc").orderBy("createdAt", "desc");
  return ordered;
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

function createEditsDomain({
  db,
  FieldValue,
  HttpsError,
  achievements,
  processEdit,
  bucket,
  collectionName = "edits",
  uploadKeyCollection = "editUploadKeys",
  quotaCollectionName = "editUploadQuota",
  muteCollectionName = "reelMutes",
  savedCollectionName = "savedReels",
  audioCollectionName = "reelAudios",
  storagePrefix = "edits",
  config = EDITS_CONFIG,
}) {
  function uid(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentication is required.");
    return request.auth.uid;
  }

  function editRef(editId) {
    return db.collection(collectionName).doc(editId);
  }

  function bump(changes, flatKey, nestedKey, amount) {
    changes[flatKey] = FieldValue.increment(amount);
    changes[`counters.${nestedKey}`] = FieldValue.increment(amount);
  }

  /**
   * §15.2 quota reservation.
   *
   * Read-and-increment inside a transaction so two simultaneous uploads cannot
   * both read `used === limit - 1` and both be admitted. The client pre-flight
   * is advisory; this is the enforcement point.
   *
   * The verdict is returned rather than stashed on the domain instance: one
   * domain object serves every request, so shared state would let concurrent
   * uploads report each other's remaining count.
   */
  function quotaRef(creatorId, now = new Date()) {
    return db
      .collection(quotaCollectionName)
      .doc(quotaDocId(creatorId, utcDayKey(now)));
  }

  async function reserveQuota(creatorId, now = new Date()) {
    const ref = quotaRef(creatorId, now);
    const verdict = await db.runTransaction(async (txn) => {
      const snap = await txn.get(ref);
      const current = quotaVerdict(snap.data()?.count ?? 0);
      if (!current.allowed) return current;
      txn.set(ref, {
        creatorId,
        day: utcDayKey(now),
        count: current.used + 1,
        limit: current.limit,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { ...current, used: current.used + 1, remaining: current.remaining - 1 };
    });
    if (!verdict.allowed) {
      throw new HttpsError("resource-exhausted", quotaExceededMessage(verdict.limit));
    }
    return verdict;
  }

  async function releaseQuota(creatorId, now = new Date()) {
    const ref = quotaRef(creatorId, now);
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(ref);
      const count = snap.data()?.count ?? 0;
      // Never go negative: a double release must not hand out free slots.
      txn.set(ref, {
        count: Math.max(0, count - 1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }).catch((error) => {
      console.error("Upload quota release failed", {
        creatorId,
        error: error && error.message ? error.message : String(error),
      });
    });
  }

  async function startUpload(request) {
    const creatorId = uid(request);
    const caption = string(request.data?.caption || "", config.captionMax);
    const animeTag = string(request.data?.animeTag || "", 128);
    const hashtags = boundedList(
      request.data?.hashtags,
      TAG_LIMITS.hashtagsMax,
      TAG_LIMITS.hashtagMaxLength,
    );
    const characterIds = boundedList(
      request.data?.characterIds,
      TAG_LIMITS.characterIdsMax,
      TAG_LIMITS.characterIdMaxLength,
    );
    const mentions = boundedList(request.data?.mentions, config.mentionMax, 128);
    const groupIds = boundedList(request.data?.groupIds, 8, 128);
    const animeId = string(request.data?.animeId || "", 128);
    const audioId = string(request.data?.audioId || "", 128);
    const eventId = string(request.data?.eventId || "", 128);
    const coverFrameMs = request.data?.coverFrameMs == null
      ? 0
      : Number(request.data.coverFrameMs);
    const visibility = string(request.data?.visibility || "public", 16);
    const allowRemix = request.data?.allowRemix !== false;
    if (caption === null || animeTag === null || animeId === null ||
        audioId === null || eventId === null || visibility === null ||
        !["public", "followers", "private"].includes(visibility) ||
        hashtags === null || characterIds === null || mentions === null ||
        groupIds === null || !Number.isInteger(coverFrameMs) ||
        coverFrameMs < 0 || coverFrameMs > 60000) {
      throw new HttpsError("invalid-argument", "Caption or anime tag is invalid.");
    }
    // An Edit must never point at an audio that does not exist or is not
    // playable. Checking here — before any byte is uploaded — turns a silent
    // dead-video bug into a fast, actionable failure.
    if (audioId) {
      const audioSnap = await db.collection(audioCollectionName).doc(audioId).get();
      if (!audioSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "That sound track no longer exists.",
        );
      }
      if (audioSnap.data()?.status !== "ready") {
        throw new HttpsError(
          "failed-precondition",
          "That sound track is still processing. Try again shortly.",
        );
      }
    }
    const idempotencyKey = string(request.data?.idempotencyKey || "", 128);
    if (idempotencyKey) {
      const keySnap = await db.collection(uploadKeyCollection)
        .doc(`${creatorId}_${idempotencyKey}`).get();
      if (keySnap.exists && keySnap.data()?.editId) {
        const existingId = keySnap.data().editId;
        return {
          editId: existingId,
          videoPath: `${storagePrefix}/${creatorId}/${existingId}.mp4`,
        };
      }
    }
    const editId = db.collection(collectionName).doc().id;
    const videoPath = `${storagePrefix}/${creatorId}/${editId}.mp4`;
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
      animeId,
      hashtags,
      characterIds,
      mentions,
      groupIds,
      eventId,
      audioId,
      coverFrameMs,
      visibility,
      allowRemix,
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
      schemaVersion: config.schemaVersion,
    };
    const writes = [editRef(editId).create(payload)];
    if (idempotencyKey) {
      writes.push(db.collection(uploadKeyCollection).doc(`${creatorId}_${idempotencyKey}`).create({
        creatorId, editId, createdAt: FieldValue.serverTimestamp(),
      }));
    }
    // Quota is reserved only once the request is known to be valid, and released
    // if the create itself fails so a rejected upload cannot silently burn a slot.
    const reservation = await reserveQuota(creatorId);
    try {
      await Promise.all(writes);
    } catch (error) {
      await releaseQuota(creatorId);
      throw error;
    }
    return { editId, videoPath, quotaRemaining: reservation.remaining };
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
    if (!originMs || Date.now() - originMs > config.repostWindowMs) {
      throw new HttpsError("failed-precondition", "Reposts are available for 30 days.");
    }
    if (source.creatorId === creatorId) {
      throw new HttpsError("failed-precondition", "You cannot repost your own Edit.");
    }
    const originalCreatorId = source.originalCreatorId || source.creatorId;
    const ref = db.collection(collectionName).doc();
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
      schemaVersion: config.schemaVersion,
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
    const max = kind === "sticker" ? config.stickerMax : config.commentMax;
    const text = string(request.data?.text, max);
    const replyRaw = request.data?.replyToCommentId;
    const replyToCommentId = replyRaw == null || replyRaw === ""
      ? null
      : string(replyRaw, 128);
    const mentions = Array.isArray(request.data?.mentions)
      ? request.data.mentions
        .filter((item) => typeof item === "string" && item.trim().length <= 32)
        .map((item) => item.trim())
        .slice(0, config.mentionMax)
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
    if (existing.exists && Date.now() - last < config.viewabilityMs) {
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
        verifiedPercent >= config.qualifiedViewPercent &&
        Date.now() - last >= 24 * 60 * 60 * 1000;
      const completed = !isSelf &&
        verifiedPercent >= config.completionPercent &&
        previous.completed !== true;
      const creditedBefore = Number(previous.creditedWatchSeconds) || 0;
      const watchCredit = increment;
      tx.set(viewerRef, {
        viewerId,
        lastPercent: Math.max(previous.lastPercent || 0, verifiedPercent),
        lastQualifiedAt: qualified ? FieldValue.serverTimestamp() : previous.lastQualifiedAt || null,
        completed: previous.completed === true || completed,
        creditedWatchSeconds: creditedBefore + watchCredit,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.update(sessionRef, {
        creditedSeconds: verifiedSeconds,
        lastHeartbeatAt: FieldValue.serverTimestamp(),
        consumed: verifiedPercent >= config.completionPercent,
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

  /**
   * §15 saved Reels.
   *
   * `save` used to be only a per-edit signal row that `unsave` DELETED, so the
   * save state was unrecoverable by design: there was no list, no callable, no
   * rule, no index, and no screen. A user's saved Reels evaporated on restart.
   * The signal row still drives ranking; this is the retrievable record.
   */
  function savedItemRef(viewerId, editId) {
    return db
      .collection(savedCollectionName)
      .doc(viewerId)
      .collection("items")
      .doc(editId);
  }

  /** Only what the saved list needs to render a row without a second fetch. */
  function savedItemSnapshot(editData) {
    return {
      editId: editData.editId || "",
      creatorId: editData.creatorId || "",
      videoUrl: editData.videoUrl || "",
      thumbnailUrl: editData.thumbnailUrl || "",
      caption: editData.caption || "",
      durationSeconds: Number(editData.durationSeconds) || 0,
      likesCount: Number(editData.likesCount) || 0,
    };
  }

  async function listSavedReels(request) {
    const viewerId = uid(request);
    const limit = Math.max(1, Math.min(50, Number(request.data?.limit) || 30));
    const afterId = string(request.data?.afterId || "", 128);
    const savedItems = db
      .collection(savedCollectionName)
      .doc(viewerId)
      .collection("items");

    // Paging happens in the query, not after it. Filtering the fetched page for
    // the cursor only works while the cursor happens to be inside that page, so
    // the second page request replayed the first page forever.
    let query = savedItems.orderBy("savedAt", "desc").limit(limit + 1);
    if (afterId) {
      const cursorSnap = await savedItems.doc(afterId).get();
      if (cursorSnap.exists) query = query.startAfter(cursorSnap);
    }
    const snapshot = await query.get();

    let docs = snapshot.docs || [];
    const hasMore = docs.length > limit;
    if (hasMore) docs = docs.slice(0, limit);
    return {
      items: docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) })),
      hasMore,
    };
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
    const savedRef = type === "save" || type === "unsave"
      ? savedItemRef(actor, editId)
      : null;
    await db.runTransaction(async (tx) => {
      const [edit, existing] = await Promise.all([tx.get(ref), tx.get(signalRef)]);
      if (!edit.exists) return;
      if (type === "unsave") {
        if (!existing.exists) return;
        tx.delete(signalRef);
        if (savedRef) tx.delete(savedRef);
        const changes = { score: FieldValue.increment(-5) };
        bump(changes, "savesCount", "saves", -1);
        tx.update(ref, changes);
        return;
      }
      if (existing.exists) return;
      tx.create(signalRef, { actor, type, createdAt: FieldValue.serverTimestamp() });
      if (type === "save" && savedRef) {
        // The retrievable save record. Kept in the same transaction as the
        // signal so a save can never be half-applied.
        tx.set(savedRef, {
          ...savedItemSnapshot({ ...(edit.data() || {}), editId }),
          savedAt: FieldValue.serverTimestamp(),
        });
      }
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

  /**
   * §15.16 — one feed entry point for every Reels surface.
   *
   * Scope (audio / anime / character / hashtag / creator) narrows the
   * candidate set; `feedType` picks the ranking strategy. Both are decided
   * here, never on the client.
   */
  /**
   * §15 mute a Reels creator.
   *
   * Mute is one-directional and consequence-free: it hides their content from
   * this viewer's feed and nothing else. Block (see socialGraph) is the
   * two-sided action.
   */
  async function muteReelCreator(request) {
    const viewerId = uid(request);
    const creatorId = string(request.data?.creatorId || "", 128);
    const muted = request.data?.muted !== false;
    if (!creatorId) {
      throw new HttpsError("invalid-argument", "creatorId is required.");
    }
    if (creatorId === viewerId) {
      throw new HttpsError("failed-precondition", "You cannot mute yourself.");
    }
    const creator = await db.collection("users").doc(creatorId).get();
    if (!creator.exists) {
      throw new HttpsError("not-found", "That creator no longer exists.");
    }
    const ref = db
      .collection(muteCollectionName)
      .doc(viewerId)
      .collection("creators")
      .doc(creatorId);
    if (muted) {
      await ref.set({
        creatorId,
        viewerId,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { muted: true, creatorId };
    }
    await ref.delete().catch(() => {});
    return { muted: false, creatorId };
  }

  /** Creators whose Reels this viewer must not see: blocked (both ways) + muted. */
  async function loadHiddenCreatorIds(viewerId) {
    // Deliberately no `.catch()` on these two reads.
    //
    // They are the privacy boundary: a block is the one signal a user has to
    // stop seeing someone, and a mute is an explicit request to hide them.
    // Reading them as "no blocks, no mutes" when the read fails fails open, and
    // would republish exactly the content the viewer asked not to see. An
    // unavailable feed is the correct outcome instead.
    const [blockSnap, muteSnap] = await Promise.all([
      db.collection("friendships")
        .where("userIds", "array-contains", viewerId)
        .get(),
      db.collection(muteCollectionName)
        .doc(viewerId)
        .collection("creators")
        .get(),
    ]);
    return buildHiddenCreatorSet({
      blockDocs: blockSnap.docs || [],
      muteDocs: (muteSnap.docs || []).map((doc) => doc.id),
      viewerId,
    });
  }

  /**
   * §15.9 — which Reels this viewer has already been served.
   *
   * Reads the server-owned `viewers` subcollection rather than anything the
   * client sends, so a viewer cannot clear their own history to farm repeats,
   * and cannot invent history to suppress content.
   *
   * Bounded on purpose: this runs on every feed request, and an unbounded read
   * would make the feed cost grow without limit for heavy viewers. Anything past
   * the cap simply stops contributing a repetition penalty.
   */
  async function loadSeenEditIds(viewerId, cap = config.seenHistoryLimit) {
    const snapshot = await db
      .collectionGroup("viewers")
      .where("viewerId", "==", viewerId)
      .limit(cap)
      .get()
      .catch(() => ({ docs: [] }));
    const ids = new Set();
    (snapshot.docs || []).forEach((doc) => {
      // The doc id is the viewer; the *parent* is the Reel that was watched.
      const editId = doc.ref.parent.parent && doc.ref.parent.parent.id;
      if (editId) ids.add(editId);
    });
    return ids;
  }

  async function getEditFeed(request) {
    const viewerId = uid(request);
    const limit = Math.max(1, Math.min(12, Number(request.data?.limit) || config.feedPageSize));
    const afterId = string(request.data?.afterId || "", 128);
    const feedType = normalizeFeedType(request.data?.feedType);
    const scope = normalizeFeedScope(request.data);
    const [userSnap, respectsSnap, listsSnap, hiddenCreatorIds] = await Promise.all([
      db.collection("users").doc(viewerId).get(),
      db.collection("respects").where("fromUserId", "==", viewerId).get().catch(() => ({ docs: [] })),
      db.collection("users").doc(viewerId).collection("animeList").get().catch(() => ({ docs: [] })),
      loadHiddenCreatorIds(viewerId),
    ]);
    const user = userSnap.data() || {};
    const creatorIds = new Set();
    (respectsSnap.docs || []).forEach((doc) => {
      const value = Number(doc.data()?.value) || 0;
      const toUserId = doc.data()?.toUserId;
      if (toUserId && value >= config.fanThreshold) creatorIds.add(toUserId);
    });
    // A blocked/muted creator must not stay in the Following set either, or the
    // `following` branch below would re-admit what the visibility filter removed.
    hiddenCreatorIds.forEach((hiddenId) => creatorIds.delete(hiddenId));
    const animeIds = [
      ...((user.favoriteAnimeIds || []).filter(Boolean)),
      ...((listsSnap.docs || []).map((doc) => doc.id)),
    ];
    // §15.9 already-watched Reels. `scoreEdit` penalises a repeat, but the
    // profile handed an empty set, so that penalty could never fire and the
    // viewer was re-served the same Reels. Read server-owned watch history:
    // `edits/{id}/viewers/{viewerId}` already exists from `recordView`.
    const seenIds = await loadSeenEditIds(viewerId);
    const profile = {
      userId: viewerId,
      animeIds,
      creatorIds,
      seenIds,
      creatorQuality: 0,
    };
    const now = new Date();
    const published = await loadFeedCandidates({
      db,
      collectionName,
      feedType,
      scope,
      creatorIds,
    });
    // Defense in depth: the query already applied scope, but re-checking here
    // keeps the guarantee that a scoped feed never leaks another context's rows
    // even if a query clause is later dropped.
    const candidates = (published.docs || [])
      .map((doc) => ({ id: doc.id, data: doc.data() || {} }))
      .filter((item) => matchesScope(item.data, scope));
    // A creator you blocked or muted must not appear in any feed scope. This is
    // applied after ranking scope so it cannot be bypassed by choosing a scope.
    const visible = applyVisibility(candidates, hiddenCreatorIds, viewerId);
    let ranked;
    if (feedType === "following") {
      // §15.16 — Following is creators the viewer actually follows. When the
      // viewer follows nobody the honest answer is an empty feed, not a
      // silent fallback to For You.
      ranked = visible
        .filter((item) => creatorIds.has(item.data.creatorId))
        .map((item) => ({
          id: item.id,
          data: item.data,
          rank: scoreEdit({ id: item.id, ...item.data }, profile, now),
        }))
        .sort((a, b) => b.rank - a.rank || String(b.id).localeCompare(String(a.id)));
    } else if (feedType === "trending") {
      // §15.16 — Trending is engagement velocity, independent of the viewer.
      ranked = visible
        .map((item) => ({
          id: item.id,
          data: item.data,
          rank: scoreReelTrending({ id: item.id, ...item.data }, now),
        }))
        .sort((a, b) => b.rank - a.rank || String(b.id).localeCompare(String(a.id)));
      // §15.10 lists creator diversity ("تنوع الصنّاع") as part of Trending, so a
      // single loud creator cannot own the "what's happening now" page. The caps
      // depend only on the ranked order, never on the viewer, so two people
      // opening Trending still see the same page.
      ranked = applyFeedDiversity(ranked);
    } else {
      ranked = visible
        .map((item) => ({
          id: item.id,
          data: item.data,
          rank: scoreEdit({ id: item.id, ...item.data }, profile, now),
        }))
        .sort((a, b) => b.rank - a.rank || String(b.id).localeCompare(String(a.id)));
      // §15.9 controlled diversity. The ranked order used to go straight out, so
      // one hot creator could own the entire page.
      ranked = applyFeedDiversity(ranked);
      // §15.9 exploitation 70–90% / exploration 10–30%. Without this the tail was
      // unreachable: every slot went to the top-ranked Reel.
      ranked = mixExploration(ranked, config.explorationShare);
    }
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

  async function resolveSourceObject(videoPath) {
    if (!bucket || !videoPath) {
      return { contentType: "video/mp4", size: config.maxBytes, exists: true };
    }
    const file = bucket.file(videoPath);
    const [exists] = await file.exists();
    if (!exists) {
      return { contentType: "video/mp4", size: 0, exists: false };
    }
    const [meta] = await file.getMetadata();
    return {
      contentType: meta.contentType || "video/mp4",
      size: Number(meta.size || 0),
      exists: true,
    };
  }

  async function kickProcessing(ref, data, videoPath, { awaitProcessing = false } = {}) {
    const source = await resolveSourceObject(videoPath);
    if (!source.exists) {
      throw new HttpsError(
        "failed-precondition",
        "The original video is missing. Re-upload the video, then try again.",
      );
    }
    if (source.size <= 0 || source.size > config.maxBytes) {
      await ref.update({
        status: "failed",
        failureReason: "invalid-video",
        processingStartedAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError(
        "failed-precondition",
        "This video is not a supported MP4, or it is too large.",
      );
    }
    await ref.update({
      status: "processing",
      failureReason: null,
      moderationReason: null,
      processingStartedAt: FieldValue.serverTimestamp(),
    });
    if (typeof processEdit === "function") {
      const job = processEdit({
        data: {
          name: videoPath,
          contentType: "video/mp4",
          size: source.size,
        },
      });
      if (awaitProcessing) {
        await job;
      } else {
        // Return immediately so the client is never blocked in the publish UI.
        // Storage onObjectFinalized is the durable processor; this kick is best-effort.
        Promise.resolve(job).catch((error) => {
          console.error("Edit processing kick failed", {
            videoPath,
            error: error && error.message ? error.message : String(error),
          });
        });
      }
    }
    return { ok: true, videoPath, status: "processing" };
  }

  /**
   * Client calls this after Storage upload succeeds. Idempotent for
   * published / already-processing edits. Recovers when the Storage
   * finalize trigger never fires (region mismatch, delay, etc.).
   */
  async function finalizeUpload(request) {
    const creatorId = uid(request);
    const editId = string(request.data?.editId, 128);
    if (!editId) throw new HttpsError("invalid-argument", "editId is required.");
    const ref = editRef(editId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Edit not found.");
    const data = snap.data() || {};
    if (data.creatorId !== creatorId) {
      throw new HttpsError("permission-denied", "Only the creator can finalize this Edit.");
    }
    if (data.status === "published") {
      return { ok: true, status: "published", videoPath: data.processedStoragePath || null };
    }
    if (data.status === "rejected") {
      return { ok: true, status: "rejected", reason: data.moderationReason || null };
    }
    if (!["uploading", "processing", "failed"].includes(data.status)) {
      throw new HttpsError("failed-precondition", "This Edit cannot be finalized.");
    }
    const videoPath = data.originalStoragePath || data.videoPath;
    if (!videoPath) {
      throw new HttpsError("failed-precondition", "The original video is missing.");
    }
    return kickProcessing(ref, data, videoPath, { awaitProcessing: false });
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
    // Allow stuck "processing" retries — never leave an Edit permanently dead.
    if (!["failed", "rejected", "uploading", "processing", "needs_review"].includes(data.status)) {
      throw new HttpsError("failed-precondition", "This Edit is not waiting for a retry.");
    }
    if (data.status === "published") {
      return { ok: true, videoPath: data.processedStoragePath || null, status: "published" };
    }
    const videoPath = data.originalStoragePath || data.videoPath;
    if (!videoPath) {
      throw new HttpsError("failed-precondition", "The original video is missing.");
    }
    return kickProcessing(ref, data, videoPath, { awaitProcessing: true });
  }

  return {
    startUpload, repost, deleteEdit, like, comment, startPlayback, recordView, signal,
    commentAction, getEditFeed, retryProcessing, finalizeUpload, muteReelCreator,
    listSavedReels,
  };
}

module.exports = { createEditsDomain };
