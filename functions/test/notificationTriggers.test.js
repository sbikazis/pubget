"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createNotificationTriggers } = require("../src/notificationTriggers");

function snapshot(value) {
  return { exists: value !== undefined, data: () => value };
}

function createDb(seed = {}) {
  const values = new Map(Object.entries(seed));
  function reference(path) {
    return {
      async get() { return snapshot(values.get(path)); },
      collection(name) {
        return { doc: (id) => reference(path + "/" + name + "/" + id) };
      },
    };
  }
  return {
    collection(name) {
      return { doc: (id) => reference(name + "/" + id) };
    },
    values,
  };
}

function setup(seed = {}) {
  const db = createDb(seed);
  const calls = [];
  const builder = {
    async build(value) {
      calls.push(value);
      return { created: value.recipientIds.length };
    },
  };
  return { db, calls, triggers: createNotificationTriggers({ db, builder }) };
}

function pairId(a, b) {
  const [first, second] = [a, b].sort();
  return first.length + ":" + first + second.length + ":" + second;
}

test("Kirari like creates a notification for the creator, not the liker", async () => {
  const { triggers, calls } = setup({
    "kirari/reel-1": {
      creatorId: "creator", status: "published", moderationStatus: "approved",
    },
  });
  await triggers.kirariLike({
    id: "event-like-1",
    params: { reelId: "reel-1", actionId: "fan_like" },
    data: { data: () => ({ uid: "fan", kind: "like" }) },
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds, ["creator"]);
  assert.equal(calls[0].type, "kirari_like");
  assert.equal(calls[0].actorId, "fan");
  assert.equal(calls[0].destination, "/reel/reel-1");
});

test("Kirari likes do not notify the creator when the actor is muted or blocked", async () => {
  const blocked = setup({
    "kirari/reel-1": {
      creatorId: "creator", status: "published", moderationStatus: "approved",
    },
    ["friendships/" + pairId("creator", "fan")]: { status: "blocked" },
  });
  await blocked.triggers.kirariLike({
    id: "event-like-blocked",
    params: { reelId: "reel-1", actionId: "fan_like" },
    data: { data: () => ({ uid: "fan", kind: "like" }) },
  });
  assert.equal(blocked.calls.length, 0);

  const muted = setup({
    "kirari/reel-1": {
      creatorId: "creator", status: "published", moderationStatus: "approved",
    },
    "users/creator/kirariMutedCreators/fan": { creatorId: "fan" },
  });
  await muted.triggers.kirariLike({
    id: "event-like-muted",
    params: { reelId: "reel-1", actionId: "fan_like" },
    data: { data: () => ({ uid: "fan", kind: "like" }) },
  });
  assert.equal(muted.calls.length, 0);
});

test("Kirari comment replies notify the reel creator and parent comment author", async () => {
  const { triggers, calls } = setup({
    "kirari/reel-1": {
      creatorId: "creator", status: "published", moderationStatus: "approved",
    },
    "kirari/reel-1/comments/parent-1": {
      authorId: "parentAuthor", status: "published",
    },
  });
  await triggers.kirariComment({
    params: { reelId: "reel-1", commentId: "reply-1" },
    data: { data: () => ({
      authorId: "replyAuthor", parentId: "parent-1",
      text: "Thanks for replying", status: "published",
    }) },
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds.sort(), ["creator", "parentAuthor"]);
  assert.equal(calls[0].type, "kirari_comment_reply");
  assert.deepEqual(calls[0].metadata, {
    commentId: "reply-1", parentId: "parent-1",
  });
});

test("Respect notifications are emitted for changed positive values only", async () => {
  const { triggers, calls } = setup();
  await triggers.respectReceived({
    id: "respect-event-1",
    params: { respectId: "fan_creator" },
    data: {
      before: snapshot({ fromUserId: "fan", toUserId: "creator", value: 5 }),
      after: snapshot({ fromUserId: "fan", toUserId: "creator", value: 6 }),
    },
  });
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds, ["creator"]);
  assert.equal(calls[0].metadata.value, 6);
  assert.match(calls[0].id, /respect-event-1$/);

  await triggers.respectReceived({
    id: "respect-event-2",
    params: { respectId: "fan_creator" },
    data: {
      before: snapshot({ fromUserId: "fan", toUserId: "creator", value: 6 }),
      after: snapshot({ fromUserId: "fan", toUserId: "creator", value: 6 }),
    },
  });
  assert.equal(calls.length, 1);
});
