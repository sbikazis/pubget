"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  scoreEdit,
  scoreGroup,
  scorePerson,
  scoreFanWork,
  calculateRisingScore,
  applyDiversity,
  isColdStart,
  overlapScore,
  scoreAnime,
  editEngagement,
  scoreReelTrending,
} = require("../src/ranking");

const now = new Date("2026-09-03T12:00:00Z");

test("edit ranking prefers relevant qualified watches over raw impressions", () => {
  const profile = { userId: "alice", animeIds: ["one_piece"] };
  const relevant = scoreEdit({
    id: "e1", creatorId: "bob", animeTag: "one_piece",
    createdAt: now, qualifiedViewsCount: 12, completionCount: 8,
    likesCount: 4, commentsCount: 1, durationSeconds: 20, totalWatchSeconds: 140,
  }, profile, now);
  const unrelated = scoreEdit({
    id: "e2", creatorId: "bob", animeTag: "naruto",
    createdAt: now, qualifiedViewsCount: 40, completionCount: 1,
    likesCount: 1, durationSeconds: 20, totalWatchSeconds: 40,
  }, profile, now);
  assert.ok(relevant > unrelated);
});

test("qualified views raise the edit engagement component used by ranking", () => {
  const none = editEngagement({ qualifiedViewsCount: 0, likesCount: 0 });
  const one = editEngagement({ qualifiedViewsCount: 1, likesCount: 0 });
  assert.ok(one > none);
  assert.equal(one - none, 2);
});

test("self views and negative feedback cannot dominate edit ranking", () => {
  const profile = { userId: "alice", animeIds: ["one_piece"] };
  const self = scoreEdit({
    id: "e1", creatorId: "alice", animeTag: "one_piece",
    createdAt: now, qualifiedViewsCount: 80, likesCount: 80,
  }, profile, now);
  const other = scoreEdit({
    id: "e2", creatorId: "bob", animeTag: "one_piece",
    createdAt: now, qualifiedViewsCount: 8, likesCount: 3,
  }, profile, now);
  assert.ok(other > self);
  const abused = scoreEdit({
    id: "e3", creatorId: "bob", animeTag: "one_piece",
    createdAt: now, qualifiedViewsCount: 8, negativeFeedbackCount: 12,
  }, profile, now);
  assert.ok(abused < other);
});

test("group ranking is not member-count ranking", () => {
  const profile = { userId: "alice", animeIds: ["one_piece"], memberGroupIds: new Set() };
  const smallActive = scoreGroup({
    id: "g1", animeId: "one_piece", activityScore: 70, risingScore: 80,
    membersCount: 6, hasImage: true, description: "A".repeat(30), rules: "B".repeat(30),
    isSearchable: true, createdAt: now, lastMessageAt: now,
  }, profile, now);
  const largeIdle = scoreGroup({
    id: "g2", animeId: "naruto", activityScore: 2, risingScore: 1,
    membersCount: 400, isSearchable: true, createdAt: now,
  }, profile, now);
  assert.ok(smallActive > largeIdle);
});

test("people ranking uses shared interests and excludes self, blocks, and friends", () => {
  const profile = {
    userId: "alice",
    animeIds: ["one_piece"],
    blockedIds: new Set(["mallory"]),
    friendIds: new Set(["bob"]),
    mutualFriendIds: new Set(["carol"]),
  };
  assert.equal(scorePerson({ uid: "alice", favoriteAnimeIds: ["one_piece"] }, profile), 0);
  assert.equal(scorePerson({ uid: "mallory", favoriteAnimeIds: ["one_piece"] }, profile), 0);
  const friend = scorePerson({ uid: "bob", favoriteAnimeIds: ["one_piece"], totalRespect: 20 }, profile);
  const mutual = scorePerson({ uid: "carol", favoriteAnimeIds: ["one_piece"], totalRespect: 4 }, profile);
  const stranger = scorePerson({ uid: "dave", favoriteAnimeIds: ["naruto"], totalRespect: 40 }, profile);
  assert.ok(mutual > friend);
  assert.ok(mutual > stranger);
});

test("rising score rewards small active groups over large inactive and spam", () => {
  const small = calculateRisingScore({
    activityScore: 55, uniqueActors: 6, memberCount: 8, joinsInWindow: 4,
    ageDays: 12, messagesInWindow: 30, qualifyingActors: 6,
    completeness: 100, replyRate: 0.4, regularity: 0.6,
  });
  const largeIdle = calculateRisingScore({
    activityScore: 4, uniqueActors: 1, memberCount: 120, joinsInWindow: 0,
    ageDays: 400, messagesInWindow: 2, qualifyingActors: 1,
    completeness: 20, replyRate: 0, regularity: 0.1,
  });
  const spam = calculateRisingScore({
    activityScore: 40, uniqueActors: 1, memberCount: 5, joinsInWindow: 20,
    ageDays: 2, messagesInWindow: 80, qualifyingActors: 1,
    completeness: 10, replyRate: 0, regularity: 0.1,
  });
  assert.ok(small > largeIdle);
  assert.ok(small > spam);
});

test("diversity caps repeated creators", () => {
  const ranked = [
    { id: "1", creatorId: "a", score: 10 },
    { id: "2", creatorId: "a", score: 9 },
    { id: "3", creatorId: "a", score: 8 },
    { id: "4", creatorId: "b", score: 7 },
  ];
  const mixed = applyDiversity(ranked, { maxPerCreator: 2 });
  assert.equal(mixed[2].creatorId, "b");
});

test("cold start is true without interests or graph", () => {
  assert.equal(isColdStart({ animeIds: [], memberGroupIds: new Set(), friendIds: new Set() }), true);
  assert.equal(isColdStart({ animeIds: ["one_piece"], memberGroupIds: new Set(["g"]), friendIds: new Set() }), false);
});

test("interest overlap is deterministic", () => {
  assert.equal(overlapScore(["One_Piece"], ["one_piece"]), 100);
  assert.equal(overlapScore(["naruto"], ["one_piece"]), 0);
});

test("fan works require published approved state", () => {
  const profile = { userId: "alice", animeIds: ["one_piece"] };
  assert.equal(scoreFanWork({
    status: "draft", moderationStatus: "approved", animeId: "one_piece",
  }, profile, now), 0);
  const live = scoreFanWork({
    status: "published", moderationStatus: "approved", animeId: "one_piece",
    likesCount: 4, commentsCount: 0, publishedAt: now, version: 2,
    copyright: { originalWorkId: "op-1" },
  }, profile, now);
  const discussed = scoreFanWork({
    status: "published", moderationStatus: "approved", animeId: "one_piece",
    likesCount: 4, commentsCount: 12, publishedAt: now, version: 2,
    copyright: { originalWorkId: "op-1" },
  }, profile, now);
  assert.ok(live > 0);
  assert.ok(discussed > live);
});

test("anime recommendations prefer related taste over already-listed titles", () => {
  const profile = {
    userId: "alice",
    animeIds: ["one_piece"],
    listedAnimeIds: new Set(["one_piece"]),
  };
  const related = scoreAnime({ id: "wano", relatedIds: ["one_piece"], score: 8 }, profile);
  const already = scoreAnime({ id: "one_piece", relatedIds: ["one_piece"], score: 9 }, profile);
  assert.ok(related > already);
});

test("trending Reels rank by engagement velocity, not recency", () => {
  const HOUR = 60 * 60 * 1000;
  const nowTs = Date.UTC(2026, 0, 15);

  const freshButQuiet = {
    status: "published", moderationStatus: "approved",
    createdAt: new Date(nowTs - 1 * HOUR),
    qualifiedViewsCount: 20, likesCount: 1, commentsCount: 0,
    savesCount: 0, sharesCount: 0, negativeFeedbackCount: 0,
  };
  const olderButHot = {
    status: "published", moderationStatus: "approved",
    createdAt: new Date(nowTs - 12 * HOUR),
    qualifiedViewsCount: 4000, likesCount: 500, commentsCount: 80,
    savesCount: 120, sharesCount: 60, negativeFeedbackCount: 0,
  };
  const sameAgeLukewarm = {
    status: "published", moderationStatus: "approved",
    createdAt: new Date(nowTs - 12 * HOUR),
    qualifiedViewsCount: 30, likesCount: 2, commentsCount: 0,
    savesCount: 0, sharesCount: 0, negativeFeedbackCount: 0,
  };

  const freshScore = scoreReelTrending(freshButQuiet, nowTs);
  const hotScore = scoreReelTrending(olderButHot, nowTs);
  const lukewarmScore = scoreReelTrending(sameAgeLukewarm, nowTs);

  // Freshness alone must not win.
  assert.ok(hotScore > freshScore, "a hot 12h Reel should outrank a quiet 1h Reel");
  // Engagement, not age, separates two Reels published at the same moment.
  assert.ok(hotScore > lukewarmScore);
});

test("trending Reels without any qualified views are not surfaced as trending", () => {
  const nowTs = Date.UTC(2026, 0, 15);
  const noViews = {
    status: "published", moderationStatus: "approved",
    createdAt: new Date(nowTs - 2 * 60 * 60 * 1000),
    qualifiedViewsCount: 0, likesCount: 0, commentsCount: 0,
    savesCount: 0, sharesCount: 0, negativeFeedbackCount: 0,
  };
  const withViews = { ...noViews, qualifiedViewsCount: 25 };
  assert.ok(scoreReelTrending(noViews, nowTs) < 5);
  assert.ok(scoreReelTrending(withViews, nowTs) > scoreReelTrending(noViews, nowTs));
});

test("trending penalises negative feedback", () => {
  const nowTs = Date.UTC(2026, 0, 15);
  const base = {
    status: "published", moderationStatus: "approved",
    createdAt: new Date(nowTs - 3 * 60 * 60 * 1000),
    qualifiedViewsCount: 900, likesCount: 90, commentsCount: 10,
    savesCount: 5, sharesCount: 2,
  };
  const clean = scoreReelTrending(base, nowTs);
  const flagged = scoreReelTrending({ ...base, negativeFeedbackCount: 5 }, nowTs);
  assert.ok(clean > flagged);
});
