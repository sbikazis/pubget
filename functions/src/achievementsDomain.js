"use strict";

/**
 * Pubget Achievements Domain — server-authoritative unlocks only.
 * Client never writes user_achievements / user_achievement_progress.
 */

const MS_DAY = 24 * 60 * 60 * 1000;

const CATALOG = Object.freeze([
  {
    id: "the_threshold",
    rarity: "common",
    nameEn: "The Threshold",
    nameAr: "العتبة",
    descriptionEn: "Take your first real step into Pubget.",
    descriptionAr: "اتخذ خطوتك الأولى الحقيقية داخل Pubget.",
    meaningEn: "You crossed into the community.",
    meaningAr: "لقد عبرت عتبة المجتمع.",
    assetPath: "assets/achievements/the_threshold/badge.png",
    animationType: "none",
    rewardCoins: 5,
    conditions: [
      {
        id: "first_action",
        labelEn: "First join / first message / first Edit",
        labelAr: "أول انضمام أو رسالة أو Edit",
        target: 1,
      },
    ],
  },
  {
    id: "keeper_of_time",
    rarity: "rare",
    nameEn: "Keeper of Time",
    nameAr: "حارس الزمن",
    descriptionEn: "Stay present across seasons.",
    descriptionAr: "ابقَ حاضرًا عبر الفصول.",
    meaningEn: "Time itself remembers you.",
    meaningAr: "الزمن نفسه يتذكرك.",
    assetPath: "assets/achievements/keeper_of_time/badge.png",
    animationType: "shimmer",
    rewardCoins: 15,
    conditions: [
      {
        id: "account_age_180",
        labelEn: "Account age ≥ 180 days",
        labelAr: "عمر الحساب ≥ 180 يومًا",
        target: 180,
      },
      {
        id: "active_days_60",
        labelEn: "Activity on ≥ 60 distinct days",
        labelAr: "نشاط في ≥ 60 يومًا متفرقًا",
        target: 60,
      },
    ],
  },
  {
    id: "shogun_of_the_realm",
    rarity: "rare",
    nameEn: "Shogun of the Realm",
    nameAr: "شوغن المجتمع",
    descriptionEn: "Found a living community.",
    descriptionAr: "أسّس مجتمعًا حيًا.",
    meaningEn: "You built a realm that stands.",
    meaningAr: "لقد بنيت مجتمعًا حقيقيًا.",
    assetPath: "assets/achievements/shogun_of_the_realm/badge.png",
    animationType: "orbit_lights",
    rewardCoins: 25,
    conditions: [
      {
        id: "members_50",
        labelEn: "Founded group with ≥ 50 unique members",
        labelAr: "مجموعة مؤسَّسة بـ ≥ 50 عضوًا فريدًا",
        target: 50,
      },
      {
        id: "member_age_3d",
        labelEn: "Each counted member age ≥ 3 days",
        labelAr: "عمر كل عضو محسوب ≥ 3 أيام",
        target: 1,
      },
      {
        id: "member_message_1",
        labelEn: "Each counted member sent ≥ 1 message",
        labelAr: "كل عضو محسوب أرسل رسالة واحدة على الأقل",
        target: 1,
      },
      {
        id: "stable_7d",
        labelEn: "Member count stable for 7 days",
        labelAr: "استقرار العدد 7 أيام",
        target: 7,
      },
    ],
  },
  {
    id: "thread_of_souls",
    rarity: "uncommon",
    nameEn: "Thread of Souls",
    nameAr: "خيط الأرواح",
    descriptionEn: "Weave real mutual bonds.",
    descriptionAr: "انسج روابط متبادلة حقيقية.",
    meaningEn: "Souls connected through you.",
    meaningAr: "أرواح اتصلت من خلالك.",
    assetPath: "assets/achievements/thread_of_souls/badge.png",
    animationType: "path_glow",
    rewardCoins: 20,
    conditions: [
      {
        id: "mutual_25",
        labelEn: "25 mutual friendships or mutual respect ≥5",
        labelAr: "25 علاقة متبادلة (صداقة أو احترام ≥5 لكل طرف)",
        target: 25,
      },
    ],
  },
  {
    id: "worldsmith",
    rarity: "rare",
    nameEn: "Worldsmith",
    nameAr: "صانع العوالم",
    descriptionEn: "Publish worlds others enter.",
    descriptionAr: "انشر عوالم يدخلها الآخرون.",
    meaningEn: "Creation that echoes.",
    meaningAr: "إبداع يتردد صداه.",
    assetPath: "assets/achievements/worldsmith/badge.png",
    animationType: "brush_trail",
    rewardCoins: 20,
    conditions: [
      {
        id: "works_10",
        labelEn: "10 published Edits + Fan Works",
        labelAr: "10 أعمال منشورة (Edits + Fan Works)",
        target: 10,
      },
      {
        id: "impact_1000",
        labelEn: "Qualified views + respect received ≥ 1000",
        labelAr: "مشاهدات مؤهلة + احترام مستلم ≥ 1000",
        target: 1000,
      },
    ],
  },
  {
    id: "arena_sovereign",
    rarity: "rare",
    nameEn: "Arena Sovereign",
    nameAr: "سيد الحلبة",
    descriptionEn: "Dominate real opponents.",
    descriptionAr: "تسيّد على خصوم حقيقيين.",
    meaningEn: "The arena bows to you.",
    meaningAr: "الحلبة تنحني لك.",
    assetPath: "assets/achievements/arena_sovereign/badge.png",
    animationType: "star_pulse",
    rewardCoins: 20,
    conditions: [
      {
        id: "wins_30",
        labelEn: "≥ 30 wins vs real players",
        labelAr: "≥ 30 انتصارًا ضد لاعبين حقيقيين",
        target: 30,
      },
      {
        id: "winrate_55",
        labelEn: "Win rate ≥ 55% vs real players",
        labelAr: "نسبة فوز ≥ 55% ضد لاعبين حقيقيين",
        target: 55,
      },
    ],
  },
  {
    id: "master_of_festivities",
    rarity: "rare",
    nameEn: "Master of Festivities",
    nameAr: "سيد الاحتفالات",
    descriptionEn: "Host gatherings that finish.",
    descriptionAr: "استضف تجمعات تكتمل فعليًا.",
    meaningEn: "Celebration under your banner.",
    meaningAr: "احتفال تحت رايتك.",
    assetPath: "assets/achievements/master_of_festivities/badge.png",
    animationType: "banner_sway",
    rewardCoins: 20,
    conditions: [
      {
        id: "events_5",
        labelEn: "5 organized ENDED events with ≥10 participants",
        labelAr: "5 أحداث منظمة اكتملت بـ ≥10 مشاركين",
        target: 5,
      },
    ],
  },
  {
    id: "crownbearer",
    rarity: "epic",
    nameEn: "Crownbearer",
    nameAr: "حامل التاج",
    descriptionEn: "Hold a great realm through seasons.",
    descriptionAr: "احمل مملكة عظيمة عبر الفصول.",
    meaningEn: "The crown found its keeper.",
    meaningAr: "التاج وجد حامله.",
    assetPath: "assets/achievements/crownbearer/badge.png",
    animationType: "crown_glow",
    rewardCoins: 40,
    conditions: [
      {
        id: "members_100_90d",
        labelEn: "Group ≥100 members sustained 90 days",
        labelAr: "مجموعة ≥100 عضو مستمرة 90 يومًا",
        target: 90,
      },
      {
        id: "no_drop_below_90",
        labelEn: "Never below 90 for >5 distinct days",
        labelAr: "بلا هبوط تحت 90 لأكثر من 5 أيام متفرقة",
        target: 5,
      },
      {
        id: "no_serious_strike",
        labelEn: "No serious moderation strike",
        labelAr: "بلا مخالفة إشرافية خطيرة",
        target: 1,
      },
    ],
  },
  {
    id: "legend_of_the_gate",
    rarity: "legendary",
    nameEn: "Legend of the Gate",
    nameAr: "أسطورة البوابة",
    descriptionEn: "Hold five realm achievements at once.",
    descriptionAr: "امتلك خمسة إنجازات من العتبة إلى التاج معًا.",
    meaningEn: "The gate remembers your legend.",
    meaningAr: "البوابة تتذكر أسطورتك.",
    assetPath: "assets/achievements/legend_of_the_gate/badge.png",
    animationType: "light_sweep",
    rewardCoins: 60,
    conditions: [
      {
        id: "hold_5_of_1_8",
        labelEn: "Own any 5 of achievements 1–8",
        labelAr: "امتلاك 5 من الإنجازات 1–8",
        target: 5,
      },
    ],
  },
  {
    id: "dragon_of_legacy",
    rarity: "mythic",
    nameEn: "Dragon of Legacy",
    nameAr: "تنين الإرث",
    descriptionEn: "Legacy, time, and crown — perfected.",
    descriptionAr: "الإرث والزمن والتاج — مكتملون.",
    meaningEn: "You are the dragon of Pubget's legacy.",
    meaningAr: "أنت تنين إرث Pubget.",
    assetPath: "assets/achievements/dragon_of_legacy/badge.png",
    animationType: "mythic_living",
    rewardCoins: 100,
    conditions: [
      {
        id: "has_legend",
        labelEn: "Own Legend of the Gate",
        labelAr: "امتلاك أسطورة البوابة",
        target: 1,
      },
      {
        id: "has_keeper",
        labelEn: "Own Keeper of Time",
        labelAr: "امتلاك حارس الزمن",
        target: 1,
      },
      {
        id: "has_crown",
        labelEn: "Own Crownbearer",
        labelAr: "امتلاك حامل التاج",
        target: 1,
      },
      {
        id: "account_age_730",
        labelEn: "Account age ≥ 730 days",
        labelAr: "عمر الحساب ≥ 730 يومًا",
        target: 730,
      },
    ],
  },
]);

const BASE_IDS = Object.freeze([
  "the_threshold",
  "keeper_of_time",
  "shogun_of_the_realm",
  "thread_of_souls",
  "worldsmith",
  "arena_sovereign",
  "master_of_festivities",
  "crownbearer",
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

function daysBetween(a, b) {
  return Math.floor((b.getTime() - a.getTime()) / MS_DAY);
}

function unlockedRef(db, uid, achievementId) {
  return db.collection("user_achievements").doc(uid)
    .collection("unlocked").doc(achievementId);
}

function legacyItemRef(db, uid, achievementId) {
  return db.collection("user_achievements").doc(uid)
    .collection("items").doc(achievementId);
}

function progressRef(db, uid, achievementId) {
  return db.collection("user_achievement_progress").doc(uid)
    .collection("progress").doc(achievementId);
}

function statsRef(db, uid) {
  return db.collection("user_achievement_stats").doc(uid);
}

function createAchievementsDomain({
  db, FieldValue, HttpsError, economy, notificationBuilder, clock,
}) {
  const nowOf = () => (clock && typeof clock.now === "function" ? clock.now() : new Date());

  async function readStats(uid) {
    const snap = await statsRef(db, uid).get();
    return snap.exists ? (snap.data() || {}) : {};
  }

  async function patchStats(uid, patch) {
    await statsRef(db, uid).set({
      ...patch,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  async function listUnlockedIds(uid) {
    const snap = await db.collection("user_achievements").doc(uid)
      .collection("unlocked").get();
    const ids = new Set((snap.docs || []).map((d) => d.id));
    // legacy fallback
    if (ids.size === 0) {
      const legacy = await db.collection("user_achievements").doc(uid)
        .collection("items").get();
      (legacy.docs || []).forEach((d) => ids.add(d.id));
    }
    return ids;
  }

  async function writeProgress(uid, achievementId, conditionsMap, { currentValue, targetValue }) {
    await progressRef(db, uid, achievementId).set({
      achievementId,
      currentValue: Number(currentValue) || 0,
      targetValue: Number(targetValue) || 0,
      conditions: conditionsMap || {},
      lastUpdatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  async function unlock(userId, achievementId, { source = "", metadata = {}, progressSnapshot = null } = {}) {
    const spec = byId(achievementId);
    if (!spec || typeof userId !== "string" || !userId) {
      return { unlocked: false, reason: "invalid" };
    }
    const ref = unlockedRef(db, userId, achievementId);
    const legacy = legacyItemRef(db, userId, achievementId);
    let created = false;
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) return;
      const legacyExisting = await transaction.get(legacy);
      if (legacyExisting.exists) {
        // migrate pointer without re-rewarding
        transaction.set(ref, {
          achievementId,
          rarity: spec.rarity,
          nameEn: spec.nameEn,
          nameAr: spec.nameAr,
          unlockedAt: legacyExisting.data().unlockedAt || FieldValue.serverTimestamp(),
          progressSnapshot: progressSnapshot || legacyExisting.data().progressSnapshot || null,
          version: 2,
          source: "migrated",
        }, { merge: true });
        return;
      }
      created = true;
      const payload = {
        achievementId,
        rarity: spec.rarity,
        nameEn: spec.nameEn,
        nameAr: spec.nameAr,
        descriptionEn: spec.descriptionEn,
        descriptionAr: spec.descriptionAr,
        meaningEn: spec.meaningEn,
        meaningAr: spec.meaningAr,
        assetPath: spec.assetPath,
        animationType: spec.animationType,
        rewardCoins: spec.rewardCoins,
        unlockedAt: FieldValue.serverTimestamp(),
        progressSnapshot: progressSnapshot || null,
        version: 2,
        source: typeof source === "string" ? source.slice(0, 40) : "",
        metadata,
      };
      transaction.create(ref, payload);
      transaction.set(legacy, payload, { merge: true });
    });
    if (!created) return { unlocked: false, reason: "already_unlocked", achievementId };

    if (economy && typeof economy.applyReward === "function" && spec.rewardCoins > 0) {
      await economy.applyReward({
        userId,
        type: "earn_achievement",
        referenceId: achievementId,
        source: "achievement",
        metadata: { achievementId },
      }).catch(() => {});
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
        metadata: { achievementId, celebration: true },
        title: "Achievement unlocked",
        body: spec.nameEn,
        pushWorthy: true,
      }).catch(() => {});
    }
    // Re-evaluate composites after every new unlock.
    await evaluateComposites(userId);
    return { unlocked: true, achievementId };
  }

  async function evaluateComposites(uid) {
    const unlocked = await listUnlockedIds(uid);
    const baseCount = BASE_IDS.filter((id) => unlocked.has(id)).length;
    await writeProgress(uid, "legend_of_the_gate", {
      hold_5_of_1_8: { current: baseCount, target: 5, met: baseCount >= 5 },
    }, { currentValue: baseCount, targetValue: 5 });
    if (baseCount >= 5) {
      await unlock(uid, "legend_of_the_gate", {
        source: "composite",
        progressSnapshot: { hold_5_of_1_8: baseCount },
      });
    }

    const stats = await readStats(uid);
    const createdAt = toDate(stats.accountCreatedAt);
    const ageDays = createdAt ? daysBetween(createdAt, nowOf()) : Number(stats.accountAgeDays) || 0;
    const hasLegend = unlocked.has("legend_of_the_gate") || baseCount >= 5;
    const hasKeeper = unlocked.has("keeper_of_time");
    const hasCrown = unlocked.has("crownbearer");
    const dragonConditions = {
      has_legend: { current: hasLegend ? 1 : 0, target: 1, met: hasLegend },
      has_keeper: { current: hasKeeper ? 1 : 0, target: 1, met: hasKeeper },
      has_crown: { current: hasCrown ? 1 : 0, target: 1, met: hasCrown },
      account_age_730: { current: ageDays, target: 730, met: ageDays >= 730 },
    };
    const dragonMet = Object.values(dragonConditions).every((c) => c.met);
    await writeProgress(uid, "dragon_of_legacy", dragonConditions, {
      currentValue: Object.values(dragonConditions).filter((c) => c.met).length,
      targetValue: 4,
    });
    if (dragonMet) {
      await unlock(uid, "dragon_of_legacy", {
        source: "composite",
        progressSnapshot: dragonConditions,
      });
    }
  }

  async function ensureAccountCreated(uid, metadata = {}) {
    const stats = await readStats(uid);
    if (stats.accountCreatedAt) return stats;
    let createdAt = toDate(metadata.accountCreatedAt);
    if (!createdAt) {
      try {
        const profile = await db.collection("public_profiles").doc(uid).get();
        createdAt = toDate(profile.data() && profile.data().createdAt);
      } catch (_) { /* ignore */ }
    }
    if (!createdAt) createdAt = nowOf();
    await patchStats(uid, { accountCreatedAt: createdAt });
    return { ...stats, accountCreatedAt: createdAt };
  }

  async function markActiveDay(uid) {
    const dayKey = nowOf().toISOString().slice(0, 10);
    const stats = await readStats(uid);
    const days = Array.isArray(stats.activeDayKeys) ? stats.activeDayKeys.slice() : [];
    if (!days.includes(dayKey)) {
      days.push(dayKey);
      // keep last ~800 keys to bound doc size
      const trimmed = days.length > 800 ? days.slice(days.length - 800) : days;
      await patchStats(uid, {
        activeDayKeys: trimmed,
        activeDays: trimmed.length,
      });
      return trimmed.length;
    }
    return days.length;
  }

  async function evaluateThreshold(uid, source) {
    const stats = await readStats(uid);
    const firstAction = Number(stats.firstActionCount) || 0;
    const next = Math.max(firstAction, 1);
    await patchStats(uid, { firstActionCount: next, firstActionSource: source });
    await writeProgress(uid, "the_threshold", {
      first_action: { current: next, target: 1, met: next >= 1 },
    }, { currentValue: next, targetValue: 1 });
    if (next >= 1) {
      return unlock(uid, "the_threshold", {
        source,
        progressSnapshot: { first_action: next },
      });
    }
    return null;
  }

  async function evaluateKeeper(uid) {
    await ensureAccountCreated(uid);
    const activeDays = await markActiveDay(uid);
    const stats = await readStats(uid);
    const createdAt = toDate(stats.accountCreatedAt) || nowOf();
    const ageDays = daysBetween(createdAt, nowOf());
    const conditions = {
      account_age_180: { current: ageDays, target: 180, met: ageDays >= 180 },
      active_days_60: { current: activeDays, target: 60, met: activeDays >= 60 },
    };
    await writeProgress(uid, "keeper_of_time", conditions, {
      currentValue: Math.min(ageDays, 180) + Math.min(activeDays, 60),
      targetValue: 240,
    });
    if (conditions.account_age_180.met && conditions.active_days_60.met) {
      return unlock(uid, "keeper_of_time", {
        source: "keeper_check",
        progressSnapshot: conditions,
      });
    }
    return null;
  }

  async function evaluateShogun(uid, metadata = {}) {
    const members = Number(metadata.qualifiedMemberCount ?? metadata.memberCount) || 0;
    const memberAgeOk = metadata.memberAgeOk !== false && (metadata.memberAgeOk === true || members > 0);
    const memberMsgOk = metadata.memberMessageOk !== false && (metadata.memberMessageOk === true || members > 0);
    const stableDays = Number(metadata.stableDays) || Number((await readStats(uid)).shogunStableDays) || 0;
    if (metadata.stableDays != null) {
      await patchStats(uid, { shogunStableDays: stableDays, shogunMembers: members });
    } else if (members > 0) {
      await patchStats(uid, { shogunMembers: members });
    }
    const stats = await readStats(uid);
    const m = Number(stats.shogunMembers) || members;
    const s = Number(stats.shogunStableDays) || stableDays;
    const conditions = {
      members_50: { current: m, target: 50, met: m >= 50 },
      member_age_3d: { current: memberAgeOk ? 1 : 0, target: 1, met: Boolean(memberAgeOk) && m >= 50 },
      member_message_1: { current: memberMsgOk ? 1 : 0, target: 1, met: Boolean(memberMsgOk) && m >= 50 },
      stable_7d: { current: s, target: 7, met: s >= 7 },
    };
    await writeProgress(uid, "shogun_of_the_realm", conditions, {
      currentValue: m,
      targetValue: 50,
    });
    if (Object.values(conditions).every((c) => c.met)) {
      return unlock(uid, "shogun_of_the_realm", {
        source: "shogun_check",
        progressSnapshot: conditions,
      });
    }
    return null;
  }

  async function evaluateThread(uid, metadata = {}) {
    let mutual = Number(metadata.mutualCount);
    if (!Number.isFinite(mutual)) {
      const stats = await readStats(uid);
      mutual = Number(stats.mutualRelationships) || 0;
    }
    await patchStats(uid, { mutualRelationships: mutual });
    await writeProgress(uid, "thread_of_souls", {
      mutual_25: { current: mutual, target: 25, met: mutual >= 25 },
    }, { currentValue: mutual, targetValue: 25 });
    if (mutual >= 25) {
      return unlock(uid, "thread_of_souls", {
        source: "thread_check",
        progressSnapshot: { mutual_25: mutual },
      });
    }
    return null;
  }

  async function evaluateWorldsmith(uid, metadata = {}) {
    const stats = await readStats(uid);
    const works = Number(metadata.publishedWorks ?? stats.publishedWorks) || 0;
    const impact = Number(metadata.impactScore ?? stats.impactScore) || 0;
    await patchStats(uid, { publishedWorks: works, impactScore: impact });
    const conditions = {
      works_10: { current: works, target: 10, met: works >= 10 },
      impact_1000: { current: impact, target: 1000, met: impact >= 1000 },
    };
    await writeProgress(uid, "worldsmith", conditions, {
      currentValue: works,
      targetValue: 10,
    });
    if (conditions.works_10.met && conditions.impact_1000.met) {
      return unlock(uid, "worldsmith", {
        source: "worldsmith_check",
        progressSnapshot: conditions,
      });
    }
    return null;
  }

  async function evaluateArena(uid, metadata = {}) {
    const stats = await readStats(uid);
    const wins = Number(metadata.realWins ?? stats.realWins) || 0;
    const games = Number(metadata.realGames ?? stats.realGames) || 0;
    const winRate = games > 0 ? Math.round((wins / games) * 1000) / 10 : 0;
    await patchStats(uid, { realWins: wins, realGames: games, realWinRate: winRate });
    const conditions = {
      wins_30: { current: wins, target: 30, met: wins >= 30 },
      winrate_55: { current: winRate, target: 55, met: winRate >= 55 && games > 0 },
    };
    await writeProgress(uid, "arena_sovereign", conditions, {
      currentValue: wins,
      targetValue: 30,
    });
    if (conditions.wins_30.met && conditions.winrate_55.met) {
      return unlock(uid, "arena_sovereign", {
        source: "arena_check",
        progressSnapshot: conditions,
      });
    }
    return null;
  }

  async function evaluateFestivities(uid, metadata = {}) {
    const stats = await readStats(uid);
    const ended = Number(metadata.endedEventsQualified ?? stats.endedEventsQualified) || 0;
    await patchStats(uid, { endedEventsQualified: ended });
    await writeProgress(uid, "master_of_festivities", {
      events_5: { current: ended, target: 5, met: ended >= 5 },
    }, { currentValue: ended, targetValue: 5 });
    if (ended >= 5) {
      return unlock(uid, "master_of_festivities", {
        source: "festivities_check",
        progressSnapshot: { events_5: ended },
      });
    }
    return null;
  }

  async function evaluateCrown(uid, metadata = {}) {
    const stats = await readStats(uid);
    const sustainedDays = Number(metadata.sustainedDays100 ?? stats.sustainedDays100) || 0;
    const dropDays = Number(metadata.dropBelow90Days ?? stats.dropBelow90Days) || 0;
    const seriousStrike = Boolean(metadata.seriousStrike ?? stats.seriousStrike);
    await patchStats(uid, {
      sustainedDays100: sustainedDays,
      dropBelow90Days: dropDays,
      seriousStrike,
    });
    const conditions = {
      members_100_90d: { current: sustainedDays, target: 90, met: sustainedDays >= 90 },
      no_drop_below_90: { current: dropDays, target: 5, met: dropDays <= 5 },
      no_serious_strike: { current: seriousStrike ? 0 : 1, target: 1, met: !seriousStrike },
    };
    await writeProgress(uid, "crownbearer", conditions, {
      currentValue: sustainedDays,
      targetValue: 90,
    });
    if (Object.values(conditions).every((c) => c.met)) {
      return unlock(uid, "crownbearer", {
        source: "crown_check",
        progressSnapshot: conditions,
      });
    }
    return null;
  }

  async function evaluate(event) {
    if (!event || typeof event !== "object") return [];
    const results = [];
    const push = async (p) => {
      if (!p) return;
      const r = await p;
      if (r) results.push(r);
    };
    const uid = event.userId;
    const meta = event.metadata || {};

    switch (event.type) {
      case "group_joined":
      case "message_sent":
      case "edit_published":
      case "group_created":
        if (uid) {
          await ensureAccountCreated(uid, meta);
          await push(evaluateThreshold(uid, event.type));
          await push(evaluateKeeper(uid));
        }
        if (event.type === "edit_published" && uid) {
          const stats = await readStats(uid);
          const works = Number(meta.publishedWorks ?? ((Number(stats.publishedWorks) || 0) + 1));
          const impact = Number(meta.impactScore ?? stats.impactScore) || 0;
          await push(evaluateWorldsmith(uid, { publishedWorks: works, impactScore: impact }));
        }
        if (event.type === "group_created" && uid) {
          await push(evaluateShogun(uid, meta));
          await push(evaluateCrown(uid, meta));
        }
        break;
      case "friend_accepted":
      case "respect_updated": {
        const ids = event.userIds || (uid ? [uid] : []);
        for (const id of ids) {
          await push(evaluateThread(id, meta));
          await push(evaluateKeeper(id));
        }
        break;
      }
      case "fan_gained":
        if (uid) {
          await push(evaluateThread(uid, meta));
          await push(evaluateWorldsmith(uid, meta));
        }
        break;
      case "fan_work_published":
        if (uid) {
          const stats = await readStats(uid);
          const works = Number(meta.publishedWorks ?? ((Number(stats.publishedWorks) || 0) + 1));
          await push(evaluateWorldsmith(uid, {
            publishedWorks: works,
            impactScore: Number(meta.impactScore ?? stats.impactScore) || 0,
          }));
          await push(evaluateThreshold(uid, event.type));
        }
        break;
      case "game_won":
      case "game_completed": {
        const ids = event.userIds || (uid ? [uid] : []);
        for (const id of ids) {
          await push(evaluateArena(id, meta));
          await push(evaluateKeeper(id));
        }
        break;
      }
      case "event_participated":
        if (uid) await push(evaluateKeeper(uid));
        break;
      case "event_won":
      case "event_ended": {
        const organizerId = meta.organizerId || uid;
        if (organizerId) await push(evaluateFestivities(organizerId, meta));
        break;
      }
      case "group_membership_changed":
        if (uid) {
          await push(evaluateShogun(uid, meta));
          await push(evaluateCrown(uid, meta));
        }
        break;
      case "daily_activity":
      case "achievement_reconcile":
        if (uid) {
          await ensureAccountCreated(uid, meta);
          await push(evaluateKeeper(uid));
          await push(evaluateShogun(uid, meta));
          await push(evaluateThread(uid, meta));
          await push(evaluateWorldsmith(uid, meta));
          await push(evaluateArena(uid, meta));
          await push(evaluateFestivities(uid, meta));
          await push(evaluateCrown(uid, meta));
          await evaluateComposites(uid);
        }
        break;
      default:
        break;
    }
    return results;
  }

  async function readProgressMap(uid) {
    const snap = await db.collection("user_achievement_progress").doc(uid)
      .collection("progress").get();
    const map = {};
    (snap.docs || []).forEach((doc) => {
      map[doc.id] = doc.data();
    });
    return map;
  }

  async function readUnlockedMap(uid) {
    const snap = await db.collection("user_achievements").doc(uid)
      .collection("unlocked").get();
    const map = {};
    (snap.docs || []).forEach((doc) => {
      map[doc.id] = doc.data();
    });
    if (Object.keys(map).length === 0) {
      const legacy = await db.collection("user_achievements").doc(uid)
        .collection("items").get();
      (legacy.docs || []).forEach((doc) => {
        map[doc.id] = doc.data();
      });
    }
    return map;
  }

  function publicItem(spec, unlockedDoc, progressDoc) {
    const conditions = (spec.conditions || []).map((c) => {
      const p = progressDoc && progressDoc.conditions && progressDoc.conditions[c.id]
        ? progressDoc.conditions[c.id]
        : null;
      const current = p ? Number(p.current) || 0 : 0;
      const target = c.target != null ? Number(c.target) : (p ? Number(p.target) || 0 : 0);
      const met = p ? Boolean(p.met) : Boolean(unlockedDoc);
      return {
        id: c.id,
        labelEn: c.labelEn,
        labelAr: c.labelAr,
        current,
        target,
        met: unlockedDoc ? true : met,
      };
    });
    return {
      id: spec.id,
      rarity: spec.rarity,
      nameEn: spec.nameEn,
      nameAr: spec.nameAr,
      descriptionEn: spec.descriptionEn,
      descriptionAr: spec.descriptionAr,
      meaningEn: spec.meaningEn,
      meaningAr: spec.meaningAr,
      assetPath: spec.assetPath,
      animationType: spec.animationType,
      rewardCoins: spec.rewardCoins,
      unlocked: Boolean(unlockedDoc),
      unlockedAt: unlockedDoc ? unlockedDoc.unlockedAt : null,
      currentValue: progressDoc ? Number(progressDoc.currentValue) || 0 : 0,
      targetValue: progressDoc
        ? Number(progressDoc.targetValue) || 0
        : (spec.conditions[0] && spec.conditions[0].target) || 0,
      conditions,
    };
  }

  async function getAchievements(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const viewer = request.auth.uid;
    const target = (request.data && request.data.userId) || viewer;
    if (typeof target !== "string" || !target) {
      throw new HttpsError("invalid-argument", "userId is required.");
    }
    const [unlocked, progress] = await Promise.all([
      readUnlockedMap(target),
      readProgressMap(target),
    ]);
    return {
      userId: target,
      viewerId: viewer,
      items: CATALOG.map((spec) => publicItem(spec, unlocked[spec.id] || null, progress[spec.id] || null)),
    };
  }

  return {
    unlock,
    evaluate,
    evaluateComposites,
    getAchievements,
    catalog: () => CATALOG.map((item) => ({ ...item })),
  };
}

module.exports = {
  CATALOG,
  BASE_IDS,
  createAchievementsDomain,
};
