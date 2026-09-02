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
]);

function byId(id) {
  return CATALOG.find((item) => item.id === id) || null;
}

function userItemRef(db, uid, achievementId) {
  return db.collection("user_achievements").doc(uid)
    .collection("items").doc(achievementId);
}

function createAchievementsDomain({
  db, FieldValue, HttpsError, economy, notificationBuilder,
}) {
  async function unlock(userId, achievementId, { source = "", metadata = {} } = {}) {
    const spec = byId(achievementId);
    if (!spec || typeof userId !== "string" || !userId) {
      return { unlocked: false, reason: "invalid" };
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
        break;
      case "friend_accepted":
        for (const uid of event.userIds || [event.userId]) {
          await grant(uid, "first_friend");
        }
        break;
      case "fan_gained":
        await grant(event.userId, "first_fan");
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
    return {
      items: CATALOG.map((item) => ({
        ...item,
        unlocked: Boolean(unlocked[item.id]),
        unlockedAt: unlocked[item.id] ? unlocked[item.id].unlockedAt : null,
      })),
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
};
