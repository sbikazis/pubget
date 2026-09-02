// functions/src/mafia/roleAssigner.js
//
// ✅ التعديل الجوهري: الأدوار تُكتب الآن على الوثيقة الخاصة
// (players/{id}/private/data) بدل وثيقة اللاعب العامة مباشرة.
// الوثيقة الخاصة موجودة أصلاً من لحظة الانضمام (بقيمة citizen)،
// لذلك هذا تحديث (update) وليس إنشاء.

const admin = require("firebase-admin");
const { ALL_ABILITIES } = require("./abilities");

const db = admin.firestore();

const FIRST_NIGHT_DURATION_SECONDS = 60;
const MAX_PLAYERS = 50;

async function cancelInvalidStartingGame(gameId, owner) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  return db.runTransaction(async (tx) => {
    const game = await tx.get(gameRef);
    if (!game.exists || game.data().status !== "starting" ||
        game.data().roleAssignmentClaim?.owner !== owner) return false;

    tx.update(gameRef, {
      status: "cancelled",
      currentPhase: "cancelled",
      roleAssignmentClaim: admin.firestore.FieldValue.delete(),
    });
    const groupId = game.data().groupId;
    if (typeof groupId === "string" && groupId) {
      const groupRef = db.collection("groups").doc(groupId);
      const group = await tx.get(groupRef);
      // Never clear a newer game's marker when a stale starting game is
      // eventually cleaned up.
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
}

function computeRoleDistribution(playersCount, version) {
  const distribution = [];

  if (version === "advanced") {
    distribution.push("mafia", "mafia");
    if (playersCount >= 6) distribution.push("doctor");
    if (playersCount >= 7) distribution.push("detective");
    if (playersCount >= 9) distribution.push("sniper");
    if (playersCount >= 10) distribution.push("silencer");
  } else if (playersCount <= 4) {
    // 4 players cannot support two Mafia without starting at parity.
    distribution.push("mafia");
    if (playersCount >= 4) distribution.push("doctor", "detective");
  } else {
    distribution.push("mafia", "mafia");
    if (playersCount >= 5) distribution.push("doctor");
    if (playersCount >= 6) distribution.push("detective");
  }

  while (distribution.length < playersCount) {
    distribution.push("citizen");
  }

  return distribution.slice(0, playersCount);
}

function shuffle(array) {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

async function assignRoles(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");

  const playersSnap = await playersRef.get();
  const activePlayers = playersSnap.docs.filter(
    (doc) => doc.data().hasLeft !== true
  );

  const minPlayers = gameData.minPlayers;
  const maxPlayers = gameData.maxPlayers;
  if (!Number.isInteger(minPlayers) || !Number.isInteger(maxPlayers) ||
      minPlayers < 2 || minPlayers > maxPlayers || maxPlayers > MAX_PLAYERS ||
      activePlayers.length < minPlayers || activePlayers.length > maxPlayers ||
      gameData.playersCount !== activePlayers.length) {
    await cancelInvalidStartingGame(gameId, gameData.roleAssignmentOwner);
    return false;
  }

  const distribution = shuffle(
    computeRoleDistribution(activePlayers.length, gameData.version || "classic")
  );

  const phaseEndsAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + FIRST_NIGHT_DURATION_SECONDS * 1000
  );
  // A transaction claims the starting lobby exactly once.  The private
  // documents are created with merge because older lobbies may not have
  // pre-created them; no client supplied role is ever trusted.
  const assignment = await db.runTransaction(async (tx) => {
    const current = await tx.get(gameRef);
    if (!current.exists || current.data().status !== "starting" ||
        current.data().rolesAssigned === true ||
        current.data().roleAssignmentClaim?.owner !== gameData.roleAssignmentOwner ||
        typeof current.data().roleAssignmentClaim?.expiresAt?.toMillis !== "function" ||
        current.data().roleAssignmentClaim.expiresAt.toMillis() <= Date.now()) {
      return { assigned: false, invalid: false };
    }
    // Read the player documents in the transaction so a join/leave concurrent
    // with assignment retries the transaction instead of assigning stale data.
    const currentPlayers = await tx.get(playersRef);
    const currentActive = currentPlayers.docs.filter((snap) => snap.data().hasLeft !== true);
    const currentMin = current.data().minPlayers;
    const currentMax = current.data().maxPlayers;
    if (!Number.isInteger(currentMin) || !Number.isInteger(currentMax) ||
        currentMin < 2 || currentMin > currentMax || currentMax > MAX_PLAYERS ||
        currentActive.length < currentMin || currentActive.length > currentMax ||
        current.data().playersCount !== currentActive.length ||
        currentActive.length !== activePlayers.length ||
        currentActive.some((snap) => !activePlayers.some((player) => player.id === snap.id))) {
      return { assigned: false, invalid: true };
    }
    activePlayers.forEach((playerDoc, index) => {
      const ability = ALL_ABILITIES[distribution[index]];
      tx.set(playerDoc.ref.collection("private").doc("data"), {
        role: distribution[index], team: ability ? ability.team : "citizens",
      }, { merge: true });
    });
    tx.update(gameRef, {
      status: "night", currentPhase: "night", currentNight: 1,
      rolesAssigned: true, countdownEndsAt: admin.firestore.FieldValue.delete(), phaseEndsAt,
      roleAssignmentClaim: admin.firestore.FieldValue.delete(),
    });
    tx.set(gameRef.collection("events").doc("roles-assigned"), {
      type: "RolesAssigned", message: "تم توزيع الأدوار، وبدأت الليلة الأولى في المافيا...",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playersCount: activePlayers.length, version: gameData.version || "classic" },
    });
    return { assigned: true, invalid: false };
  });
  if (assignment.invalid) {
    await cancelInvalidStartingGame(gameId, gameData.roleAssignmentOwner);
  }
  return assignment.assigned;
}

module.exports = { assignRoles, computeRoleDistribution, cancelInvalidStartingGame };