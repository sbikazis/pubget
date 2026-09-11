"use strict";

const admin = require("firebase-admin");

const db = admin.firestore();

const ROLE_LABELS = {
  mafia: "Mafia",
  doctor: "the Doctor",
  detective: "the Detective",
  don: "the Don",
  citizen: "a Citizen",
};

function planVoteResolution({ playersById, votes, dayNumber, round = 0 }) {
  const validVotes = (votes || []).filter((vote) => {
    if (!vote || typeof vote !== "object" || typeof vote.voterId !== "string" ||
      typeof vote.targetId !== "string" || !Number.isInteger(vote.dayNumber) ||
      (vote.round ?? 0) !== round) {
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
  const round = gameData.revoteCount || 0;
  const currentGame = await gameRef.get();
  if (!currentGame.exists || currentGame.data().status !== "VOTING" ||
      currentGame.data().currentPhase !== "VOTING" ||
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
    round,
  });
  const eventsRef = gameRef.collection("events");

  if (plan.kind === "skip") {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "VoteResolved",
      message: "Nobody voted. Nobody is eliminated.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber },
    });
    await gameRef.update({
      status: "VOTE_RESULT",
      currentPhase: "VOTE_RESULT",
      voteResult: { kind: "skip", tally: plan.tally },
    });
    return true;
  }

  if (plan.kind === "tie") {
    const current = currentGame.data();
    const isRevote = (current.revoteCount || 0) > 0;
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: isRevote ? "VoteTieFinal" : "VoteTie",
      message: isRevote
        ? "The revote tied. Nobody is eliminated."
        : "The vote tied. A revote is open between the tied players.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber, tally: plan.tally, revote: !isRevote },
    });
    await gameRef.update({
      status: "VOTE_RESULT",
      currentPhase: "VOTE_RESULT",
      voteResult: {
        kind: isRevote ? "final_tie" : "tie",
        tally: plan.tally,
        tiedPlayerIds: Object.entries(plan.tally)
          .filter(([, count]) => count === Math.max(...Object.values(plan.tally)))
          .map(([id]) => id),
      },
      revoteCount: isRevote ? current.revoteCount : 1,
      revotePending: !isRevote,
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
    type: "PlayerEliminated",
    message: `The village eliminated ${name}. They were ${roleLabel}.`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { playerId: plan.targetId, role, dayNumber },
  });
  await batch.commit();
  await gameRef.update({
    status: "VOTE_RESULT",
    currentPhase: "VOTE_RESULT",
    voteResult: { kind: "execute", targetId: plan.targetId, tally: plan.tally },
    revotePending: false,
  });
  return true;
}

module.exports = { resolveVotes, planVoteResolution, ROLE_LABELS };
