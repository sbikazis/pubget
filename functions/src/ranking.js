"use strict";

// Deterministic, content-specific ranking for Prompt 19 discovery.
// Weights are heuristic, not ML. Scores are 0–100 unless noted.
// Raw client counters are never trusted here; callers must pass
// server-owned fields.

const WEIGHTS = Object.freeze({
  edit: Object.freeze({
    relevance: 22,
    freshness: 16,
    engagement: 18,
    quality: 14,
    social: 8,
    velocity: 10,
    creator: 12,
  }),
  group: Object.freeze({
    relevance: 24,
    freshness: 8,
    engagement: 10,
    quality: 14,
    social: 16,
    velocity: 18,
    creator: 10,
  }),
  person: Object.freeze({
    relevance: 22,
    freshness: 6,
    engagement: 8,
    quality: 10,
    social: 36,
    velocity: 6,
    creator: 12,
  }),
  fanWork: Object.freeze({
    relevance: 24,
    freshness: 16,
    engagement: 16,
    quality: 18,
    social: 8,
    velocity: 8,
    creator: 10,
  }),
  event: Object.freeze({
    relevance: 26,
    freshness: 22,
    engagement: 12,
    quality: 10,
    social: 16,
    velocity: 8,
    creator: 6,
  }),
  anime: Object.freeze({
    relevance: 40,
    freshness: 10,
    engagement: 12,
    quality: 18,
    social: 10,
    velocity: 6,
    creator: 4,
  }),
});

const DIVERSITY = Object.freeze({
  maxPerCreator: 2,
  maxPerGroup: 2,
  minTypesPerPage: 3,
});

function clamp(value, min = 0, max = 100) {
  const n = Number(value);
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.toMillis === "function") return new Date(value.toMillis());
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function freshnessScore(createdAt, now, halfLifeDays) {
  const created = toDate(createdAt);
  if (!created) return 0;
  const ageDays = Math.max(0, (now.getTime() - created.getTime()) /
    (24 * 60 * 60 * 1000));
  const half = Math.max(0.5, halfLifeDays);
  return clamp(100 * Math.pow(0.5, ageDays / half));
}

function overlapScore(left, right) {
  const a = new Set((left || []).map((item) => String(item).toLowerCase()).filter(Boolean));
  const b = new Set((right || []).map((item) => String(item).toLowerCase()).filter(Boolean));
  if (a.size === 0 || b.size === 0) return 0;
  let hits = 0;
  for (const item of a) {
    if (b.has(item)) hits += 1;
  }
  return clamp((hits / Math.max(a.size, 1)) * 100);
}

function ratio(numerator, denominator, scale = 100) {
  if (!denominator) return 0;
  return clamp((numerator / denominator) * scale);
}

function editQuality(edit) {
  const duration = Math.max(1, Number(edit.durationSeconds) || 1);
  const completions = Number(edit.completionCount) || 0;
  const qualified = Number(edit.qualifiedViewsCount) || 0;
  const negatives = Number(edit.negativeFeedbackCount) || 0;
  const completionRate = ratio(completions, Math.max(qualified, 1));
  const watch = Math.min(1, (Number(edit.totalWatchSeconds) || 0) /
    (duration * Math.max(qualified, 1)));
  return clamp(
    completionRate * 0.5 +
    watch * 40 +
    Math.min(20, (Number(edit.likesCount) || 0) * 0.4) -
    Math.min(40, negatives * 8),
  );
}

function editEngagement(edit) {
  const qualified = Number(edit.qualifiedViewsCount) || 0;
  const likes = Number(edit.likesCount) || 0;
  const comments = Number(edit.commentsCount) || 0;
  const saves = Number(edit.savesCount) || 0;
  const shares = Number(edit.sharesCount) || 0;
  return clamp(
    Math.min(40, qualified * 2) +
    Math.min(20, likes) +
    Math.min(20, comments * 2) +
    Math.min(10, saves * 2) +
    Math.min(10, shares * 2),
  );
}

function scoreEdit(edit, profile, now) {
  const weights = WEIGHTS.edit;
  const tags = [edit.animeTag, edit.animeId].filter(Boolean);
  const relevance = overlapScore(profile.animeIds, tags);
  const freshness = freshnessScore(edit.createdAt, now, 10);
  const engagement = editEngagement(edit);
  const quality = editQuality(edit);
  const social = profile.creatorIds && profile.creatorIds.has(edit.creatorId) ? 80 : 0;
  const velocity = freshnessScore(edit.createdAt, now, 2) *
    Math.min(1, (Number(edit.qualifiedViewsCount) || 0) / 8);
  const creator = clamp(Number(edit.creatorQuality) || profile.creatorQuality || 0);
  const selfPenalty = edit.creatorId === profile.userId ? 40 : 0;
  const abuse = Math.min(50, (Number(edit.negativeFeedbackCount) || 0) * 10);
  const repetition = profile.seenIds && profile.seenIds.has(edit.id) ? 25 : 0;
  return clamp(
    relevance * weights.relevance / 100 +
    freshness * weights.freshness / 100 +
    engagement * weights.engagement / 100 +
    quality * weights.quality / 100 +
    social * weights.social / 100 +
    velocity * weights.velocity / 100 +
    creator * weights.creator / 100 -
    selfPenalty - abuse - repetition,
  );
}

function scoreGroup(group, profile, now) {
  const weights = WEIGHTS.group;
  const relevance = overlapScore(profile.animeIds, [group.animeId, group.animeTitle]);
  const freshness = freshnessScore(group.lastMessageAt || group.createdAt, now, 14);
  const engagement = clamp(Number(group.activityScore) || 0);
  const quality = clamp(
    (group.hasImage ? 30 : 0) +
    (String(group.description || "").trim().length >= 20 ? 35 : 0) +
    (String(group.rules || "").trim().length >= 20 ? 35 : 0),
  );
  const social = (profile.friendGroupIds && profile.friendGroupIds.has(group.id) ? 50 : 0) +
    (profile.memberGroupIds && profile.memberGroupIds.has(group.id) ? -100 : 0);
  const velocity = clamp(Number(group.risingScore) || Number(group.activityScore) || 0);
  const creator = clamp((Number(group.membersCount) || 0) >= 2 ? 40 : 10);
  const privateHidden = group.isSearchable === false ||
    group.joinPolicy === "inviteOnly";
  if (privateHidden) return 0;
  const spam = Number(group.spamPenalty) || 0;
  return clamp(
    relevance * weights.relevance / 100 +
    freshness * weights.freshness / 100 +
    engagement * weights.engagement / 100 +
    quality * weights.quality / 100 +
    Math.max(0, social) * weights.social / 100 +
    velocity * weights.velocity / 100 +
    creator * weights.creator / 100 -
    spam -
    (profile.memberGroupIds && profile.memberGroupIds.has(group.id) ? 80 : 0),
  );
}

function scorePerson(person, profile) {
  const weights = WEIGHTS.person;
  if (person.uid === profile.userId) return 0;
  if (profile.blockedIds && profile.blockedIds.has(person.uid)) return 0;
  if (person.profileVisibility === "private") return 0;
  const relevance = overlapScore(profile.animeIds, person.favoriteAnimeIds);
  const characterOverlap = overlapScore(profile.characterIds, person.favoriteCharacterIds);
  const social = (profile.mutualFriendIds && profile.mutualFriendIds.has(person.uid) ? 50 : 0) +
    (profile.mutualFanIds && profile.mutualFanIds.has(person.uid) ? 25 : 0) +
    (profile.sharedGroupIds && profile.sharedGroupIds[person.uid]
      ? Math.min(25, profile.sharedGroupIds[person.uid] * 8)
      : 0);
  const quality = clamp((Number(person.totalRespect) || 0) * 4);
  const creator = clamp((Number(person.fansCount) || 0) * 3);
  const alreadyFriend = profile.friendIds && profile.friendIds.has(person.uid);
  return clamp(
    (relevance * 0.7 + characterOverlap * 0.3) * weights.relevance / 100 +
    quality * weights.quality / 100 +
    social * weights.social / 100 +
    creator * weights.creator / 100 -
    (alreadyFriend ? 70 : 0),
  );
}

function scoreFanWork(work, profile, now) {
  const weights = WEIGHTS.fanWork;
  if (work.status !== "published" || work.moderationStatus !== "approved") return 0;
  const relevance = overlapScore(profile.animeIds, [work.animeId, ...(work.tags || [])]);
  const freshness = freshnessScore(work.publishedAt || work.createdAt, now, 21);
  const engagement = clamp(
    Math.min(50, (Number(work.likesCount) || 0) * 3) +
    Math.min(30, (Number(work.bookmarksCount) || 0) * 4) +
    Math.min(24, (Number(work.commentsCount) || 0) * 2),
  );
  const quality = clamp(40 + (Number(work.version) || 1) * 4 +
    (work.copyright && work.copyright.originalWorkId ? 10 : 0));
  const social = profile.creatorIds && profile.creatorIds.has(work.creatorId) ? 70 : 0;
  const creatorRepeat = profile.seenCreators &&
    (profile.seenCreators.get(work.creatorId) || 0) >= 2 ? 30 : 0;
  return clamp(
    relevance * weights.relevance / 100 +
    freshness * weights.freshness / 100 +
    engagement * weights.engagement / 100 +
    quality * weights.quality / 100 +
    social * weights.social / 100 -
    creatorRepeat,
  );
}

function scoreEvent(event, profile, now) {
  const weights = WEIGHTS.event;
  if (!["active", "scheduled"].includes(event.status)) return 0;
  const relevance = overlapScore(profile.animeIds, [event.animeId, event.groupId]);
  const social = profile.memberGroupIds && profile.memberGroupIds.has(event.groupId) ? 80 : 0;
  const freshness = freshnessScore(event.startAt || event.createdAt, now, 7);
  const engagement = clamp((Number(event.participantsCount) || 0) * 4);
  return clamp(
    relevance * weights.relevance / 100 +
    freshness * weights.freshness / 100 +
    engagement * weights.engagement / 100 +
    social * weights.social / 100,
  );
}

function scoreAnime(anime, profile) {
  const weights = WEIGHTS.anime;
  const relevance = overlapScore(
    [...(profile.animeIds || []), ...(profile.genreIds || [])],
    [anime.id, anime.malId, ...(anime.genres || []), ...(anime.relatedIds || [])],
  );
  const quality = clamp((Number(anime.score) || 0) * 10);
  const listed = profile.listedAnimeIds && profile.listedAnimeIds.has(String(anime.id));
  return clamp(
    relevance * weights.relevance / 100 +
    quality * weights.quality / 100 -
    (listed ? 60 : 0),
  );
}

function calculateRisingScore({
  activityScore,
  uniqueActors,
  memberCount,
  joinsInWindow,
  ageDays,
  messagesInWindow,
  qualifyingActors,
  completeness,
  replyRate,
  regularity,
}) {
  const members = Math.max(1, Number(memberCount) || 1);
  const age = Math.max(1, Number(ageDays) || 1);
  const velocity = clamp((Number(joinsInWindow) || 0) / Math.sqrt(age) * 35);
  const uniqueGrowth = clamp(((Number(uniqueActors) || 0) / members) * 100);
  const quality = clamp(Number(completeness) || 0);
  const response = clamp((Number(replyRate) || 0) * 100);
  const regular = clamp((Number(regularity) || 0) * 100);
  const activity = clamp(Number(activityScore) || 0);
  const burst = (Number(messagesInWindow) || 0) / Math.max(1, Number(qualifyingActors) || 1);
  const spamPenalty = burst > 20 ? Math.min(40, (burst - 20) * 2) : 0;
  const inactiveLarge = members >= 80 && activity < 8 ? 35 : 0;
  const tooNewSolo = age < 1 && (Number(uniqueActors) || 0) < 2 ? 20 : 0;
  return clamp(
    velocity * 0.22 +
    uniqueGrowth * 0.18 +
    quality * 0.12 +
    response * 0.14 +
    regular * 0.12 +
    activity * 0.22 -
    spamPenalty -
    inactiveLarge -
    tooNewSolo,
  );
}

function applyDiversity(ranked, options = {}) {
  const maxCreator = options.maxPerCreator || DIVERSITY.maxPerCreator;
  const maxGroup = options.maxPerGroup || DIVERSITY.maxPerGroup;
  const creators = new Map();
  const groups = new Map();
  const accepted = [];
  const overflow = [];
  for (const item of ranked) {
    const creator = item.creatorId || item.metadata && item.metadata.creatorId;
    const groupId = item.groupId || item.metadata && item.metadata.groupId;
    const creatorCount = creator ? (creators.get(creator) || 0) : 0;
    const groupCount = groupId ? (groups.get(groupId) || 0) : 0;
    if ((creator && creatorCount >= maxCreator) || (groupId && groupCount >= maxGroup)) {
      overflow.push(item);
      continue;
    }
    accepted.push(item);
    if (creator) creators.set(creator, creatorCount + 1);
    if (groupId) groups.set(groupId, groupCount + 1);
  }
  return accepted.concat(overflow);
}

function isColdStart(profile) {
  const anime = (profile.animeIds || []).length;
  const groups = profile.memberGroupIds ? profile.memberGroupIds.size : 0;
  const friends = profile.friendIds ? profile.friendIds.size : 0;
  return anime + groups + friends < 2;
}

function mixExploration(ranked, exploreShare = 0.2) {
  if (ranked.length < 4) return ranked;
  const exploreCount = Math.max(1, Math.floor(ranked.length * exploreShare));
  const head = ranked.slice(0, ranked.length - exploreCount);
  const tail = ranked.slice(ranked.length - exploreCount);
  const mixed = [];
  let i = 0;
  let j = 0;
  while (i < head.length || j < tail.length) {
    if (i < head.length) mixed.push(head[i++]);
    if (j < tail.length && mixed.length % 5 === 4) mixed.push(tail[j++]);
  }
  while (j < tail.length) mixed.push(tail[j++]);
  return mixed;
}

module.exports = {
  WEIGHTS,
  DIVERSITY,
  clamp,
  freshnessScore,
  overlapScore,
  scoreEdit,
  scoreGroup,
  scorePerson,
  scoreFanWork,
  scoreEvent,
  scoreAnime,
  calculateRisingScore,
  applyDiversity,
  isColdStart,
  mixExploration,
};
