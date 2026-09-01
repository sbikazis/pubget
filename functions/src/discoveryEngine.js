"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");

const WINDOW_DAYS = 7;
const MAX_MESSAGES = 500;
const GROUPS_PER_RUN = 75;
const MIN_ACCOUNT_AGE_DAYS = 7;
const MIN_MEMBERSHIP_AGE_HOURS = 24;

function dateValue(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return new Date(0);
}

function calculateActivityScore({
  messages,
  memberCount,
  hasImage,
  hasDescription,
  hasRules,
  qualifyingActorIds,
  now = new Date(),
}) {
  const cutoff = now.getTime() - WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const recent = messages.filter((message) => {
    const actor = typeof message.senderId === "string" ? message.senderId : "";
    return dateValue(message.createdAt).getTime() >= cutoff &&
      (!qualifyingActorIds || qualifyingActorIds.has(actor));
  });
  const actors = new Map();
  const days = new Set();
  let replies = 0;
  recent.forEach((message) => {
    const actor = typeof message.senderId === "string" ? message.senderId : "";
    if (actor) actors.set(actor, (actors.get(actor) || 0) + 1);
    const date = dateValue(message.createdAt);
    days.add(date.toISOString().slice(0, 10));
    if (message.replyToMessageId) replies += 1;
  });
  const uniqueActors = actors.size;
  const cappedMessages = [...actors.values()]
    .reduce((sum, count) => sum + Math.min(count, 12), 0);
  const diversity = recent.length === 0
    ? 0
    : Math.min(1, uniqueActors / Math.max(3, Math.min(memberCount, 20)));
  const activity = Math.min(1, cappedMessages / 60);
  const replyRate = recent.length === 0 ? 0 : Math.min(1, replies / recent.length);
  const regularity = days.size / WINDOW_DAYS;
  const completeness = (
    Number(Boolean(hasImage)) +
    Number(Boolean(hasDescription)) +
    Number(Boolean(hasRules))
  ) / 3;
  // A single account cannot create a high score through repetition alone.
  const antiManipulation = uniqueActors <= 1
    ? 0.35
    : Math.min(1, uniqueActors / 5);
  const base = activity * 35 +
    replyRate * 15 +
    diversity * 20 +
    regularity * 15 +
    completeness * 10;
  return Math.round(Math.max(0, Math.min(100,
    base * (recent.length === 0 ? 1 : antiManipulation),
  )));
}

function createDiscoveryScheduler({ db, FieldValue }) {
  async function updateScores() {
    const stateRef = db.collection("_system").doc("discoveryScheduler");
    const state = await stateRef.get();
    const cursor = state.data()?.lastGroupId;
    let query = db.collection("groups")
      .where("isSearchable", "==", true)
      .orderBy("__name__")
      .limit(GROUPS_PER_RUN);
    if (cursor) query = query.startAfter(cursor);
    let groups = await query.get();
    if (groups.empty && cursor) {
      groups = await db.collection("groups")
        .where("isSearchable", "==", true)
        .orderBy("__name__")
        .limit(GROUPS_PER_RUN)
        .get();
    }
    let batch = db.batch();
    let writes = 0;
    for (const groupDoc of groups.docs) {
      const group = groupDoc.data() || {};
      const cutoff = new Date(Date.now() - WINDOW_DAYS * 24 * 60 * 60 * 1000);
      const messages = await groupDoc.ref.collection("messages")
        .where("createdAt", ">=", cutoff)
        .orderBy("createdAt", "desc")
        .limit(MAX_MESSAGES)
        .get();
      const actorIds = [...new Set(messages.docs.map((doc) =>
        doc.data()?.senderId).filter(Boolean))];
      const memberRefs = actorIds.map((uid) =>
        groupDoc.ref.collection("members").doc(uid));
      const userRefs = actorIds.map((uid) => db.collection("users").doc(uid));
      const memberDocs = memberRefs.length ? await db.getAll(...memberRefs) : [];
      const userDocs = userRefs.length ? await db.getAll(...userRefs) : [];
      const now = new Date();
      const accountCutoff = now.getTime() -
        MIN_ACCOUNT_AGE_DAYS * 24 * 60 * 60 * 1000;
      const membershipCutoff = now.getTime() -
        MIN_MEMBERSHIP_AGE_HOURS * 60 * 60 * 1000;
      const qualifyingActorIds = new Set(actorIds.filter((uid, index) => {
        const userCreatedAt = dateValue(userDocs[index]?.data()?.createdAt);
        const joinedAt = dateValue(memberDocs[index]?.data()?.joinedAt);
        return userDocs[index]?.exists && memberDocs[index]?.exists &&
          userCreatedAt.getTime() <= accountCutoff &&
          joinedAt.getTime() <= membershipCutoff;
      }));
      const score = calculateActivityScore({
        messages: messages.docs.map((doc) => doc.data() || {}),
        memberCount: group.membersCount || 0,
        hasImage: typeof group.imageUrl === "string" && group.imageUrl.length > 0,
        hasDescription: typeof group.description === "string" &&
          group.description.trim().length >= 20,
        hasRules: typeof group.rules === "string" && group.rules.trim().length >= 20,
        qualifyingActorIds,
        now,
      });
      const createdAt = dateValue(group.createdAt);
      const ageDays = (now.getTime() - createdAt.getTime()) /
        (24 * 60 * 60 * 1000);
      const risingEligible = (group.membersCount || 0) >= 2 &&
        (group.membersCount || 0) <= 200 &&
        ageDays <= 180 &&
        score > 0;
      batch.update(groupDoc.ref, {
        activityScore: score,
        risingEligible,
        activityScoreUpdatedAt: FieldValue.serverTimestamp(),
        activityMetrics: {
          recentMessageCount: messages.size,
          activeMemberCount: qualifyingActorIds.size,
          scoreWindowDays: WINDOW_DAYS,
        },
      });
      writes += 1;
      if (writes === 400) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();
    await stateRef.set({
      lastGroupId: groups.size < GROUPS_PER_RUN
        ? null
        : groups.docs[groups.docs.length - 1].id,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { groups: groups.size };
  }

  return { updateScores };
}

module.exports = {
  calculateActivityScore,
  createDiscoveryScheduler,
  onSchedule,
};