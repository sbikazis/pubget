"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { calculateActivityScore } = require("../src/discoveryEngine");

const now = new Date("2026-09-01T00:00:00Z");
const message = (senderId, day, replyToId = null) => ({
  senderId,
  replyToMessageId: replyToId,
  createdAt: new Date(`2026-08-${day}T12:00:00Z`),
});

test("activity score rewards diverse regular conversation", () => {
  const diverse = calculateActivityScore({
    messages: [
      message("a", 26),
      message("b", 27, "m1"),
      message("c", 28),
      message("d", 29, "m2"),
      message("e", 30),
      message("a", 31, "m3"),
    ],
    memberCount: 8,
    hasImage: true,
    hasDescription: true,
    hasRules: true,
    now,
  });
  const repeated = calculateActivityScore({
    messages: Array.from({ length: 100 }, () => message("a", 31)),
    memberCount: 8,
    hasImage: true,
    hasDescription: true,
    hasRules: true,
    now,
  });
  assert.ok(diverse > repeated);
});

test("old messages do not raise the current activity score", () => {
  const score = calculateActivityScore({
    messages: [message("a", 1), message("b", 2, "m1")],
    memberCount: 5,
    hasImage: false,
    hasDescription: false,
    hasRules: false,
    now,
  });
  assert.equal(score, 0);
});