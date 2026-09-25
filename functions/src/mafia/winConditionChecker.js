"use strict";

const admin = require("firebase-admin");
const { distributeRewards } = require("./rewardDistributor");
const { createHistoryWriter } = require("./historyWriter");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

const db = admin.firestore();
const { writeHistory } = createHistoryWriter({ db });

function winnerFromAliveTeams(teams) {
  const list = Array.isArray(teams) ? teams : [];
  if (list.length === 0) return null;
  let mafiaCount = 0;
  let othersCount = 0;
  for (const team of list) {
    if (team === "mafias") mafiaCount += 1;
    else othersCount += 1;
  }
  if (mafiaCount === 0) return "citizens";
  if (mafiaCount >= othersCount) return "mafias";
  return null;
}

async function checkWinCondition(gameId, gameData, deps = {}) {
  const firestore = deps.db || db;
  const gameRef = firestore.collection("mafia_games").doc(gameId);

  if (["GAME_OVER", "CANCELLED"].includes(gameData.status)) {
    return;
  }

  const playersRef = gameRef.collection("players");
  const playersSnap = await playersRef.get();

  // Every player's private role is resolved once, up front. The alive subset
  // decides the winner; the whole map is what the final reveal publishes.
  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) => doc.ref.collection("private").doc("data").get()),
  );
  const rolesById = {};
  playersSnap.docs.forEach((doc, index) => {
    const data = privateSnaps[index].exists ? privateSnaps[index].data() : {};
    rolesById[doc.id] = {
      role: data.role || "citizen",
      team: data.team || "citizens",
    };
  });

  const alivePlayers = playersSnap.docs.filter(
    (doc) => doc.data().isAlive === true && doc.data().hasLeft !== true,
  );

  if (alivePlayers.length === 0) {
    return finishGame(gameId, gameRef, null, playersSnap, gameData.groupId, rolesById, deps);
  }

  const winner = winnerFromAliveTeams(
    alivePlayers.map((doc) => (rolesById[doc.id] || { team: "citizens" }).team),
  );
  if (!winner) return;

  return finishGame(gameId, gameRef, winner, playersSnap, gameData.groupId, rolesById, deps);
}

async function finishGame(gameId, gameRef, winner, playersSnap, groupId, rolesById = {}, deps = {}) {
  const firestore = deps.db || db;
  const write = deps.writeHistory || writeHistory;
  const pay = deps.distributeRewards || distributeRewards;
  const post = deps.postFromActivity || postFromActivity;
  const eventsRef = gameRef.collection("events");
  const claimed = await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists || ["GAME_OVER", "CANCELLED"].includes(snap.data().status)) return false;
    tx.update(gameRef, {
       status: "GAME_OVER",
       currentPhase: "GAME_OVER",
      winner,
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
      phaseEndsAt: admin.firestore.FieldValue.delete(),
      serverEndsAt: admin.firestore.FieldValue.delete(),
      phaseTransitionClaim: admin.firestore.FieldValue.delete(),
    });
    // Master Spec 13.10: the game ends by revealing every final role. The
    // reveal rides the same transaction that claims the win, so a client can
    // never observe a finished game whose roles are still private.
    for (const playerDoc of playersSnap.docs) {
      tx.update(playerDoc.ref, {
        revealedRole: true,
        role: (rolesById[playerDoc.id] || {}).role || "citizen",
      });
    }
    if (groupId) {
      const groupRef = firestore.collection("groups").doc(groupId);
      const group = await tx.get(groupRef);
      if (group.exists && group.data().activeGameId === gameId) {
        tx.update(groupRef, {
          activeGameId: admin.firestore.FieldValue.delete(),
          gameStatus: admin.firestore.FieldValue.delete(),
          hasRunningGame: false,
        });
      }
    }
    return true;
  });
  if (!claimed) return false;

  const message = winner === "mafias"
    ? "Mafia controls the village."
    : winner === "citizens"
      ? "Town eliminated every Mafia member."
      : "The game ended without a winner.";

  const revealedRoles = playersSnap.docs.map((doc) => ({
    playerId: doc.id,
    displayName: (doc.data() && doc.data().displayName) || null,
    role: (rolesById[doc.id] || {}).role || "citizen",
  }));

  await eventsRef.doc("game-finished").set({
    type: "GameFinished",
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { winner, revealedRoles },
  });

  try {
    await post(
      admin.firestore(),
      admin.firestore.FieldValue,
      toMafiaActivity(
        {
          type: winner === "mafias" ? "MafiaWon" : "TownWon",
          actorId: "system",
          payload: { winner },
        },
        { id: gameId, groupId, type: "mafia" },
      ),
    );
    await post(
      admin.firestore(),
      admin.firestore.FieldValue,
      toMafiaActivity(
        { type: "GameFinished", actorId: "system", payload: { winner, revealedRoles } },
        { id: gameId, groupId, type: "mafia" },
      ),
    );
  } catch (_) {
    // Result card is best-effort; history and rewards still proceed.
  }

  await write(gameId, gameRef, winner, playersSnap);

  if (winner) {
    await pay(gameId, gameRef, winner, playersSnap);
    try {
      await post(
        admin.firestore(),
        admin.firestore.FieldValue,
        toMafiaActivity(
          { type: "Rewards", actorId: "system", payload: { winner } },
          { id: gameId, groupId, type: "mafia" },
        ),
      );
    } catch (_) {
      // Rewards are authoritative; the chat projection is best effort.
    }
  }
  return true;
}

module.exports = { checkWinCondition, winnerFromAliveTeams };
