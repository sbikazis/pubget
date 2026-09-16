"use strict";

const { scanText } = require("./contentFilter");

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
      let count = Number(statsSnap.data()?.ratingCount) || 0;
      let sum = Number(statsSnap.data()?.scoreSum) || 0;
      if (existing.exists) {
        sum -= previous;
      } else {
        count += 1;
      }
      sum += parsed.overall;
      if (count < 0) count = 0;
      if (sum < 0) sum = 0;
      const averageScore = count === 0 ? 0 : round1(sum / count);
      const payload = {
        animeId,
        userId,
        username,
        title: title || (statsSnap.data()?.title || ""),
        imageUrl: imageUrl || (statsSnap.data()?.imageUrl || ""),
        criteria: parsed.criteria,
        overall: parsed.overall,
        comment,
        moderationStatus: "ok",
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!existing.exists) payload.createdAt = FieldValue.serverTimestamp();
      tx.set(userRating, payload, { merge: true });
      tx.set(review, payload, { merge: true });
      tx.set(stats, {
        animeId,
        title: payload.title,
        imageUrl: payload.imageUrl,
        scoreSum: sum,
        ratingCount: count,
        averageScore,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
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
      let count = Math.max(0, (Number(statsSnap.data()?.ratingCount) || 0) - 1);
      let sum = Math.max(0, (Number(statsSnap.data()?.scoreSum) || 0) - previous);
      const averageScore = count === 0 ? 0 : round1(sum / count);
      tx.delete(userRating);
      tx.delete(review);
      if (statsSnap.exists) {
        tx.update(stats, {
          scoreSum: sum,
          ratingCount: count,
          averageScore,
          updatedAt: FieldValue.serverTimestamp(),
        });
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

  return {
    upsertAnimeRating,
    deleteAnimeRating,
    reportAnimeReview,
    CRITERIA,
    ACTION_COOLDOWN_MS,
    REPORT_REASONS,
  };
}

module.exports = {
  createAnimeHubDomain,
  ANIME_RATING_CRITERIA: CRITERIA,
};
