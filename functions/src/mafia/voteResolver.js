"use strict";

const admin = require("firebase-admin");

const db = admin.firestore();

const ROLE_LABELS = {
  mafia: "Mafia",
  don: "Don",
  doctor: "the Doctor",
  detective: "the Detective",
  citizen: "a Citizen",
};

function planVoteResolution({ playersById, votes, dayNumber, voteRound = 1, tiedIds = [] }) {
  const validVotes = (votes || []).filter((vote) => {
    if (!vote || typeof vote !== "object" || typeof vote.voterId !== "string" ||
        typeof vote.targetId !== "string" || !Number.isInteger(vote.dayNumber)) {
      return false;
    }
    // A ballot belongs to the round it was cast in. Without this, a re-vote
    // re-counted the first round's ballots and could tie itself forever.
    const ballotRound = Number.isInteger(vote.voteRound) ? vote.voteRound : 1;
    if (ballotRound !== voteRound) return false;
    const voter = playersById[vote.voterId];
    const target = playersById[vote.targetId];
    return voter && target && vote.dayNumber === dayNumber &&
      voter.isAlive === true && voter.hasLeft !== true && voter.canVote !== false &&
      target.isAlive === true && target.hasLeft !== true &&
      vote.voterId !== vote.targetId &&
      (tiedIds.length === 0 || tiedIds.includes(vote.targetId));
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
    // First round tie → re-vote within VOTING. Second round tie → skip.
    if (voteRound >= 2) {
      return { kind: "skip", reason: "second_tie", tally, targetId: null };
    }
    return { kind: "revote", reason: "tie", tally, targetId: null, tiedIds: candidates };
  }
  return { kind: "execute", reason: "majority", tally, targetId: topTargetId };
}

async function resolveVotes(gameId, gameData, deps = {}) {
  const database = deps.db || db;
  const gameRef = database.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const dayNumber = gameData.currentDay || 0;
  const currentGame = await gameRef.get();
  const current = currentGame.exists ? currentGame.data() : {};
  const phase = current.currentPhase || current.status;
  if (!currentGame.exists || phase !== "VOTING" || current.currentDay !== dayNumber) return false;
  const voteRound = current.voteRound || 1;
  // Every round that has already been decided is recorded on the game document.
  // Without this marker a re-vote re-opened its own first round forever, because
  // the same vote documents still match the new round.
  const resolvedRounds = new Set(Array.isArray(current.resolvedVoteRounds)
    ? current.resolvedVoteRounds
    : []);
  const roundKey = `${dayNumber}:${voteRound}`;
  if (resolvedRounds.has(roundKey)) return false;

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
    voteRound,
    tiedIds: current.revoteCandidates || [],
    dayNumber,
  });
  const eventsRef = gameRef.collection("events");

  if (plan.kind === "skip") {
    await database.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (!snap.exists || snap.data().currentPhase !== phase ||
          (snap.data().currentDay || 0) !== dayNumber) return;
      tx.update(gameRef, {
        status: "VOTE_RESULT",
        currentPhase: "VOTE_RESULT",
        revoteCandidates: admin.firestore.FieldValue.delete(),
        voteRound: admin.firestore.FieldValue.delete(),
        resolvedVoteRounds: admin.firestore.FieldValue.arrayUnion(roundKey),
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 6_000),
        serverEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 6_000),
      });
      tx.set(eventsRef.doc(`vote-${dayNumber}-${voteRound > 1 ? "revote-" : ""}resolved`), {
        type: "VoteResolved",
        message: plan.reason === "second_tie"
          ? "The re-vote was tied. Nobody is eliminated."
          : "Nobody voted. Nobody is eliminated.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { dayNumber, voteRound, tally: plan.tally },
      });
    });
    return true;
  }

  if (plan.kind === "revote") {
    await database.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (!snap.exists || snap.data().currentPhase !== phase ||
          (snap.data().currentDay || 0) !== dayNumber) return;
      tx.update(gameRef, {
        revoteCandidates: plan.tiedIds,
        voteRound: voteRound + 1,
        resolvedVoteRounds: admin.firestore.FieldValue.arrayUnion(roundKey),
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30_000),
        serverEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30_000),
      });
      tx.set(eventsRef.doc(`vote-${dayNumber}-tie`), {
        type: "VoteTie",
        message: "The vote tied. A re-vote is open between the tied players.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { dayNumber, voteRound, tiedIds: plan.tiedIds },
      });
    });
    return true;
  }

  // The execution used to run as a plain batch with no guard, so a retry after a
  // lease expiry could eliminate against a tally that was no longer current. It
  // now resolves inside a transaction that re-checks the phase, the day, and
  // whether this round was already executed.
  const executed = await database.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists) return false;
    const current = snap.data() || {};
    if ((current.currentPhase || current.status) !== phase) return false;
    if ((current.currentDay || 0) !== dayNumber) return false;
    if (Array.isArray(current.resolvedVoteRounds) &&
        current.resolvedVoteRounds.includes(roundKey)) return false;

    const targetRef = playersRef.doc(plan.targetId);
    const [targetSnap, privateSnap] = await Promise.all([
      tx.get(targetRef),
      tx.get(targetRef.collection("private").doc("data")),
    ]);
    if (!targetSnap.exists) return false;
    const target = targetSnap.data() || {};
    if (target.isAlive !== true || target.hasLeft === true) return false;
    const role = privateSnap.exists && privateSnap.data() && privateSnap.data().role
      ? privateSnap.data().role
      : "citizen";
    const roleLabel = ROLE_LABELS[role] || "a villager";
    const name = typeof target.username === "string" && target.username.trim()
      ? target.username.trim().slice(0, 80)
      : "A player";

    tx.update(targetRef, {
      isAlive: false,
      canVote: false,
      canSpeak: false,
      canUseAbility: false,
      revealedRole: true,
      eliminatedBy: "vote",
      canSayLastWords: true,
    });
    tx.set(eventsRef.doc(`vote-${dayNumber}-resolved`), {
      type: "PlayerExecuted",
      message: `The village eliminated ${name}. They were ${roleLabel}.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playerId: plan.targetId, role, dayNumber, voteRound },
    });
    tx.update(gameRef, {
      status: "VOTE_RESULT",
      currentPhase: "VOTE_RESULT",
      revoteCandidates: admin.firestore.FieldValue.delete(),
      voteRound: admin.firestore.FieldValue.delete(),
      resolvedVoteRounds: admin.firestore.FieldValue.arrayUnion(`${dayNumber}:${voteRound}`),
      phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 6_000),
      serverEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 6_000),
      votingResults: admin.firestore.FieldValue.arrayUnion({
        dayNumber,
        voteRound,
        tally: plan.tally,
        eliminatedPlayerId: plan.targetId,
        at: new Date(),
      }),
      eliminations: admin.firestore.FieldValue.arrayUnion({
        playerId: plan.targetId,
        cause: "vote",
        dayNumber,
        at: new Date(),
      }),
    });
    return true;
  });
  return executed;
}

module.exports = { resolveVotes, planVoteResolution, ROLE_LABELS };
