// Authoritative leave handling for games once the waiting lobby is locked.
const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { checkWinCondition } = require("./winConditionChecker");
const { leaveTransition, validGameId } = require("./leaveTransition");

async function leaveMafiaGame(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const suppliedGameId = request.data && request.data.gameId;
  if (!validGameId(suppliedGameId)) {
    throw new HttpsError(
      "invalid-argument",
      "gameId must be a non-empty string of at most 128 characters.",
    );
  }

  const gameId = suppliedGameId.trim();
  const uid = request.auth.uid;
  const db = admin.firestore();
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playerRef = gameRef.collection("players").doc(uid);
  let outcome;

  await db.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRef);
    if (!gameSnap.exists) {
      outcome = "missing";
      return;
    }
    const game = gameSnap.data() || {};
    const playerSnap = await tx.get(playerRef);
    const transition = leaveTransition(
      game.status,
      playerSnap.exists ? playerSnap.data() : null,
      game.playersCount,
      game.minPlayers,
    );
    if (transition.kind === "already-left") {
      outcome = playerSnap.exists ? "already-left" : "missing-player";
      return;
    }
    if (transition.kind === "unsupported") {
      throw new HttpsError("failed-precondition", "This game can no longer be left.");
    }

    const playerUpdate = {
      hasLeft: true,
      isAlive: false,
      canVote: false,
      canSpeak: false,
      canUseAbility: false,
      isDisconnected: true,
      leftAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    tx.update(playerRef, playerUpdate);

    if (transition.kind === "active-left") {
      const currentCount = Number.isInteger(game.playersCount) ? game.playersCount : 0;
      tx.update(gameRef, { playersCount: Math.max(0, currentCount - 1) });
      outcome = "left-active";
      return;
    }

    if (transition.kind === "starting-left") {
      tx.update(gameRef, { playersCount: transition.nextCount });
      outcome = "left-starting";
      return;
    }

    // Match the existing starting-game cancellation behavior and clear a
    // marker only if it still identifies this exact game.
    tx.update(gameRef, {
      playersCount: transition.nextCount,
      status: "cancelled",
      currentPhase: "cancelled",
      roleAssignmentClaim: admin.firestore.FieldValue.delete(),
    });
    if (typeof game.groupId === "string" && game.groupId) {
      const groupRef = db.collection("groups").doc(game.groupId);
      const groupSnap = await tx.get(groupRef);
      if (groupSnap.exists && groupSnap.data().activeGameId === gameId) {
        tx.update(groupRef, {
          activeGameId: admin.firestore.FieldValue.delete(),
          gameStatus: admin.firestore.FieldValue.delete(),
          hasRunningGame: false,
        });
      }
    }
    outcome = "cancelled-starting";
  });

  // Re-read after the leave transaction. This prevents a stale pre-leave
  // snapshot from delaying resolution after a team balance changes.
  if (outcome === "left-active") {
    const freshGame = await gameRef.get();
    if (freshGame.exists) {
      await checkWinCondition(gameId, freshGame.data());
    }
  }
  return { ok: true, outcome };
}

module.exports = { leaveMafiaGame, leaveTransition, validGameId };