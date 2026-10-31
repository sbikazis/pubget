"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  KIRARI, TRANSITIONS, transitionStatus, normalizeTags, rankKirari,
  createKirariDomain,
} = require("../src/kirariDomain");

class TestHttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

test("Kirari contract has strict media and daily upload limits", () => {
  assert.equal(KIRARI.minDurationSeconds, 3);
  assert.equal(KIRARI.maxDurationSeconds, 60);
  assert.equal(KIRARI.maxBytes, 500 * 1024 * 1024);
  assert.equal(KIRARI.dailyUploadLimit, 10);
  assert.equal(KIRARI.qualifiedViewSeconds, 3);
  assert.equal(KIRARI.completionPercent, 95);
});

test("Kirari lifecycle only allows declared transitions", () => {
  assert.equal(transitionStatus("uploading", "processing"), true);
  assert.equal(transitionStatus("processing", "preparing"), true);
  assert.equal(transitionStatus("preparing", "published"), true);
  assert.equal(transitionStatus("published", "processing"), false);
  assert.equal(transitionStatus("rejected", "published"), false);
  assert.equal(transitionStatus("failed", "uploading"), true);
  assert.equal(TRANSITIONS.deleted.size, 0);
});

test("hashtag normalization removes duplicates and unsafe characters", () => {
  assert.deepEqual(normalizeTags(["#Anime", "anime", " One_Piece! "]), ["anime", "one_piece"]);
  assert.deepEqual(normalizeTags(null), []);
  assert.throws(() => normalizeTags(new Array(13).fill("tag")));
});

test("Kirari ranking is bounded and reacts to relevance and negative feedback", () => {
  const now = Date.now();
  const base = {
    creatorId: "creator", hashtags: ["one_piece"],
    createdAt: { toMillis: () => now },
    qualifiedViewsCount: 100, completionCount: 70,
    likesCount: 20, commentsCount: 5, savesCount: 5, sharesCount: 2,
    creatorQuality: 80, negativeFeedbackCount: 0,
  };
  const relevant = rankKirari(base, { interests: ["one_piece"], creatorIds: [] }, now);
  const irrelevant = rankKirari(base, { interests: ["bleach"], creatorIds: [] }, now);
  const negative = rankKirari({ ...base, negativeFeedbackCount: 100 }, { interests: ["one_piece"] }, now);
  assert.ok(relevant > irrelevant);
  assert.ok(relevant > negative);
  assert.ok(relevant >= 0 && relevant <= 100);
});

test("all Kirari callables reject unauthenticated requests before touching Firestore", async () => {
  const domain = createKirariDomain({
    db: { collection() { throw new Error("database must not be touched"); } },
    FieldValue: {},
    HttpsError: TestHttpsError,
    bucket: {},
  });
  for (const [name, data] of [
    ["startUpload", {}],
    ["finalizeUpload", { reelId: "r1" }],
    ["retryProcessing", { reelId: "r1" }],
    ["cancelUpload", { reelId: "r1" }],
    ["deleteReel", { reelId: "r1" }],
    ["setCreatorMute", { creatorId: "bob" }],
    ["getHashtagFeed", { hashtag: "anime" }],
    ["action", { reelId: "r1", kind: "like" }],
    ["addComment", { reelId: "r1", text: "hi" }],
    ["commentAction", { reelId: "r1", commentId: "c1", kind: "like" }],
    ["startPlayback", { reelId: "r1" }],
    ["recordPlayback", { reelId: "r1", sessionId: "s1", eventId: "e1" }],
    ["getFeed", {}],
  ]) {
    await assert.rejects(
      domain[name]({ data }),
      (error) => error.code === "unauthenticated",
    );
  }
});
