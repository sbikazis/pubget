"use strict";

// Multi-user Prompt 18 E2E against the Firebase Emulator Suite.
// This is not hosted production E2E.

const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-pubget-security";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-security" });
}

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");
const { createGamesDomain } = require("../src/gamesDomain");
const { createEventsDomain } = require("../src/eventsDomain");
const { createAchievementsDomain } = require("../src/achievementsDomain");
const { createMafiaDomain } = require("../src/mafia/mafiaDomain");
const { assignRoles } = require("../src/mafia/roleAssigner");
const { resolveNight } = require("../src/mafia/nightResolver");
const { resolveVotes } = require("../src/mafia/voteResolver");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;
const db = admin.firestore();
let env;

function auth(uid) {
  return { auth: { uid } };
}

function games() {
  return createGamesDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

function events() {
  return createEventsDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

function achievements(clock) {
  return createAchievementsDomain({
    db, FieldValue, HttpsError: TestHttpsError, clock,
  });
}

function mafia() {
  return createMafiaDomain({
    db, FieldValue, Timestamp, HttpsError: TestHttpsError,
  });
}

function client(uid) {
  return env.authenticatedContext(uid).firestore();
}

async function seedGroup() {
  await db.doc("users/alice").set({ username: "Alice" });
  await db.doc("users/bob").set({ username: "Bob" });
  await db.doc("users/charlie").set({ username: "Charlie" });
  await db.doc("users/dave").set({ username: "Dave" });
  await db.doc("groups/g-e2e").set({
    founderId: "alice", name: "E2E", hasRunningGame: false,
  });
  await db.doc("groups/g-e2e/members/alice").set({ role: "founder", userId: "alice" });
  await db.doc("groups/g-e2e/members/bob").set({ role: "member", userId: "bob" });
  await db.doc("groups/g-e2e/members/charlie").set({ role: "member", userId: "charlie" });
  await db.doc("groups/g-e2e/members/dave").set({ role: "member", userId: "dave" });
}

test.before(async () => {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  env = await initializeTestEnvironment({
    projectId: "demo-pubget-security",
    firestore: { host: "127.0.0.1", port: 8080, rules },
  });
});

test.beforeEach(async () => {
  if (env && typeof env.clearFirestore === "function") {
    await env.clearFirestore();
  }
  await seedGroup();
});

test("guess character multiplayer create/join/start/submit hides the secret", async () => {
  const domain = games();
  const created = await domain.createGame({
    ...auth("alice"),
    data: { type: "guessCharacter", title: "Guess E2E", groupId: "g-e2e" },
  });
  await domain.joinGame({ ...auth("bob"), data: { gameId: created.gameId } });
  await domain.startGame({ ...auth("alice"), data: { gameId: created.gameId } });
  const snap = await db.doc(`games/${created.gameId}`).get();
  const game = snap.data();
  assert.equal(game.status, "active");
  assert.ok(game.publicState.prompt.artwork);
  assert.ok(game.publicState.prompt.choices.length >= 2);
  const secretSnap = await db.doc(`games/${created.gameId}/secret/round`).get();
  assert.equal(secretSnap.exists, true);
  await assertFails(client("alice").doc(`games/${created.gameId}/secret/round`).get());
  await assertFails(client("bob").doc(`games/${created.gameId}/secret/round`).get());
  const correct = secretSnap.data().correctId;
  const wrong = game.publicState.prompt.choices.find((item) => item.id !== correct).id;
  await domain.submitGameAction({
    ...auth("alice"),
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { choiceId: correct },
      clientActionId: "alice-e2e",
    },
  });
  await domain.submitGameAction({
    ...auth("bob"),
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { choiceId: wrong },
      clientActionId: "bob-e2e",
    },
  });
  const after = (await db.doc(`games/${created.gameId}`).get()).data();
  assert.equal(after.publicState.scores.alice, 1);
  assert.equal(after.publicState.scores.bob, 0);
  await assert.rejects(
    domain.submitGameAction({
      ...auth("charlie"),
      data: { gameId: created.gameId, actionType: "guess", payload: { choiceId: correct } },
    }),
    (error) => error.code === "permission-denied" || error.code === "failed-precondition",
  );
});

test("emoji anime guess turn progression and invalid answers", async () => {
  const domain = games();
  const created = await domain.createGame({
    ...auth("alice"),
    data: { type: "emojiAnimeGuess", title: "Emoji E2E", groupId: "g-e2e" },
  });
  await domain.joinGame({ ...auth("bob"), data: { gameId: created.gameId } });
  await domain.startGame({ ...auth("alice"), data: { gameId: created.gameId } });
  const game = (await db.doc(`games/${created.gameId}`).get()).data();
  assert.ok(game.publicState && game.publicState.currentPlayerId);
  const current = game.publicState.currentPlayerId;
  const other = current === "alice" ? "bob" : "alice";
  await assert.rejects(
    domain.submitGameAction({
      ...auth(other),
      data: { gameId: created.gameId, actionType: "guess", payload: { title: "Nope" } },
    }),
    (error) => error.code === "failed-precondition",
  );
  const before = (await db.doc(`games/${created.gameId}`).get()).data();
  const beforeScore = before.publicState.scores[current] || 0;
  await domain.submitGameAction({
    ...auth(current),
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { title: "Definitely Not An Anime" },
      clientActionId: `${current}-wrong`,
    },
  });
  const afterWrong = (await db.doc(`games/${created.gameId}`).get()).data();
  assert.equal(afterWrong.publicState.scores[current] || 0, beforeScore);
  const secret = (await db.doc(`games/${created.gameId}/secret/round`).get()).data();
  const guesser = afterWrong.publicState.currentPlayerId;
  await domain.submitGameAction({
    ...auth(guesser),
    data: {
      gameId: created.gameId,
      actionType: "guess",
      payload: { title: secret.title },
      clientActionId: `${guesser}-emoji`,
    },
  });
  const after = (await db.doc(`games/${created.gameId}`).get()).data();
  const scored = after.publicState && after.publicState.scores
    ? (after.publicState.scores[guesser] || 0)
    : 0;
  assert.ok(scored >= 1 || after.status === "completed");
});

test("comparison event, expiry, and server-verified challenge", async () => {
  const domain = events();
  const draft = await domain.saveEventDraft({
    ...auth("alice"),
    data: {
      type: "characterComparison",
      title: "Captain poll",
      groupId: "g-e2e",
      criterion: "Who leads better?",
      candidates: [{ characterId: "luffy" }, { characterId: "levi" }],
    },
  });
  await domain.publishEvent({
    ...auth("alice"),
    data: {
      eventId: draft.eventId,
      startAt: new Date(Date.now() - 1000).toISOString(),
      endAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    },
  });
  await domain.submitEventResponse({
    ...auth("bob"),
    data: { eventId: draft.eventId, responseData: { optionId: "luffy" } },
  });
  await assert.rejects(
    domain.submitEventResponse({
      ...auth("bob"),
      data: { eventId: draft.eventId, responseData: { optionId: "levi" } },
    }),
    (error) => error.code === "already-exists",
  );
  await domain.endEvent({ ...auth("alice"), data: { eventId: draft.eventId } });
  const ended = (await db.doc(`events/${draft.eventId}`).get()).data();
  assert.equal(ended.result.kind, "characterComparison");
  assert.deepEqual(ended.result.winnerIds, ["luffy"]);

  await db.doc("user_achievements/bob/items/community_milestone").set({
    achievementId: "community_milestone",
  });
  const challenge = await domain.saveEventDraft({
    ...auth("alice"),
    data: {
      type: "challenge",
      title: "Finish a game",
      groupId: "g-e2e",
      prompt: "Finish a Pubget game.",
      challengeKind: "finish_game",
    },
  });
  await domain.publishEvent({
    ...auth("alice"),
    data: {
      eventId: challenge.eventId,
      startAt: new Date(Date.now() - 1000).toISOString(),
      endAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    },
  });
  await assert.rejects(
    domain.submitEventResponse({
      ...auth("alice"),
      data: { eventId: challenge.eventId, responseData: { completed: true } },
    }),
    (error) => error.code === "failed-precondition",
  );
  await domain.submitEventResponse({
    ...auth("bob"),
    data: { eventId: challenge.eventId, responseData: { completed: true } },
  });
  const response = (await db.doc(`events/${challenge.eventId}/responses/bob`).get()).data();
  assert.equal(response.responseData.verified, true);
});

test("seasonal achievement unlocks once during the season", async () => {
  const domain = achievements({ now: () => new Date("2026-09-03T12:00:00Z") });
  const first = await domain.evaluate({ type: "game_won", userIds: ["alice"] });
  assert.equal(first.some((item) => item.achievementId === "autumn_2026_rally" && item.unlocked), true);
  const second = await domain.evaluate({ type: "game_won", userIds: ["alice"] });
  assert.equal(second.find((item) => item.achievementId === "autumn_2026_rally").reason, "already_unlocked");
  await assertFails(client("alice").doc("user_achievements/alice/items/forged").set({
    achievementId: "forged",
  }));
});

test("mafia lobby, private roles, night, vote, and unauthorized actions", async () => {
  const domain = mafia();
  const created = await domain.createMafiaGame({
    ...auth("alice"),
    data: { groupId: "g-e2e", minPlayers: 4, maxPlayers: 8 },
  });
  await domain.joinMafiaGame({ ...auth("bob"), data: { gameId: created.gameId } });
  await domain.joinMafiaGame({ ...auth("charlie"), data: { gameId: created.gameId } });
  await domain.joinMafiaGame({ ...auth("dave"), data: { gameId: created.gameId } });
  await domain.startMafiaGame({ ...auth("alice"), data: { gameId: created.gameId } });
  const starting = (await db.doc(`mafia_games/${created.gameId}`).get()).data();
  const assigned = await assignRoles(created.gameId, {
    ...starting,
    roleAssignmentOwner: starting.roleAssignmentClaim
      ? starting.roleAssignmentClaim.owner
      : "e2e",
  });
  if (!assigned) {
    await db.doc(`mafia_games/${created.gameId}`).update({
      status: "starting",
      currentPhase: "starting",
      playersCount: 4,
      minPlayers: 4,
      maxPlayers: 8,
      roleAssignmentClaim: {
        owner: "e2e",
        expiresAt: Timestamp.fromMillis(Date.now() + 60 * 1000),
      },
    });
    const retried = await assignRoles(created.gameId, {
      minPlayers: 4,
      maxPlayers: 8,
      playersCount: 4,
      roleAssignmentOwner: "e2e",
      version: "classic",
    });
    assert.equal(retried, true);
  }
  const roles = {};
  for (const uid of ["alice", "bob", "charlie", "dave"]) {
    const privateSnap = await db.doc(
      `mafia_games/${created.gameId}/players/${uid}/private/data`,
    ).get();
    roles[uid] = privateSnap.data();
    assert.ok(roles[uid].role);
  }
  await assertFails(client("alice").doc(
    `mafia_games/${created.gameId}/players/bob/private/data`,
  ).get());
  const mafiaUid = Object.keys(roles).find((uid) => roles[uid].role === "mafia");
  const citizenUid = Object.keys(roles).find((uid) => roles[uid].role === "citizen"
    || roles[uid].role === "doctor" || roles[uid].role === "detective");
  assert.ok(mafiaUid);
  assert.ok(citizenUid);
  const nightGame = (await db.doc(`mafia_games/${created.gameId}`).get()).data();
  assert.equal(nightGame.status, "night");
  const doctorUid = Object.keys(roles).find((uid) => roles[uid].role === "doctor");
  await assertSucceeds(client(mafiaUid).doc(
    `mafia_games/${created.gameId}/night_actions/${mafiaUid}_n1`,
  ).set({
    playerId: mafiaUid,
    targetId: citizenUid,
    nightNumber: 1,
    submittedAt: serverTimestamp(),
  }));
  if (doctorUid && doctorUid !== mafiaUid) {
    await assertSucceeds(client(doctorUid).doc(
      `mafia_games/${created.gameId}/night_actions/${doctorUid}_n1`,
    ).set({
      playerId: doctorUid,
      targetId: mafiaUid,
      nightNumber: 1,
      submittedAt: serverTimestamp(),
    }));
  }
  await assertFails(client(mafiaUid).doc(
    `mafia_games/${created.gameId}/night_actions/${mafiaUid}_n1`,
  ).set({
    playerId: mafiaUid,
    targetId: citizenUid,
    nightNumber: 1,
    submittedAt: serverTimestamp(),
  }));
  await assertFails(client(mafiaUid).doc(
    `mafia_games/${created.gameId}/night_actions/${mafiaUid}_n0`,
  ).set({
    playerId: mafiaUid,
    targetId: citizenUid,
    nightNumber: 0,
    submittedAt: serverTimestamp(),
  }));
  const resolved = await resolveNight(created.gameId, {
    currentNight: 1, status: "night", currentPhase: "night",
  });
  assert.equal(resolved, true);
  await db.doc(`mafia_games/${created.gameId}`).update({
    status: "voting", currentPhase: "voting", currentDay: 1, phaseEndsAt: null,
  });
  const alive = [];
  for (const uid of ["alice", "bob", "charlie", "dave"]) {
    const player = (await db.doc(`mafia_games/${created.gameId}/players/${uid}`).get()).data();
    if (player.isAlive === true) alive.push(uid);
  }
  const voter = alive[0];
  const target = alive.find((uid) => uid !== voter) || alive[0];
  await assertSucceeds(client(voter).doc(
    `mafia_games/${created.gameId}/votes/${voter}_d1`,
  ).set({
    voterId: voter, targetId: target, dayNumber: 1, time: serverTimestamp(),
  }));
  await resolveVotes(created.gameId, {
    currentDay: 1, status: "voting", currentPhase: "voting",
  });
  await assertFails(client("mallory").doc(
    `mafia_games/${created.gameId}/votes/mallory_d1`,
  ).set({
    voterId: "mallory", targetId: target, dayNumber: 1, time: new Date(),
  }));
});
