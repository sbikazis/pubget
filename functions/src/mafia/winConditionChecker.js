"use strict";

const admin = require("firebase-admin");
const { distributeRewards } = require("./rewardDistributor");
const { writeHistory } = require("./historyWriter");

const db = admin.firestore();

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

async function checkWinCondition(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);

  if (gameData.status === "finished" || gameData.status === "cancelled") {
    return;
  }

  const playersRef = gameRef.collection("players");
  const playersSnap = await playersRef.get();

  const alivePlayers = playersSnap.docs.filter(
    (doc) => doc.data().isAlive === true && doc.data().hasLeft !== true,
  );

  if (alivePlayers.length === 0) {
    await finishGame(gameId, gameRef, null, playersSnap, gameData.groupId);
    return;
  }

  const privateSnaps = await Promise.all(
    alivePlayers.map((doc) => doc.ref.collection("private").doc("data").get()),
  );
  const winner = winnerFromAliveTeams(
    privateSnaps.map((snap) => (snap.exists ? snap.data().team : "citizens")),
  );
  if (!winner) return;

  await finishGame(gameId, gameRef, winner, playersSnap, gameData.groupId);
}

async function finishGame(gameId, gameRef, winner, playersSnap, groupId) {
  const eventsRef = gameRef.collection("events");
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists || ["finished", "cancelled"].includes(snap.data().status)) return false;
    tx.update(gameRef, {
      status: "finished",
      currentPhase: "finished",
      winner,
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
      phaseEndsAt: admin.firestore.FieldValue.delete(),
      phaseTransitionClaim: admin.firestore.FieldValue.delete(),
    });
    if (groupId) {
      const groupRef = db.collection("groups").doc(groupId);
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

  await eventsRef.doc("game-finished").set({
    type: "GameFinished",
    message,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { winner },
  });

  await writeHistory(gameId, gameRef, winner, playersSnap);

  if (winner) {
    await distributeRewards(gameId, gameRef, winner, playersSnap);
  }
  return true;
}

module.exports = { checkWinCondition, winnerFromAliveTeams };
