"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { canonicalPhase, durationOf, PHASE_MESSAGES } = require("./phaseFlow");
const { resolveNight } = require("./nightResolver");
const { resolveVotes } = require("./voteResolver");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();
const ACTIVE_PHASES = [
  "ROLE_REVEAL", "NIGHT", "DAY", "DISCUSSION", "VOTING",
  "VOTE_RESULT", "RESOLUTION",
];
const CLAIM_LEASE_MS = 5 * 60 * 1000;

const processPhaseTransitions = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const expiredGames = await db.collection("mafia_games")
    .where("currentPhase", "in", ACTIVE_PHASES)
    .where("phaseEndsAt", "<=", now)
    .get();
  for (const doc of expiredGames.docs) await advancePhase(doc.id, doc.data());
});

async function advancePhase(gameId, snapshotData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const phase = canonicalPhase(snapshotData.currentPhase || snapshotData.status);
  const claimId = `${process.pid || "scheduler"}:${Date.now()}:${gameId}`;
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists) return false;
    const game = snap.data() || {};
    const current = canonicalPhase(game.currentPhase || game.status);
    const claim = game.phaseTransitionClaim;
    const claimExpired = !claim?.expiresAt ||
      typeof claim.expiresAt.toMillis !== "function" ||
      claim.expiresAt.toMillis() <= Date.now();
    if (current !== phase || !ACTIVE_PHASES.includes(current) ||
        !game.phaseEndsAt || game.phaseEndsAt.toMillis() > Date.now() ||
        (claim && !claimExpired) || game.resultLocked === true) return false;
    tx.update(gameRef, {
      phaseTransitionClaim: {
        owner: claimId,
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + CLAIM_LEASE_MS),
      },
    });
    return true;
  });
  if (!claimed) return false;

  try {
    if (phase === "NIGHT") {
      await resolveNight(gameId, snapshotData);
      await checkWinCondition(gameId, (await gameRef.get()).data());
    } else if (phase === "VOTING") {
      await resolveVotes(gameId, snapshotData);
    } else if (phase === "RESOLUTION") {
      await checkWinCondition(gameId, (await gameRef.get()).data());
    }

    const freshSnap = await gameRef.get();
    const fresh = freshSnap.data() || {};
    const freshPhase = canonicalPhase(fresh.currentPhase || fresh.status);
    if (["GAME_OVER", "CANCELLED"].includes(freshPhase) || fresh.resultLocked === true) {
      await releaseClaim(gameRef, claimId);
      return true;
    }

    let next;
    if (phase === "ROLE_REVEAL") next = "NIGHT";
    else if (phase === "NIGHT") next = "DAY";
    else if (phase === "DAY") next = "DISCUSSION";
    else if (phase === "DISCUSSION") next = "VOTING";
    else if (phase === "VOTING") next = "VOTE_RESULT";
    else if (phase === "VOTE_RESULT") {
      next = fresh.revotePending === true ? "VOTING" : "RESOLUTION";
    } else if (phase === "RESOLUTION") next = "NIGHT";
    else next = "NIGHT";

    const now = Date.now();
    const update = {
      status: next,
      currentPhase: next,
      phaseStartedAt: admin.firestore.Timestamp.fromMillis(now),
      phaseEndsAt: admin.firestore.Timestamp.fromMillis(
        now + durationOf(next) * 1000,
      ),
      phaseTransitionClaim: admin.firestore.FieldValue.delete(),
      stateVersion: admin.firestore.FieldValue.increment(1),
    };
    if (next === "NIGHT") {
      update.currentNight = admin.firestore.FieldValue.increment(1);
      update.revoteCount = 0;
      update.revotePending = false;
    }
    if (next === "DAY") update.currentDay = admin.firestore.FieldValue.increment(1);
    if (next === "VOTING" && fresh.revotePending === true) {
      update.revotePending = false;
    }
    const batch = db.batch();
    batch.update(gameRef, update);
    batch.set(gameRef.collection("events").doc(
      `phase-${next.toLowerCase()}-${fresh.stateVersion || 0}`,
    ), {
      type: "PhaseChanged",
      message: PHASE_MESSAGES[next] || `The game moved to ${next}.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { from: phase, to: next },
    });
    if (next === "NIGHT") {
      const playersSnap = await gameRef.collection("players").get();
      for (const doc of playersSnap.docs) {
        const player = doc.data();
        if (player.isAlive === true && player.hasLeft !== true) {
          batch.update(doc.ref, { canSpeak: true, canUseAbility: true });
        }
      }
    }
    await batch.commit();
    return true;
  } catch (error) {
    await releaseClaim(gameRef, claimId);
    throw error;
  }
}

async function releaseClaim(gameRef, owner) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (snap.exists && snap.data().phaseTransitionClaim?.owner === owner) {
      tx.update(gameRef, {
        phaseTransitionClaim: admin.firestore.FieldValue.delete(),
      });
    }
  });
}

module.exports = { processPhaseTransitions, advancePhase };