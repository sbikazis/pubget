"use strict";

const { scanText } = require("./contentFilter");
const {
  readScoreDistribution,
  hasScoreDistribution,
  applyScoreDelta,
  scoreBucket,
  SCORE_BUCKETS,
} = require("./animeStats");

const CRITERIA = Object.freeze([
  "story",
  "art",
  "characters",
  "action",
  "sound",
  "enjoyment",
]);
const REPORT_REASONS = Object.freeze([
  "inappropriate",
  "spam",
  "copyright",
  "harassment",
  "other",
]);
const ACTION_COOLDOWN_MS = 3000;
const COMMENT_MAX = 500;
const TITLE_MAX = 200;
const NAME_MAX = 120;
const IMAGE_MAX = 2048;
const ID_MAX = 64;
const STATS_BATCH_MAX = 30;
const STATS_CHUNK = 10;

function createAnimeHubDomain({ db, FieldValue, HttpsError }) {
  function uid(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  function validString(value, max, min = 1) {
    return typeof value === "string" &&
      value.trim().length >= min &&
      value.trim().length <= max;
  }

  function optionalString(value, max) {
    if (value == null || value === "") return "";
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (trimmed.length > max) return null;
    return trimmed;
  }

  function round1(value) {
    return Math.round(Number(value) * 10) / 10;
  }

  function parseCriteria(raw) {
    if (!raw || typeof raw !== "object") return null;
    const criteria = {};
    let sum = 0;
    for (const key of CRITERIA) {
      const score = Number(raw[key]);
      if (!Number.isInteger(score) || score < 0 || score > 10) return null;
      criteria[key] = score;
      sum += score;
    }
    return { criteria, overall: round1(sum / CRITERIA.length) };
  }

  function millisOf(value) {
    if (!value) return 0;
    if (typeof value.toMillis === "function") return value.toMillis();
    if (value instanceof Date) return value.getTime();
    if (typeof value === "number") return value;
    if (value && value._ts) return Date.now();
    return 0;
  }

  function ratingRef(userId, animeId) {
    return db.collection("users").doc(userId).collection("anime_ratings").doc(animeId);
  }

  function statsRef(animeId) {
    return db.collection("anime_stats").doc(animeId);
  }

  function reviewRef(animeId, userId) {
    return statsRef(animeId).collection("reviews").doc(userId);
  }

  function rateRef(userId) {
    return db.collection("users").doc(userId).collection("animeHubRate").doc("write");
  }

  async function usernameOf(userId) {
    const snap = await db.collection("users").doc(userId).get();
    const data = snap.exists ? snap.data() || {} : {};
    return validString(data.username, NAME_MAX)
      ? data.username.trim()
      : validString(data.displayName, NAME_MAX)
        ? data.displayName.trim()
        : "Pubget user";
  }

  function assertCooldown(rateSnap) {
    const last = millisOf(rateSnap.exists ? rateSnap.data()?.lastAt : 0);
    if (last > 0 && Date.now() - last < ACTION_COOLDOWN_MS) {
      throw new HttpsError(
        "resource-exhausted",
        "Please wait a moment before rating again.",
      );
    }
  }

  async function upsertAnimeRating(request) {
    const userId = uid(request);
    const animeId = validString(request.data && request.data.animeId, ID_MAX)
      ? request.data.animeId.trim()
      : null;
    const parsed = parseCriteria(request.data && request.data.criteria);
    const title = optionalString(request.data && request.data.title, TITLE_MAX);
    const imageUrl = optionalString(request.data && request.data.imageUrl, IMAGE_MAX);
    const comment = optionalString(request.data && request.data.comment, COMMENT_MAX);
    if (!animeId || !parsed) {
      throw new HttpsError(
        "invalid-argument",
        "animeId and scores from 0 to 10 for every criterion are required.",
      );
    }
    if (title === null || imageUrl === null || comment === null) {
      throw new HttpsError("invalid-argument", "Rating details are not valid.");
    }
    if (comment) {
      const scan = scanText(comment);
      if (scan.flagged) {
        throw new HttpsError("invalid-argument", "That review contains prohibited language.");
      }
    }
    const username = await usernameOf(userId);
    const userRating = ratingRef(userId, animeId);
    const stats = statsRef(animeId);
    const review = reviewRef(animeId, userId);
    const cooldown = rateRef(userId);
    let overall = parsed.overall;
    await db.runTransaction(async (tx) => {
      const [existing, statsSnap, rateSnap] = await Promise.all([
        tx.get(userRating),
        tx.get(stats),
        tx.get(cooldown),
      ]);
      assertCooldown(rateSnap);
      const previous = existing.exists ? Number(existing.data()?.overall) || 0 : 0;
      const statsData = statsSnap.data() || {};
      let count = Number(statsData.ratingCount) || 0;
      let sum = Number(statsData.scoreSum) || 0;
      // The distribution is server-authoritative, so it is moved by the same
      // transaction that moves the mean: leave the previous bucket, enter the
      // new one. Re-rating with an unchanged score nets to zero, which is what
      // makes a replay of this callable harmless.
      let distribution = readScoreDistribution(statsData);
      // A document written before the migration has counts but no distribution.
      // Publishing one here would record only the rating this request just
      // made while the older rows stay invisible, and the client would draw
      // that fraction as if it were the whole community. So the field is left
      // absent and the chart keeps saying "not counted yet" until the backfill
      // publishes the real totals. A document this transaction creates is the
      // one case where the aggregates are known to be complete.
      const maintainDistribution =
        hasScoreDistribution(statsData) || !statsSnap.exists;
      if (existing.exists) {
        sum -= previous;
        distribution = applyScoreDelta(distribution, scoreBucket(previous), -1);
      } else {
        count += 1;
      }
      sum += parsed.overall;
      distribution = applyScoreDelta(distribution, scoreBucket(parsed.overall), 1);
      if (count < 0) count = 0;
      if (sum < 0) sum = 0;
      const averageScore = count === 0 ? 0 : round1(sum / count);
      const payload = {
        animeId,
        userId,
        username,
        title: title || (statsData.title || ""),
        imageUrl: imageUrl || (statsData.imageUrl || ""),
        criteria: parsed.criteria,
        overall: parsed.overall,
        comment,
        moderationStatus: "ok",
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!existing.exists) payload.createdAt = FieldValue.serverTimestamp();
      tx.set(userRating, payload, { merge: true });
      tx.set(review, payload, { merge: true });
      const statsPayload = {
        animeId,
        title: payload.title,
        imageUrl: payload.imageUrl,
        scoreSum: sum,
        ratingCount: count,
        averageScore,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (maintainDistribution) statsPayload.scoreDistribution = distribution;
      tx.set(stats, statsPayload, { merge: true });
      tx.set(cooldown, { lastAt: FieldValue.serverTimestamp() }, { merge: true });
      overall = parsed.overall;
    });
    return {
      animeId,
      overall,
      criteria: parsed.criteria,
      comment,
    };
  }

  async function deleteAnimeRating(request) {
    const userId = uid(request);
    const animeId = validString(request.data && request.data.animeId, ID_MAX)
      ? request.data.animeId.trim()
      : null;
    if (!animeId) throw new HttpsError("invalid-argument", "animeId is required.");
    const userRating = ratingRef(userId, animeId);
    const stats = statsRef(animeId);
    const review = reviewRef(animeId, userId);
    const cooldown = rateRef(userId);
    await db.runTransaction(async (tx) => {
      const [existing, statsSnap, rateSnap] = await Promise.all([
        tx.get(userRating),
        tx.get(stats),
        tx.get(cooldown),
      ]);
      assertCooldown(rateSnap);
      if (!existing.exists) return;
      if (existing.data()?.userId && existing.data().userId !== userId) {
        throw new HttpsError("permission-denied", "This rating belongs to another account.");
      }
      const previous = Number(existing.data()?.overall) || 0;
      const statsData = statsSnap.data() || {};
      let count = Math.max(0, (Number(statsData.ratingCount) || 0) - 1);
      let sum = Math.max(0, (Number(statsData.scoreSum) || 0) - previous);
      const averageScore = count === 0 ? 0 : round1(sum / count);
      // Leaving the bucket the deleted rating occupied keeps the distribution
      // in step with the count. The `!existing.exists` guard above makes a
      // repeated delete a no-op, so the counter cannot be walked below zero.
      const distribution = applyScoreDelta(
        readScoreDistribution(statsData),
        scoreBucket(previous),
        -1,
      );
      tx.delete(userRating);
      tx.delete(review);
      if (statsSnap.exists) {
        const statsPayload = {
          scoreSum: sum,
          ratingCount: count,
          averageScore,
          updatedAt: FieldValue.serverTimestamp(),
        };
        // Same rule as the create path: only move a distribution this document
        // already publishes, so a pre-migration document is not given a
        // one-rating chart by a deletion.
        if (hasScoreDistribution(statsData)) {
          statsPayload.scoreDistribution = distribution;
        }
        tx.update(stats, statsPayload);
      }
      tx.set(cooldown, { lastAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    return { ok: true };
  }

  async function reportAnimeReview(request) {
    const reporterId = uid(request);
    const animeId = validString(request.data && request.data.animeId, ID_MAX)
      ? request.data.animeId.trim()
      : null;
    const targetUserId = validString(request.data && request.data.targetUserId, 128)
      ? request.data.targetUserId.trim()
      : null;
    const reason = REPORT_REASONS.includes(request.data && request.data.reason)
      ? request.data.reason
      : null;
    const details = optionalString(request.data && request.data.details, COMMENT_MAX);
    if (!animeId || !targetUserId || !reason) {
      throw new HttpsError("invalid-argument", "A structured report reason is required.");
    }
    if (details === null) {
      throw new HttpsError("invalid-argument", "Report details are too long.");
    }
    if (targetUserId === reporterId) {
      throw new HttpsError("failed-precondition", "You cannot report your own review.");
    }
    const review = reviewRef(animeId, targetUserId);
    const report = review.collection("reports").doc(reporterId);
    await db.runTransaction(async (tx) => {
      const [reviewSnap, existing] = await Promise.all([
        tx.get(review),
        tx.get(report),
      ]);
      if (!reviewSnap.exists) throw new HttpsError("not-found", "Review not found.");
      if (existing.exists) return;
      tx.create(report, {
        reporterId,
        reason,
        details,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(review, {
        reportsCount: (Number(reviewSnap.data()?.reportsCount) || 0) + 1,
        moderationStatus: "flagged",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  function animeReportRef(animeId) {
    return db.collection("anime_reports").doc(animeId).collection("reports");
  }

  async function reportAnime(request) {
    const reporterId = uid(request);
    const animeId = validString(request.data && request.data.animeId, ID_MAX)
      ? request.data.animeId.trim()
      : null;
    const category = validString(request.data && request.data.category, 32)
      ? request.data.category.trim()
      : null;
    if (!animeId || !REPORT_REASONS.includes(category)) {
      throw new HttpsError(
        "invalid-argument",
        "A structured report reason is required.",
      );
    }
    const detail = optionalString(request.data && request.data.detail, COMMENT_MAX);
    if (detail === null) {
      throw new HttpsError("invalid-argument", "Report details are too long.");
    }
    const reportRef = animeReportRef(animeId).doc(reporterId);
    const prior = await reportRef.get();
    if (prior.exists) {
      const previous = prior.data() || {};
      await reportRef.set({
        category,
        detail: detail || previous.detail || null,
        reporterId: previous.reporterId || reporterId,
        animeId: previous.animeId || animeId,
        status: previous.status || "open",
        createdAt: previous.createdAt || FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        repeatCount: (Number(previous.repeatCount) || 1) + 1,
      });
      return { ok: true, alreadyReported: true };
    }
    const gate = await enforceAnimeReportRateLimit(reporterId);
    if (!gate.allowed) {
      throw new HttpsError("resource-exhausted", gate.message);
    }
    await reportRef.set({
      category,
      detail: detail || null,
      reporterId,
      animeId,
      status: "open",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      repeatCount: 1,
    });
    return { ok: true, alreadyReported: false };
  }

  // Thin abuse gate on the anime report queue, mirroring the events report
  // gate: the cost of a false positive is a rejected report, the cost of no
  // limit is a triage queue nobody can clear.
  async function enforceAnimeReportRateLimit(actor, now = Date.now()) {
    const doc = db.collection("animeReportRate").doc(actor);
    const windowMs = 60 * 60 * 1000;
    const maxPerWindow = 10;
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(doc);
      const startedAt = Number(snapshot.data()?.startedAt) || 0;
      const count = Number(snapshot.data()?.count) || 0;
      const elapsed = now - startedAt;
      if (elapsed > windowMs || elapsed < 0) {
        transaction.set(doc, { startedAt: now, count: 1 });
        return { allowed: true };
      }
      if (count >= maxPerWindow) {
        return {
          allowed: false,
          message: "You have sent a few reports already. Try again later.",
        };
      }
      transaction.set(doc, { startedAt, count: count + 1 });
      return { allowed: true };
    });
  }

  function discussionRef(characterId) {
    return db
      .collection("character_discussions")
      .doc(characterId)
      .collection("posts");
  }

  // Batch aggregate read for discovery grids. Firestore caps an `in` query at
  // 10 ids, so the request is chunked; the shape mirrors the single-title
  // getAnimeStats read so the same client codec understands both. Only
  // aggregated public facts are returned, never per-user rows.
  async function getAnimeCommunityStats(request) {
    uid(request);
    const raw = request.data && Array.isArray(request.data.animeIds)
      ? request.data.animeIds
      : null;
    if (!raw || raw.length === 0) {
      throw new HttpsError("invalid-argument", "animeIds is required.");
    }
    if (raw.length > STATS_BATCH_MAX) {
      throw new HttpsError(
        "invalid-argument",
        `Request up to ${STATS_BATCH_MAX} anime ids at a time.`,
      );
    }
    const ids = [];
    const seen = new Set();
    for (const item of raw) {
      const candidate = typeof item === "string" ? item.trim() : "";
      if (validString(candidate, ID_MAX) && !seen.has(candidate)) {
        seen.add(candidate);
        ids.push(candidate);
      }
    }
    if (ids.length === 0) {
      throw new HttpsError("invalid-argument", "No valid anime ids provided.");
    }
    const stats = {};
    for (let index = 0; index < ids.length; index += STATS_CHUNK) {
      const chunk = ids.slice(index, index + STATS_CHUNK);
      const snapshot = await db
        .collection("anime_stats")
        .where("__name__", "in", chunk)
        .get();
      snapshot.forEach((doc) => {
        const data = doc.data() || {};
        const animeId = validString(data.animeId, ID_MAX)
          ? String(data.animeId).trim()
          : doc.id;
        const payload = {
          title: validString(data.title, TITLE_MAX)
            ? String(data.title).trim()
            : "",
          imageUrl: validString(data.imageUrl, IMAGE_MAX)
            ? String(data.imageUrl).trim()
            : null,
          averageScore: Number(data.averageScore) || 0,
          ratingCount: Number(data.ratingCount) || 0,
          listedCount: Number(data.listedCount) || 0,
        };
        if (data.scoreDistribution && typeof data.scoreDistribution === "object") {
          payload.scoreDistribution = data.scoreDistribution;
        }
        if (data.statusCounts && typeof data.statusCounts === "object") {
          payload.statusCounts = data.statusCounts;
        }
        stats[animeId] = payload;
      });
    }
    return { stats };
  }

  async function postCharacterDiscussion(request) {
    const userId = uid(request);
    const characterId = validString(request.data && request.data.characterId, ID_MAX)
      ? request.data.characterId.trim()
      : null;
    const text = optionalString(request.data && request.data.text, COMMENT_MAX);
    if (!characterId || !text) {
      throw new HttpsError(
        "invalid-argument",
        "characterId and text are required.",
      );
    }
    const scan = scanText(text);
    if (scan.flagged) {
      throw new HttpsError("invalid-argument", "That text contains prohibited language.");
    }
    const username = await usernameOf(userId);
    const ref = discussionRef(characterId).doc();
    await ref.set({
      characterId,
      userId,
      username,
      text,
      moderationStatus: "ok",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { id: ref.id, characterId, userId, username, text };
  }

  async function deleteCharacterDiscussion(request) {
    const userId = uid(request);
    const characterId = validString(request.data && request.data.characterId, ID_MAX)
      ? request.data.characterId.trim()
      : null;
    const postId = validString(request.data && request.data.postId, ID_MAX)
      ? request.data.postId.trim()
      : null;
    if (!characterId || !postId) {
      throw new HttpsError(
        "invalid-argument",
        "characterId and postId are required.",
      );
    }
    const ref = discussionRef(characterId).doc(postId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Discussion post not found.");
    }
    if ((snap.data() || {}).userId !== userId) {
      throw new HttpsError(
        "permission-denied",
        "This post belongs to another account.",
      );
    }
    await ref.delete();
    return { ok: true };
  }

  return {
    upsertAnimeRating,
    deleteAnimeRating,
    reportAnimeReview,
    reportAnime,
    getAnimeCommunityStats,
    postCharacterDiscussion,
    deleteCharacterDiscussion,
    CRITERIA,
    ACTION_COOLDOWN_MS,
    REPORT_REASONS,
    SCORE_BUCKETS,
  };
}

module.exports = {
  createAnimeHubDomain,
  ANIME_RATING_CRITERIA: CRITERIA,
  ANIME_SCORE_BUCKETS: SCORE_BUCKETS,
};
