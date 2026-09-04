"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-mafia-engine" });
}

const { nextPhase, durationOf, PLAY_ORDER } = require("../src/mafia/phaseFlow");
const { computeRoleDistribution } = require("../src/mafia/roleAssigner");
const { planNightResolution, pickMajorityTarget } = require("../src/mafia/nightResolver");
const { planVoteResolution } = require("../src/mafia/voteResolver");
const { winnerFromAliveTeams } = require("../src/mafia/winConditionChecker");

function player(id, role, team, extras = {}) {
  return {
    userId: id,
    username: id,
    role,
    team,
    isAlive: true,
    hasLeft: false,
    canUseAbility: true,
    canVote: true,
    usedBullet: false,
    ...extras,
  };
}

test("mafia play loop returns to night after execution", () => {
  assert.equal(nextPhase("waiting"), "starting");
  assert.equal(nextPhase("starting"), "night");
  assert.equal(nextPhase("night"), "day");
  assert.equal(nextPhase("day"), "discussion");
  assert.equal(nextPhase("discussion"), "voting");
  assert.equal(nextPhase("voting"), "execution");
  assert.equal(nextPhase("execution"), "night");
  assert.equal(nextPhase("finished"), "finished");
  assert.ok(durationOf("night") > 0);
  assert.deepEqual(PLAY_ORDER[PLAY_ORDER.length - 1], "execution");
});

test("classic four-player roles stay below mafia parity", () => {
  const four = computeRoleDistribution(4, "classic");
  assert.equal(four.filter((role) => role === "mafia").length, 1);
  assert.ok(four.includes("doctor"));
  assert.ok(four.includes("detective"));
  const five = computeRoleDistribution(5, "classic");
  assert.equal(five.filter((role) => role === "mafia").length, 2);
  assert.ok(five.includes("doctor"));
});

test("night resolution kills, saves, investigates, and rejects invalid actions", () => {
  const playersById = {
    m1: player("m1", "mafia", "mafias"),
    m2: player("m2", "mafia", "mafias"),
    doc: player("doc", "doctor", "citizens"),
    det: player("det", "detective", "citizens"),
    town: player("town", "citizen", "citizens"),
  };
  const kill = planNightResolution({
    playersById,
    nightNumber: 1,
    actions: [
      { playerId: "m1", targetId: "town", nightNumber: 1 },
      { playerId: "m1", targetId: "doc", nightNumber: 1 },
      { playerId: "m2", targetId: "m1", nightNumber: 1 },
      { playerId: "det", targetId: "m1", nightNumber: 1 },
      { playerId: "town", targetId: "m1", nightNumber: 1 },
    ],
  });
  assert.equal(kill.mafiaTargetId, "town");
  assert.deepEqual(kill.killedIds, ["town"]);
  assert.deepEqual(kill.savedIds, []);
  assert.equal(kill.investigations[0].targetTeam, "mafias");

  const saved = planNightResolution({
    playersById,
    nightNumber: 1,
    actions: [
      { playerId: "m1", targetId: "town", nightNumber: 1 },
      { playerId: "doc", targetId: "town", nightNumber: 1 },
    ],
  });
  assert.deepEqual(saved.savedIds, ["town"]);
  assert.deepEqual(saved.killedIds, []);

  const stale = planNightResolution({
    playersById,
    nightNumber: 1,
    actions: [{ playerId: "m1", targetId: "town", nightNumber: 2 }],
  });
  assert.equal(stale.mafiaTargetId, null);
});

test("mafia night majority ties spare the village", () => {
  assert.equal(pickMajorityTarget([
    { targetId: "a" },
    { targetId: "b" },
  ]), null);
  assert.equal(pickMajorityTarget([
    { targetId: "a" },
    { targetId: "a" },
    { targetId: "b" },
  ]), "a");
});

test("voting majority executes, ties skip, dead votes are ignored", () => {
  const playersById = {
    a: player("a", "citizen", "citizens"),
    b: player("b", "citizen", "citizens"),
    c: player("c", "mafia", "mafias"),
    d: player("d", "citizen", "citizens", { isAlive: false }),
  };
  const majority = planVoteResolution({
    playersById,
    dayNumber: 1,
    votes: [
      { voterId: "a", targetId: "c", dayNumber: 1 },
      { voterId: "b", targetId: "c", dayNumber: 1 },
      { voterId: "d", targetId: "a", dayNumber: 1 },
    ],
  });
  assert.equal(majority.kind, "execute");
  assert.equal(majority.targetId, "c");

  const tie = planVoteResolution({
    playersById,
    dayNumber: 1,
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1 },
      { voterId: "b", targetId: "a", dayNumber: 1 },
    ],
  });
  assert.equal(tie.kind, "tie");
  assert.equal(tie.targetId, null);

  const skip = planVoteResolution({
    playersById,
    dayNumber: 1,
    votes: [],
  });
  assert.equal(skip.kind, "skip");
});

test("win check uses private teams and mafia parity", () => {
  assert.equal(winnerFromAliveTeams(["citizens", "citizens", "citizens"]), "citizens");
  assert.equal(winnerFromAliveTeams(["mafias", "citizens"]), "mafias");
  assert.equal(winnerFromAliveTeams(["mafias", "citizens", "citizens"]), null);
  assert.equal(winnerFromAliveTeams([]), null);
});
