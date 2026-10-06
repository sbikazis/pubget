'use strict';

/// Ranked, signal-backed Home sections that did not exist in the first
/// discovery feed. Master Spec §5.3 requires anime of the week, popular
/// characters, friends' activity, rising creators and the freshest content.
///
/// Every ranking function here takes already-read rows and returns ranked rows.
/// The ranking decisions are deliberately pure so they are unit-testable
/// without the Firestore emulator, and so a section can never invent an item:
/// rows with no real signal are dropped rather than padded.

const WEEK_MILLIS = 7 * 24 * 60 * 60 * 1000;

class AnimeCatalogRow {
  constructor({ id, title, ratingCount, weeklyRatingCount, lastRatedAt }) {
    this.id = id;
    this.title = title;
    this.ratingCount = ratingCount;
    this.weeklyRatingCount = weeklyRatingCount;
    this.lastRatedAt = lastRatedAt;
  }
}

class CharacterPopularityRow {
  constructor({ characterId, name, favouriteCount, discussionCount }) {
    this.characterId = characterId;
    this.name = name;
    this.favouriteCount = favouriteCount;
    this.discussionCount = discussionCount;
  }
}

class CreatorActivityRow {
  constructor({ creatorId, displayName, editCount, fanWorkCount, totalEngagement }) {
    this.creatorId = creatorId;
    this.displayName = displayName;
    this.editCount = editCount;
    this.fanWorkCount = fanWorkCount;
    this.totalEngagement = totalEngagement;
  }
}

class FriendActivityRow {
  constructor({ uid, kind, refId, createdAtMillis }) {
    this.uid = uid;
    this.kind = kind;
    this.refId = refId;
    this.createdAtMillis = createdAtMillis;
  }
}

class FreshContentRow {
  constructor({ refId, kind, title, createdAtMillis }) {
    this.refId = refId;
    this.kind = kind;
    this.title = title;
    this.createdAtMillis = createdAtMillis;
  }
}

class RankedSectionItem {
  constructor({ id, title, reason, score, metadata }) {
    this.id = id;
    this.title = title;
    this.reason = reason;
    this.score = score;
    this.metadata = metadata || {};
  }
}

function countOf(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value < 0 ? 0 : value;
  }
  return 0;
}

function intCountOf(value) {
  return Math.trunc(countOf(value));
}

/// Natural log, dampening engagement so one viral item cannot dominate a
/// ranking that is supposed to measure sustained activity.
function log1p(value) {
  return Math.log1p(countOf(value));
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

/// Anime of the week.
///
/// Ranked on activity inside the last seven days. Lifetime rating count is a
/// tiebreaker only, so a show with a large all-time total cannot sit at the top
/// permanently while nobody is rating it.
function rankAnimeOfTheWeek(rows, { now, limit = 8 }) {
  const cutoff = now.getTime() - WEEK_MILLIS;
  const eligible = [];
  for (const row of rows) {
    if (!row || typeof row.id !== 'string' || row.id.length === 0) continue;
    if (!(row.lastRatedAt instanceof Date)) continue;
    if (row.lastRatedAt.getTime() < cutoff) continue;
    if (intCountOf(row.weeklyRatingCount) <= 0) continue;
    eligible.push(row);
  }
  eligible.sort((a, b) => {
    const byWeekly = intCountOf(b.weeklyRatingCount).compareTo(
      intCountOf(a.weeklyRatingCount),
    );
    if (byWeekly !== 0) return byWeekly;
    const byTotal = intCountOf(b.ratingCount).compareTo(intCountOf(a.ratingCount));
    if (byTotal !== 0) return byTotal;
    return a.id.localeCompare(b.id);
  });
  return eligible.slice(0, limit);
}

/// Popular characters.
///
/// Real community signals only: favourites and discussion counts. A character
/// with neither is dropped instead of being shown as a suggestion.
function rankPopularCharacters(rows, { limit = 8 }) {
  const scored = [];
  for (const row of rows) {
    if (!row || typeof row.characterId !== 'string' || !row.characterId) continue;
    const favourites = intCountOf(row.favouriteCount);
    const discussions = intCountOf(row.discussionCount);
    if (favourites <= 0 && discussions <= 0) continue;
    const score = log1p(favourites) + log1p(discussions) * 1.4;
    scored.push(
      new RankedSectionItem({
        id: row.characterId,
        title: typeof row.name === 'string' ? row.name : '',
        reason: discussions > 0 ? 'community' : 'favourites',
        score: round2(score),
        metadata: {
          favouriteCount: favourites,
          discussionCount: discussions,
        },
      }),
    );
  }
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.id.localeCompare(b.id);
  });
  return spread(scored, limit);
}

/// Rising creators.
///
/// Requires sustained output: a single post is not a rising creator, however
/// well it performed. Engagement is damped by a log so one viral clip cannot
/// outrank consistent work.
function rankRisingCreators(rows, { limit = 8, viewerUid }) {
  const minimumPosts = 2;
  const scored = [];
  for (const row of rows) {
    if (!row || typeof row.creatorId !== 'string' || !row.creatorId) continue;
    if (viewerUid && row.creatorId === viewerUid) continue;
    const posts = intCountOf(row.editCount) + intCountOf(row.fanWorkCount);
    if (posts < minimumPosts) continue;
    const engagement = intCountOf(row.totalEngagement);
    const score =
      log1p(posts) * 2.4 + log1p(engagement <= 0 ? 0 : engagement / 12);
    scored.push(
      new RankedSectionItem({
        id: row.creatorId,
        title: typeof row.displayName === 'string' ? row.displayName : '',
        reason: 'rising',
        score: round2(score),
        metadata: {
          editCount: intCountOf(row.editCount),
          fanWorkCount: intCountOf(row.fanWorkCount),
        },
      }),
    );
  }
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.id.localeCompare(b.id);
  });
  return scored.slice(0, limit);
}

/// Activity from people the viewer actually follows.
///
/// One item per friend (their most recent act), newest first, with the viewer
/// and anyone they blocked removed.
function rankFriendsActivity(
  rows, {
    viewerUid,
    blockedIds = new Set(),
    limit = 8,
  },
) {
  const latest = new Map();
  for (const row of rows) {
    if (!row || typeof row.uid !== 'string' || !row.uid) continue;
    if (row.uid === viewerUid) continue;
    if (blockedIds.has(row.uid)) continue;
    const at = intCountOf(row.createdAtMillis);
    if (at <= 0) continue;
    const current = latest.get(row.uid);
    if (!current || at > intCountOf(current.createdAtMillis)) {
      latest.set(row.uid, row);
    }
  }
  const ranked = [];
  for (const row of latest.values()) {
    ranked.push(
      new RankedSectionItem({
        id: `${row.uid}:${row.kind}:${row.refId}`,
        title: typeof row.kind === 'string' ? row.kind : '',
        reason: typeof row.kind === 'string' ? row.kind : 'activity',
        score: intCountOf(row.createdAtMillis),
        metadata: {
          uid: row.uid,
          kind: row.kind,
          refId: row.refId,
          createdAtMillis: intCountOf(row.createdAtMillis),
        },
      }),
    );
  }
  ranked.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.id.localeCompare(b.id);
  });
  return ranked.slice(0, limit);
}

/// Freshest content across kinds, newest publication time first.
///
/// Capped per kind so one prolific surface cannot push the others out of Home.
function rankFreshestContent(rows, { limit = 8, perKindCap = 4 }) {
  const byKind = new Map();
  for (const row of rows) {
    if (!row || typeof row.refId !== 'string' || !row.refId) continue;
    const at = intCountOf(row.createdAtMillis);
    if (at <= 0) continue;
    const kind = typeof row.kind === 'string' && row.kind ? row.kind : 'other';
    if (!byKind.has(kind)) byKind.set(kind, []);
    byKind.get(kind).push({ row, at });
  }
  for (const items of byKind.values()) {
    items.sort((a, b) => b.at - a.at);
  }
  const preferred = ['edit', 'fanWork', 'groupJoin', 'event'];
  const kinds = [
    ...preferred.filter((kind) => byKind.has(kind)),
    ...[...byKind.keys()].filter((kind) => !preferred.includes(kind)),
  ];
  const ranked = [];
  for (const kind of kinds) {
    for (const entry of byKind.get(kind).slice(0, perKindCap)) {
      ranked.push(
        new RankedSectionItem({
          id: `${kind}:${entry.row.refId}`,
          title:
            typeof entry.row.title === 'string' ? entry.row.title : '',
          reason: kind,
          score: entry.at,
          metadata: {
            kind,
            refId: entry.row.refId,
            createdAtMillis: entry.at,
          },
        }),
      );
    }
  }
  ranked.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.id.localeCompare(b.id);
  });
  return ranked.slice(0, limit);
}

function spread(items, limit) {
  const seen = new Set();
  const unique = [];
  for (const item of items) {
    if (!item || typeof item.id !== 'string' || !item.id) continue;
    if (seen.has(item.id)) continue;
    seen.add(item.id);
    unique.push(item);
    if (unique.length >= limit) break;
  }
  return unique;
}

/// Clamp a client-supplied page size into a range the callable will honour.
function clampHomeLimit(value, { page }) {
  const max = 20;
  const fallback = page > max ? max : page;
  const parsed = intCountOf(value);
  if (parsed < 1) return fallback;
  if (parsed > max) return max;
  return parsed;
}

/// These sections are per-user, so an authenticated viewer is required.
/// Refusing here is what stops them degrading into an unfiltered browse for a
/// signed-out visitor.
function assertViewer(uid) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new Error('Authentication is required.');
  }
}

module.exports = {
  WEEK_MILLIS,
  AnimeCatalogRow,
  CharacterPopularityRow,
  CreatorActivityRow,
  FriendActivityRow,
  FreshContentRow,
  RankedSectionItem,
  rankAnimeOfTheWeek,
  rankPopularCharacters,
  rankRisingCreators,
  rankFriendsActivity,
  rankFreshestContent,
  clampHomeLimit,
  assertViewer,
};