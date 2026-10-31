"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createNotificationTriggers } = require("../src/notificationTriggers");

function makeDb({ followers = [], reel = null } = {}) {
  return {
    collectionGroup() {
      const query = { where() { return query; }, async get() { return { docs: [] }; } };
      return query;
    },
    collection(name) {
      if (name === "friendships") {
        const query = {
          where() { return query; },
          async get() { return { docs: [] }; },
          doc() { return { async get() { return { exists: false, data: () => null }; } }; },
        };
        return query;
      }
      if (name === "users") {
        return {
          doc() {
            return { collection() {
              return { doc() { return { async get() { return { exists: false }; } }; } };
            } };
          },
        };
      }
      if (name === "respects") {
        const query = {
          where() { return query; },
          limit() { return query; },
          async get() {
            return { docs: followers.map((uid) => ({ data: () => ({ fromUserId: uid }) })) };
          },
        };
        return query;
      }
      if (name === "kirari") {
        return {
          doc() {
            return { async get() { return { exists: Boolean(reel), data: () => reel }; } };
          },
        };
      }
      throw new Error("Unexpected collection: " + name);
    },
  };
}

test("Kirari publication notifies only unique followers after moderation approval", async () => {
  const calls = [];
  const triggers = createNotificationTriggers({
    db: makeDb({ followers: ["fan-1", "fan-2", "fan-1", "creator"] }),
    builder: { async build(payload) { calls.push(payload); } },
  });
  await triggers.kirariPublished({
    params: { reelId: "reel-1" },
    data: {
      before: { data: () => ({ status: "processing" }) },
      after: { data: () => ({
        creatorId: "creator", status: "published",
        moderationStatus: "approved", caption: "Anime edit",
      }) },
    },
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds, ["fan-1", "fan-2"]);
  assert.equal(calls[0].destination, "/reel/reel-1");
});

test("Kirari publication never notifies before moderation approval", async () => {
  const calls = [];
  const triggers = createNotificationTriggers({
    db: makeDb({ followers: ["fan-1"] }),
    builder: { async build(payload) { calls.push(payload); } },
  });
  await triggers.kirariPublished({
    params: { reelId: "reel-1" },
    data: {
      before: { data: () => ({ status: "processing" }) },
      after: { data: () => ({
        creatorId: "creator", status: "published",
        moderationStatus: "review_pending",
      }) },
    },
  });
  assert.equal(calls.length, 0);
});

test("Kirari comments notify the video creator but not the commenter", async () => {
  const calls = [];
  const triggers = createNotificationTriggers({
    db: makeDb({ reel: { creatorId: "creator" } }),
    builder: { async build(payload) { calls.push(payload); } },
  });
  await triggers.kirariComment({
    params: { reelId: "reel-1", commentId: "comment-1" },
    data: { data: () => ({ authorId: "fan-1", text: "Nice edit", status: "published" }) },
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds, ["creator"]);
  assert.equal(calls[0].destination, "/reel/reel-1");
});
