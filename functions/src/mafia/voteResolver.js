"use strict";

const admin = require("firebase-admin");

const db = admin.firestore();

const ROLE_LABELS = {
  mafia: "Mafia",
  don: "Don",
  doctor: "the Doctor",
  detective: "the Detective",
  sniper: "the Sniper",
  silencer: "the Silencer",
  good_boy: "the Good Boy",
  citizen: "a Citizen",
};

function planVoteResolution({ playersById, votes, dayNumber, revote = false, tiedIds = [] }) {
  const validVotes = (votes || []).filter((vote) => {
    if (!vote || typeof vote !== "object" || typeof vote.voterId !== "string" ||
        typeof vote.targetId !== "string" || !Number.isInteger(vote.dayNumber)) {
      return false;
    }
    const voter = playersById[vote.voterId];
    const target = playersById[vote.targetId];
    return voter && target && vote.dayNumber === dayNumber &&
      voter.isAlive === true && voter.hasLeft !== true && voter.canVote !== false &&
      target.isAlive === true && target.hasLeft !== true &&
      vote.voterId !== vote.targetId &&
      (!revote || tiedIds.includes(vote.targetId));
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
    const candidates = Object.entries(tally)
      .filter(([, count]) => count === topCount)
      .map(([targetId]) => targetId);
    return {
      kind: revote ? "no_elimination" : "revote",
      reason: revote ? "second_tie" : "tie",
      tally,
      targetId: null,
      tiedIds: candidates,
    };
  }
  return { kind: "execute", reason: "majority", tally, targetId: topTargetId };
}

async function resolveVotes(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const dayNumber = gameData.currentDay || 0;
  const currentGame = await gameRef.get();
  const current = currentGame.exists ? currentGame.data() : {};
  const phase = current.currentPhase || current.status;
  if (!currentGame.exists || !["voting", "revote"].includes(phase) ||
      current.currentDay !== dayNumber) return false;
  const isRevote = phase === "revote";

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
    revote: isRevote,
    tiedIds: current.revoteCandidates || [],
    dayNumber,
  });
  const eventsRef = gameRef.collection("events");

  if (plan.kind === "skip" || plan.kind === "no_elimination") {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (!snap.exists || snap.data().currentPhase !== phase) return;
      tx.update(gameRef, {
        status: "resolution",
        currentPhase: "resolution",
        revoteCandidates: admin.firestore.FieldValue.delete(),
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 4_000),
      });
      tx.set(eventsRef.doc(`vote-${dayNumber}-${isRevote ? "revote" : "resolved"}`), {
        type: "VoteResolved",
        message: isRevote
          ? "The re-vote was tied. Nobody is eliminated."
          : "Nobody voted. Nobody is eliminated.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { dayNumber, revote: isRevote, tally: plan.tally },
      });
    });
    return true;
  }

  if (plan.kind === "revote") {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (!snap.exists || snap.data().currentPhase !== phase) return;
      tx.update(gameRef, {
        status: "revote",
        currentPhase: "revote",
        revoteCandidates: plan.tiedIds,
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30_000),
      });
      tx.set(eventsRef.doc(`vote-${dayNumber}-tie`), {
        type: "VoteTie",
        message: "The vote tied. A re-vote is open between the tied players.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { dayNumber, tiedIds: plan.tiedIds },
      });
    });
    return true;
  }

  if (plan.kind === "skip") {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "ExecutionSkipped",
      message: "Nobody voted. Nobody is eliminated.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber },
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
  batch.update(gameRef, {
    status: "resolution",
    currentPhase: "resolution",
    revoteCandidates: admin.firestore.FieldValue.delete(),
    phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 4_000),
    votingResults: admin.firestore.FieldValue.arrayUnion({
      dayNumber,
      revote: isRevote,
      tally: plan.tally,
      eliminatedPlayerId: plan.targetId,
      at: new Date(),
    }),
  });
  await batch.commit();
  return true;
}

module.exports = { resolveVotes, planVoteResolution, ROLE_LABELS };
