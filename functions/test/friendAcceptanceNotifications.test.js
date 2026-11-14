"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createNotificationTriggers } = require("../src/notificationTriggers");

test("friend acceptance notifies only the original requester", async () => {
  const calls = [];
  const triggers = createNotificationTriggers({
    db: {},
    builder: { build: async (payload) => { calls.push(payload); return { created: 1 }; } },
  });

  await triggers.friendAccepted({
    params: { friendshipId: "pair-1" },
    data: {
      before: { data: () => ({ status: "pending", requestedBy: "alice", userIds: ["alice", "bob"] }) },
      after: { data: () => ({ status: "accepted", requestedBy: "alice", userIds: ["alice", "bob"] }) },
    },
  });

  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].recipientIds, ["alice"]);
  assert.equal(calls[0].actorId, "bob");
  assert.equal(calls[0].destination, "/profile?uid=bob");
  assert.equal(calls[0].type, "friend_accepted");
});

test("friend acceptance ignores unrelated updates and missing requesters", async () => {
  const calls = [];
  const triggers = createNotificationTriggers({
    db: {},
    builder: { build: async (payload) => { calls.push(payload); } },
  });

  await triggers.friendAccepted({
    params: { friendshipId: "pair-2" },
    data: {
      before: { data: () => ({ status: "accepted", requestedBy: "alice", userIds: ["alice", "bob"] }) },
      after: { data: () => ({ status: "accepted", requestedBy: "alice", userIds: ["alice", "bob"] }) },
    },
  });
  await triggers.friendAccepted({
    params: { friendshipId: "pair-3" },
    data: {
      before: { data: () => ({ status: "pending", userIds: ["alice", "bob"] }) },
      after: { data: () => ({ status: "accepted", userIds: ["alice", "bob"] }) },
    },
  });

  assert.equal(calls.length, 0);
});
