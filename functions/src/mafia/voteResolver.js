"use strict";

const admin = require("firebase-admin");

const db = admin.firestore();

const ROLE_LABELS = {
  mafia: "Mafia",
  doctor: "the Doctor",
  detective: "the Detective",
  sniper: "the Sniper",
  silencer: "the Silencer",
  good_boy: "the Good Boy",
  citizen: "a Citizen",
};

function planVoteResolution({ playersById, votes, dayNumber }) {
  const validVotes = (votes || []).filter((vote) => {
    if (!vote || typeof vote !== "object" || typeof vote.voterId !== "string" ||
        typeof vote.targetId !== "string" || !Number.isInteger(vote.dayNumber)) {
      return false;
    }
    const voter = playersById[vote.voterId];
    const target = playersById[vote.targetId];
    return voter && target && vote.dayNumber === dayNumber &&
      voter.isAlive === true && voter.hasLeft !== true && voter.canVote !== false &&
      target.isAlive === true && target.hasLeft !== true;
  });
  const tally = {};
  for (const vote of validVotes) {
    tally[vote.targetId] = (tally[vote.targetId] || 0) + 1;
  }
  if (Object.keys(tally).length === 0) {
    return { kind: "skip", reason: "no_votes", tally, targetId: null };
  }
  let topTargetId = null;
  let topCount = 0;
  let tiedCount = 0;
  for (const [targetId, count] of Object.entries(tally)) {
    if (count > topCount) {
      topCount = count;
      topTargetId = targetId;
      tiedCount = 1;
    } else if (count === topCount) {
      tiedCount += 1;
    }
  }
  if (tiedCount > 1) {
    return { kind: "tie", reason: "tie", tally, targetId: null };
  }
  return { kind: "execute", reason: "majority", tally, targetId: topTargetId };
}

async function resolveVotes(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const dayNumber = gameData.currentDay || 0;
  const currentGame = await gameRef.get();
  if (!currentGame.exists || currentGame.data().status !== "voting" ||
      currentGame.data().currentPhase !== "voting" ||
      currentGame.data().currentDay !== dayNumber) return false;

  const [playersSnap, votesSnap] = await Promise.all([
    playersRef.get(),
    gameRef.collection("votes").where("dayNumber", "==", dayNumber).get(),
  ]);

  const playersById = {};
  playersSnap.docs.forEach((doc) => {
    playersById[doc.id] = { ref: doc.ref, ...doc.data() };
  });

  const plan = planVoteResolution({
    playersById,
    votes: votesSnap.docs.map((doc) => doc.data()),
    dayNumber,
  });
  const eventsRef = gameRef.collection("events");

  if (plan.kind === "skip") {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "ExecutionSkipped",
      message: "Nobody voted. Nobody is eliminated.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber },
    });
    return true;
  }

  if (plan.kind === "tie") {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "ExecutionSkipped",
      message: "The vote tied. Nobody is eliminated.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber, tally: plan.tally },
    });
    return true;
  }

  const target = playersById[plan.targetId];
  if (!target || target.isAlive !== true || target.hasLeft === true) return false;

  const privateSnap = await target.ref.collection("private").doc("data").get();
  const role = privateSnap.exists ? privateSnap.data().role : "citizen";
  const roleLabel = ROLE_LABELS[role] || "a villager";
  const name = typeof target.username === "string" && target.username.trim()
    ? target.username.trim().slice(0, 80)
    : "A player";

  const batch = db.batch();
  batch.update(target.ref, {
    isAlive: false,
    canVote: false,
    canSpeak: false,
    canUseAbility: false,
    revealedRole: true,
  });
  batch.set(eventsRef.doc(`vote-${dayNumber}-resolved`), {
    type: "PlayerExecuted",
    message: `The village eliminated ${name}. They were ${roleLabel}.`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { playerId: plan.targetId, role, dayNumber },
  });
  await batch.commit();
  return true;
}

module.exports = { resolveVotes, planVoteResolution, ROLE_LABELS };
