"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-mafia-engine" });
}

const { nextPhase, durationOf, PLAY_ORDER, ORDER } = require("../src/mafia/phaseFlow");
const { computeRoleDistribution } = require("../src/mafia/roleAssigner");
const { getAbility, ALL_ABILITIES } = require("../src/mafia/abilities");
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

test("mafia state machine follows the server-owned uppercase lifecycle", () => {
  assert.deepEqual(ORDER, [
    "WAITING", "STARTING", "ROLE_REVEAL", "NIGHT", "DAY", "DISCUSSION",
    "VOTING", "VOTE_RESULT", "RESOLUTION", "GAME_OVER", "CANCELLED",
  ]);
  assert.equal(nextPhase("WAITING"), "STARTING");
  assert.equal(nextPhase("STARTING"), "ROLE_REVEAL");
  assert.equal(nextPhase("ROLE_REVEAL"), "NIGHT");
  assert.equal(nextPhase("NIGHT"), "DAY");
  assert.equal(nextPhase("DAY"), "DISCUSSION");
  assert.equal(nextPhase("DISCUSSION"), "VOTING");
  assert.equal(nextPhase("VOTING"), "VOTE_RESULT");
  assert.equal(nextPhase("VOTE_RESULT"), "RESOLUTION");
  assert.equal(nextPhase("RESOLUTION"), "NIGHT");
  assert.equal(nextPhase("GAME_OVER"), "GAME_OVER");
  assert.equal(nextPhase("CANCELLED"), "CANCELLED");
  assert.ok(durationOf("NIGHT") > 0);
  assert.deepEqual(PLAY_ORDER[PLAY_ORDER.length - 1], "RESOLUTION");
  // The machine has no legacy revote or finished states.
  assert.equal(ORDER.includes("revote"), false);
  assert.equal(ORDER.includes("finished"), false);
  assert.equal(ORDER.includes("execution"), false);
});

// Master Spec 13.2 fixes the lobby at 7-15 players and 13.3 demands a
// deterministic distribution that never hands the town fewer players than the
// mafia team, otherwise the "mafia alive >= town alive" condition in 13.5 would
// already be true on night zero.
test("the 7-15 distribution keeps the town at or above mafia parity", () => {
  for (let count = 7; count <= 15; count += 1) {
    const roles = computeRoleDistribution(count);
    assert.equal(roles.length, count, `distribution must cover all ${count} players`);
    const mafiaCount = roles.filter((role) => role === "mafia").length;
    const donCount = roles.filter((role) => role === "don").length;
    const mafiaTeam = mafiaCount + donCount;
    const town = count - mafiaTeam;
    assert.equal(donCount, 1, "the Don is a single-slot role");
    assert.equal(roles.filter((role) => role === "doctor").length, 1);
    assert.equal(roles.filter((role) => role === "detective").length, 1);
    assert.ok(mafiaCount >= 1, "at least one plain mafia member always exists");
    assert.ok(town >= mafiaTeam, `town ${town} must not be outnumbered at ${count} players`);
  }
  // Deterministic: the same count always yields the same multiset.
  assert.deepEqual(computeRoleDistribution(11), computeRoleDistribution(11));
  // Out of the documented range there is no distribution at all.
  assert.deepEqual(computeRoleDistribution(6), []);
  assert.deepEqual(computeRoleDistribution(16), []);
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
  assert.equal(kill.investigations[0].result, "Mafia");

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

test("voting majority executes, first tie requests revote, second tie skips", () => {
  const playersById = {
    a: player("a", "citizen", "citizens"),
    b: player("b", "citizen", "citizens"),
    c: player("c", "mafia", "mafias"),
    d: player("d", "citizen", "citizens", { isAlive: false }),
  };
  const majority = planVoteResolution({
    playersById,
    dayNumber: 1,
    voteRound: 1,
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
    voteRound: 1,
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1 },
      { voterId: "b", targetId: "a", dayNumber: 1 },
    ],
  });
  assert.equal(tie.kind, "revote");
  assert.deepEqual(tie.tiedIds.sort(), ["a", "b"]);
  assert.equal(tie.targetId, null);

  // Second round tie → no elimination (voteRound >= 2). The ballots carry the
  // round they were cast in; a re-vote must not inherit the first round's votes.
  const secondTie = planVoteResolution({
    playersById,
    dayNumber: 1,
    voteRound: 2,
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1, voteRound: 2 },
      { voterId: "b", targetId: "a", dayNumber: 1, voteRound: 2 },
    ],
  });
  assert.equal(secondTie.kind, "skip");
  assert.equal(secondTie.reason, "second_tie");
  assert.equal(secondTie.targetId, null);

  // Round-1 ballots are ignored while round 2 is being counted.
  const inherited = planVoteResolution({
    playersById,
    dayNumber: 1,
    voteRound: 2,
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1, voteRound: 1 },
      { voterId: "b", targetId: "a", dayNumber: 1, voteRound: 1 },
    ],
  });
  assert.equal(inherited.kind, "skip");
  assert.equal(inherited.reason, "no_votes");

  // Revote round is restricted to the tied players only.
  const restricted = planVoteResolution({
    playersById,
    dayNumber: 1,
    voteRound: 2,
    tiedIds: ["a", "b"],
    votes: [
      { voterId: "a", targetId: "b", dayNumber: 1, voteRound: 2 },
      { voterId: "b", targetId: "a", dayNumber: 1, voteRound: 2 },
      { voterId: "a", targetId: "c", dayNumber: 1, voteRound: 2 },
      { voterId: "a", targetId: "b", dayNumber: 2, voteRound: 2 },
    ],
  });
  assert.equal(restricted.kind, "skip");
  assert.equal(restricted.reason, "second_tie");
  // The non-tied target ("c") and the stale day are ignored.
  assert.deepEqual(Object.keys(restricted.tally).sort(), ["a", "b"]);

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

test("only the five approved Mafia roles are distributed deterministically", () => {
  const roles = computeRoleDistribution(8);
  assert.deepEqual(
    [...new Set(roles)].sort(),
    ["citizen", "detective", "doctor", "don", "mafia"].sort(),
  );
  assert.equal(computeRoleDistribution(6).length, 0);
  assert.equal(computeRoleDistribution(16).length, 0);
  assert.equal(getAbility("don").team, "mafias");
  assert.equal(
    winnerFromAliveTeams(["mafias", "citizens"]),
    "mafias",
  );
  assert.equal(
    winnerFromAliveTeams(["citizens", "citizens"]),
    "citizens",
  );
});

test("abilities registry contains only the five approved roles", () => {
  assert.deepEqual(Object.keys(ALL_ABILITIES).sort().join(","),
    "citizen,detective,doctor,don,mafia");
  for (const role of ["mafia", "don", "doctor", "detective", "citizen"]) {
    assert.ok(ALL_ABILITIES[role], `missing ${role}`);
  }
});

test("Mafia role assignment does not include legacy or prohibited roles", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const role = fs.readFileSync(path.join(__dirname, "../src/mafia/roleAssigner.js"), "utf8");
  const lobby = fs.readFileSync(path.join(__dirname, "../src/mafia/lobbyManager.js"), "utf8");
  assert.match(role, /Roles have been assigned privately/);
  assert.equal(role.includes("good_boy"), false);
  assert.equal(role.includes("sniper"), false);
  assert.equal(role.includes("silencer"), false);
  assert.equal(lobby.includes("Mafia was cancelled"), true);
});

test("doctor cannot protect the same target twice and Don gets a private detective result", () => {
  const playersById = {
    don: player("don", "don", "mafias"),
    mafia: player("mafia", "mafia", "mafias"),
    doctor: player("doctor", "doctor", "citizens", { lastDoctorTargetId: "town" }),
    detective: player("detective", "detective", "citizens"),
    town: player("town", "citizen", "citizens"),
  };
  const plan = require("../src/mafia/nightResolver").planNightResolution({
    playersById,
    nightNumber: 2,
    actions: [
      { playerId: "don", targetId: "detective", nightNumber: 2 },
      { playerId: "doctor", targetId: "town", nightNumber: 2 },
    ],
  });
  assert.equal(plan.doctorTargetWasRepeated, true);
  assert.equal(plan.donInvestigations[0].result, "Detective");
  assert.equal(plan.investigations.length, 0);
});