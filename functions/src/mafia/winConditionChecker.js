// functions/src/mafia/winConditionChecker.js
//
// ✅ الإصلاح الحرج: finishGame الآن يصفّر hasRunningGame/activeGameId
// على مستند المجموعة عند انتهاء المباراة بفوز طبيعي، تماماً كما
// يفعل cancelLobby.js عند الإلغاء. بدون هذا، أي مجموعة تلعب مباراة
// واحدة تُقفل نهائياً من لعب أي مباراة مافيا أخرى.

const admin = require("firebase-admin");
const { distributeRewards } = require("./rewardDistributor");
const { writeHistory } = require("./historyWriter");

const db = admin.firestore();

async function checkWinCondition(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);

  if (gameData.status === "finished" || gameData.status === "cancelled") {
    return;
  }

  const playersRef = gameRef.collection("players");
  const playersSnap = await playersRef.get();

  const alivePlayers = playersSnap.docs.filter(
    (doc) => doc.data().isAlive === true && doc.data().hasLeft !== true
  );

  if (alivePlayers.length === 0) {
    await finishGame(gameId, gameRef, null, playersSnap, gameData.groupId);
    return;
  }

  const privateSnaps = await Promise.all(
    alivePlayers.map((doc) => doc.ref.collection("private").doc("data").get())
  );

  let mafiaCount = 0;
  let othersCount = 0;

  privateSnaps.forEach((snap) => {
    const team = snap.exists ? snap.data().team : "citizens";
    if (team === "mafias") {
      mafiaCount += 1;
    } else {
      othersCount += 1;
    }
  });

  let winner = null;
  if (mafiaCount === 0) {
    winner = "citizens";
  } else if (mafiaCount >= othersCount) {
    winner = "mafias";
  }

  if (!winner) return;

  await finishGame(gameId, gameRef, winner, playersSnap, gameData.groupId);
}

async function finishGame(gameId, gameRef, winner, playersSnap, groupId) {
  const eventsRef = gameRef.collection("events");
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists || ["finished", "cancelled"].includes(snap.data().status)) return false;
    tx.update(gameRef, {
      status: "finished", currentPhase: "finished", winner,
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

  // ✅ الإصلاح الحرج: تحرير المجموعة فوراً لتصبح قادرة على استضافة
  // مباراة مافيا جديدة. بدون هذا السطر، المجموعة تبقى "مقفلة" للأبد.
  const message = winner === "mafias"
    ? "🔪 تمكنت المافيا من السيطرة الكاملة على القرية... المافيا تفوز!"
    : winner === "citizens"
      ? "🎉 نجحت القرية في القضاء على كل أفراد المافيا... القرية تفوز!"
      : "🌫️ انتهت المباراة دون فائز واضح.";

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

module.exports = { checkWinCondition };