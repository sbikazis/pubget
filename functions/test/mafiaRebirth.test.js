"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-pubget-rebirth" });
const { computeRoleDistribution } = require("../src/mafia/roleAssigner");
const { planNightResolution } = require("../src/mafia/nightResolver");
const { planVoteResolution } = require("../src/mafia/voteResolver");
const { nextPhase } = require("../src/mafia/phaseFlow");

function player(id, role, team, extras = {}) {
  return {
    userId: id,
    role,
    team,
    isAlive: true,
    hasLeft: false,
    canUseAbility: true,
    canVote: true,
    ...extras,
  };
}

test("Prompt 2 distribution uses only the five allowed roles", () => {
  const roles = computeRoleDistribution(7, 2);
  assert.equal(roles.length, 7);
  assert.equal(roles.filter((role) => role === "don").length, 1);
  assert.equal(roles.filter((role) => role === "mafia").length, 1);
  assert.ok(roles.includes("doctor"));
  assert.ok(roles.includes("detective"));
  assert.ok(roles.every((role) => [
    "mafia", "don", "doctor", "detective", "citizen",
  ].includes(role)));
});

test("Don investigation is private and Doctor cannot protect twice consecutively", () => {
  const playersById = {
    don: player("don", "don", "mafias"),
    mafia: player("mafia", "mafia", "mafias"),
    doctor: player("doctor", "doctor", "citizens", {
      lastProtectedTargetId: "town",
    }),
    detective: player("detective", "detective", "citizens"),
    town: player("town", "citizen", "citizens"),
  };
  const plan = planNightResolution({
    playersById,
    nightNumber: 2,
    actions: [
      { playerId: "don", targetId: "town", nightNumber: 2 },
      { playerId: "doctor", targetId: "town", nightNumber: 2 },
      { playerId: "detective", targetId: "mafia", nightNumber: 2 },
    ],
  });
  assert.equal(plan.mafiaTargetId, "town");
  assert.deepEqual(plan.savedIds, []);
  assert.equal(plan.donInvestigations[0].isDetective, false);
  assert.equal(plan.investigations[0].result, "Mafia");
});

test("revote resolution only counts the active voting round", () => {
  const playersById = {
    a: player("a", "citizen", "citizens"),
    b: player("b", "citizen", "citizens"),
    c: player("c", "mafia", "mafias"),
  };
  const result = planVoteResolution({
    playersById,
    dayNumber: 1,
    round: 1,
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1, round: 0 },
      { voterId: "b", targetId: "c", dayNumber: 1, round: 1 },
      { voterId: "c", targetId: "b", dayNumber: 1, round: 1 },
    ],
  });
  assert.equal(result.kind, "tie");
  assert.deepEqual(result.tally, { c: 1, b: 1 });
});

test("uppercase state machine includes role reveal, vote result, and resolution", () => {
  assert.equal(nextPhase("WAITING"), "STARTING");
  assert.equal(nextPhase("STARTING"), "ROLE_REVEAL");
  assert.equal(nextPhase("ROLE_REVEAL"), "NIGHT");
  assert.equal(nextPhase("VOTING"), "VOTE_RESULT");
  assert.equal(nextPhase("VOTE_RESULT"), "RESOLUTION");
  assert.equal(nextPhase("RESOLUTION"), "NIGHT");
});