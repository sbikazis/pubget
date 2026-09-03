"use strict";

const CATALOG = Object.freeze([
  {
    id: "first_group",
    type: "community",
    title: "First Circle",
    description: "Create your first group.",
    icon: "group",
    rewardCoins: 5,
  },
  {
    id: "first_edit",
    type: "creator",
    title: "First Cut",
    description: "Publish your first edit.",
    icon: "edit",
    rewardCoins: 5,
  },
  {
    id: "first_friend",
    type: "social",
    title: "First Friend",
    description: "Accept or form your first friendship.",
    icon: "friend",
    rewardCoins: 5,
  },
  {
    id: "first_fan",
    type: "social",
    title: "First Fan",
    description: "Receive your first fan through Respect.",
    icon: "fan",
    rewardCoins: 5,
  },
  {
    id: "first_event_participation",
    type: "event",
    title: "Show Up",
    description: "Participate in your first event.",
    icon: "event",
    rewardCoins: 5,
  },
  {
    id: "first_event_win",
    type: "event",
    title: "Event Victor",
    description: "Win your first event.",
    icon: "trophy",
    rewardCoins: 5,
  },
  {
    id: "first_game_win",
    type: "game",
    title: "First Victory",
    description: "Win your first game.",
    icon: "game",
    rewardCoins: 5,
  },
  {
    id: "creator_milestone",
    type: "creator",
    title: "Creator",
    description: "Publish your first Fan Work.",
    icon: "creator",
    rewardCoins: 5,
  },
  {
    id: "community_milestone",
    type: "community",
    title: "In the Mix",
    description: "Finish your first game as a participant.",
    icon: "community",
    rewardCoins: 5,
  },
  {
    id: "edit_milestone",
    type: "creator",
    title: "Cut Five",
    description: "Publish five edits.",
    icon: "edit",
    rewardCoins: 5,
  },
  {
    id: "creator_fan_milestone",
    type: "creator",
    title: "First Circle of Fans",
    description: "Earn a fan as a creator.",
    icon: "fan",
    rewardCoins: 5,
  },
  {
    id: "autumn_2026_rally",
    type: "seasonal",
    title: "Autumn Rally",
    description: "Win a game during the Autumn 2026 season.",
    icon: "season",
    rewardCoins: 10,
    trigger: "game_won",
    season: {
      id: "autumn_2026",
      startAt: "2026-09-01T00:00:00.000Z",
      endAt: "2026-11-30T23:59:59.999Z",
    },
  },
]);

function byId(id) {
  return CATALOG.find((item) => item.id === id) || null;
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.toMillis === "function") return new Date(value.toMillis());
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function seasonStateOf(spec, now) {
  if (!spec || !spec.season) return "evergreen";
  const start = toDate(spec.season.startAt);
  const end = toDate(spec.season.endAt);
  if (!start || !end) return "evergreen";
  const t = now.getTime();
  if (t < start.getTime()) return "upcoming";
  if (t > end.getTime()) return "ended";
  return "active";
}

function publicSpec(spec, now, unlockedDoc) {
  const seasonState = seasonStateOf(spec, now);
  return {
    id: spec.id,
    type: spec.type,
    title: spec.title,
    description: spec.description,
    icon: spec.icon,
    rewardCoins: spec.rewardCoins,
    trigger: spec.trigger || null,
    seasonId: spec.season ? spec.season.id : null,
    seasonStartAt: spec.season ? spec.season.startAt : null,
    seasonEndAt: spec.season ? spec.season.endAt : null,
    seasonState,
    unlocked: Boolean(unlockedDoc),
    unlockedAt: unlockedDoc ? unlockedDoc.unlockedAt : null,
  };
}

function userItemRef(db, uid, achievementId) {
  return db.collection("user_achievements").doc(uid)
    .collection("items").doc(achievementId);
}

function createAchievementsDomain({
  db, FieldValue, HttpsError, economy, notificationBuilder, clock,
}) {
  const nowOf = () => (clock && typeof clock.now === "function" ? clock.now() : new Date());

  async function unlock(userId, achievementId, { source = "", metadata = {} } = {}) {
    const spec = byId(achievementId);
    if (!spec || typeof userId !== "string" || !userId) {
      return { unlocked: false, reason: "invalid" };
    }
    const seasonState = seasonStateOf(spec, nowOf());
    if (seasonState === "upcoming") {
      return { unlocked: false, reason: "season_not_started", achievementId };
    }
    if (seasonState === "ended") {
      return { unlocked: false, reason: "season_ended", achievementId };
    }
    const ref = userItemRef(db, userId, achievementId);
    let created = false;
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) return;
      created = true;
      transaction.create(ref, {
        achievementId,
        type: spec.type,
        title: spec.title,
        description: spec.description,
        icon: spec.icon,
        rewardCoins: spec.rewardCoins,
        unlockedAt: FieldValue.serverTimestamp(),
        version: 1,
        source: typeof source === "string" ? source.slice(0, 40) : "",
        metadata,
        seasonId: spec.season ? spec.season.id : null,
      });
    });
    if (!created) return { unlocked: false, reason: "already_unlocked", achievementId };
    if (economy && typeof economy.applyReward === "function" && spec.rewardCoins > 0) {
      await economy.applyReward({
        userId,
        type: "earn_achievement",
        referenceId: achievementId,
        source: "achievement",
        metadata: { achievementId },
      });
    }
    if (notificationBuilder && typeof notificationBuilder.build === "function") {
      await notificationBuilder.build({
        id: `achievement-${userId}-${achievementId}`,
        recipientIds: [userId],
        type: "achievement_unlocked",
        actorId: userId,
        targetId: achievementId,
        action: "unlocked",
        destination: `/achievements?id=${achievementId}`,
        metadata: { achievementId },
        title: "Achievement unlocked",
        body: spec.title,
        pushWorthy: false,
      }).catch(() => {});
    }
    return { unlocked: true, achievementId };
  }

  async function evaluate(event) {
    if (!event || typeof event !== "object") return [];
    const results = [];
    const grant = async (uid, id) => {
      if (!uid) return;
      results.push(await unlock(uid, id, {
        source: event.source || event.type || "",
        metadata: event.metadata || {},
      }));
    };
    switch (event.type) {
      case "group_created":
        await grant(event.userId, "first_group");
        break;
      case "edit_published":
        await grant(event.userId, "first_edit");
        if ((Number(event.metadata && event.metadata.publishedCount) || 0) >= 5) {
          await grant(event.userId, "edit_milestone");
        }
        break;
      case "friend_accepted":
        for (const uid of event.userIds || [event.userId]) {
          await grant(uid, "first_friend");
        }
        break;
      case "fan_gained":
        await grant(event.userId, "first_fan");
        await grant(event.userId, "creator_fan_milestone");
        break;
      case "event_participated":
        await grant(event.userId, "first_event_participation");
        break;
      case "event_won":
        for (const uid of event.userIds || []) {
          await grant(uid, "first_event_win");
        }
        break;
      case "game_won":
        for (const uid of event.userIds || []) {
          await grant(uid, "first_game_win");
          await grant(uid, "autumn_2026_rally");
        }
        break;
      case "game_completed":
        for (const uid of event.userIds || []) {
          await grant(uid, "community_milestone");
        }
        break;
      case "fan_work_published":
        await grant(event.userId, "creator_milestone");
        break;
      default:
        break;
    }
    return results;
  }

  async function getAchievements(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const uid = request.auth.uid;
    const snap = await db.collection("user_achievements").doc(uid)
      .collection("items").get();
    const unlocked = {};
    (snap.docs || []).forEach((doc) => {
      unlocked[doc.id] = doc.data();
    });
    const now = nowOf();
    return {
      items: CATALOG.map((item) => publicSpec(item, now, unlocked[item.id] || null)),
    };
  }

  return {
    unlock,
    evaluate,
    getAchievements,
    catalog: () => CATALOG.map((item) => ({ ...item })),
  };
}

module.exports = {
  CATALOG,
  createAchievementsDomain,
  seasonStateOf,
};
