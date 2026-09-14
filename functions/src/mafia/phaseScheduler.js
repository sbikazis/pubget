"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { nextPhase, durationOf, PHASE_MESSAGES } = require("./phaseFlow");
const { resolveNight } = require("./nightResolver");
const { resolveVotes } = require("./voteResolver");
const { checkWinCondition } = require("./winConditionChecker");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

const db = admin.firestore();

const ACTIVE_LOOP_STATUSES = [
  "ROLE_REVEAL", "NIGHT", "DAY", "DISCUSSION", "VOTING", "RESOLUTION",
];
const CLAIM_LEASE_MS = 5 * 60 * 1000;

const processPhaseTransitions = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  const expiredGames = await db
    .collection("mafia_games")
    .where("status", "in", ACTIVE_LOOP_STATUSES)
    .where("phaseEndsAt", "<=", now)
    .get();

  for (const doc of expiredGames.docs) {
    await advancePhase(doc.id, doc.data());
  }

  const discussionGames = await db.collection("mafia_games")
    .where("status", "==", "DISCUSSION").get();
  for (const doc of discussionGames.docs) {
    const turnEndsAt = doc.data().turnEndsAt;
    if (turnEndsAt?.toMillis?.() <= Date.now()) {
      await advanceDiscussionTurn(doc.id);
    }
  }
});

async function advanceDiscussionTurn(gameId) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  await db.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRef);
    if (!gameSnap.exists) return;
    const game = gameSnap.data() || {};
    if (game.currentPhase !== "DISCUSSION") return;
    const players = await tx.get(gameRef.collection("players"));
    const eligible = new Set(players.docs
      .filter((doc) => doc.data().isAlive === true &&
        doc.data().hasLeft !== true && doc.data().isDisconnected !== true)
      .map((doc) => doc.id));
    const order = (game.speakingOrder || []).filter((id) => eligible.has(id));
    const currentIndex = order.indexOf(game.currentSpeakerId);
    const nextSpeakerId = currentIndex >= 0 ? order[currentIndex + 1] : order[0];
    if (nextSpeakerId && nextSpeakerId !== game.currentSpeakerId) {
      tx.update(gameRef, {
        currentSpeakerId: nextSpeakerId,
        turnStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        turnEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 20_000),
      });
    } else {
      tx.update(gameRef, {
        status: "VOTING",
        currentPhase: "VOTING",
        currentSpeakerId: null,
        voteRound: 1,
        revoteCandidates: null,
        phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 45_000),
        serverStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        serverEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 45_000),
      });
    }
  });
}

async function advancePhase(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const current = gameData.currentPhase || gameData.status;
  const claimId = `${process.pid || "scheduler"}:${Date.now()}:${gameId}`;
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    const data = snap.data();
    const claimedBy = data && data.phaseTransitionClaim;
    const expiresAt = claimedBy && claimedBy.expiresAt;
    const leaseExpired = !expiresAt || typeof expiresAt.toMillis !== "function" ||
      expiresAt.toMillis() <= Date.now();
    if (!snap.exists || !data || (data.currentPhase || data.status) !== current ||
        (!data.phaseEndsAt || typeof data.phaseEndsAt.toMillis !== "function" ||
        data.phaseEndsAt.toMillis() > Date.now()) || (claimedBy && !leaseExpired) ||
        ["GAME_OVER", "CANCELLED"].includes(data.status)) return false;
    tx.update(gameRef, {
      phaseTransitionClaim: {
        owner: claimId,
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + CLAIM_LEASE_MS),
      },
    });
    return true;
  });
  if (!claimed) return;

  try {
    if (current === "NIGHT") {
      await resolveNight(gameId, gameData);
      await checkWinCondition(gameId, (await gameRef.get()).data());
    }

    if (current === "VOTING") {
      await resolveVotes(gameId, gameData);
      await checkWinCondition(gameId, (await gameRef.get()).data());
    }

    const freshSnap = await gameRef.get();
    const freshData = freshSnap.data();
    if (["GAME_OVER", "CANCELLED"].includes(freshData.status)) {
      await releaseClaim(gameRef, claimId);
      return;
    }

    const afterResolution = await gameRef.get();
    const afterData = afterResolution.data() || {};
    // If resolveVotes set revoteCandidates (tie → re-vote), stay in VOTING.
    if (afterData.currentPhase === "VOTING" &&
        Array.isArray(afterData.revoteCandidates) &&
        afterData.revoteCandidates.length > 0) {
      await releaseClaim(gameRef, claimId);
      return;
    }

    let next = nextPhase(current);
    const durationSeconds = durationOf(next);
    const endsAtMs = Date.now() + durationSeconds * 1000;
    const phaseEndsAt = admin.firestore.Timestamp.fromMillis(endsAtMs);

    const updateData = {
      status: next,
      currentPhase: next,
      phaseEndsAt,
      phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      serverStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      serverEndsAt: phaseEndsAt,
      phaseHistory: admin.firestore.FieldValue.arrayUnion({
        from: current,
        to: next,
        at: new Date(),
      }),
      phaseTransitionClaim: admin.firestore.FieldValue.delete(),
    };

    if (next === "NIGHT") {
      updateData.currentNight = admin.firestore.FieldValue.increment(1);
      updateData.voteRound = admin.firestore.FieldValue.delete();
      updateData.revoteCandidates = admin.firestore.FieldValue.delete();
    } else if (next === "DAY") {
      updateData.currentDay = admin.firestore.FieldValue.increment(1);
    }
    if (next === "DISCUSSION") {
      const alive = (await gameRef.collection("players").get()).docs
        .filter((doc) => doc.data().isAlive === true && doc.data().hasLeft !== true)
        .map((doc) => doc.id);
      updateData.speakingOrder = alive;
      updateData.currentSpeakerId = alive[0] || null;
      updateData.turnStartedAt = admin.firestore.FieldValue.serverTimestamp();
      updateData.turnEndsAt = admin.firestore.Timestamp.fromMillis(Date.now() + 20_000);
    }
    if (next === "VOTING") {
      updateData.voteRound = 1;
      updateData.revoteCandidates = admin.firestore.FieldValue.delete();
    }

    const ownership = await gameRef.get();
    if (!ownership.exists || ownership.data().phaseTransitionClaim?.owner !== claimId) return;
    const batch = db.batch();
    batch.update(gameRef, updateData);
    batch.set(gameRef.collection("events").doc(`phase-${current}-${gameData.currentNight || gameData.currentDay || 0}`), {
      type: "PhaseChanged",
      message: PHASE_MESSAGES[next] || `The game moved to ${next}.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { from: current, to: next },
    });

    // Reset canSpeak for all alive non-left players on night start.
    if (next === "NIGHT") {
      const playersSnap = await gameRef.collection("players").get();
      playersSnap.docs.forEach((doc) => {
        const player = doc.data();
        if (player.isAlive === true && player.hasLeft !== true && player.canSpeak === false) {
          batch.update(doc.ref, { canSpeak: true });
        }
      });
    }

    await batch.commit();
    const chatEventType = next === "NIGHT"
      ? "NightStarted"
      : next === "DAY"
        ? "DayStarted"
        : null;
    if (chatEventType && freshData.groupId) {
      try {
        await postFromActivity(
          db,
          admin.firestore.FieldValue,
          toMafiaActivity(
            { type: chatEventType, actorId: "system", payload: { phase: next } },
            { id: gameId, groupId: freshData.groupId, type: "mafia" },
          ),
        );
      } catch (_) {
        // Chat cards are projections and never block the game state machine.
      }
    }
  } catch (error) {
    // Permit the scheduled retry only if this invocation still owns the claim.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (snap.exists && snap.data().phaseTransitionClaim?.owner === claimId) {
        tx.update(gameRef, { phaseTransitionClaim: admin.firestore.FieldValue.delete() });
      }
    });
    throw error;
  }
}

async function releaseClaim(gameRef, owner) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (snap.exists && snap.data().phaseTransitionClaim?.owner === owner) {
      tx.update(gameRef, { phaseTransitionClaim: admin.firestore.FieldValue.delete() });
    }
  });
}

module.exports = { processPhaseTransitions, advancePhase, advanceDiscussionTurn };
