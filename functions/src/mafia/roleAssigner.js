// functions/src/mafia/roleAssigner.js
//
// ✅ التعديل الجوهري: الأدوار تُكتب الآن على الوثيقة الخاصة
// (players/{id}/private/data) بدل وثيقة اللاعب العامة مباشرة.
// الوثيقة الخاصة موجودة أصلاً من لحظة الانضمام (بقيمة citizen)،
// لذلك هذا تحديث (update) وليس إنشاء.

const admin = require("firebase-admin");
const { ALL_ABILITIES } = require("./abilities");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

const db = admin.firestore();

const FIRST_NIGHT_DURATION_SECONDS = 8;
const MIN_PLAYERS = 4;
const MAX_PLAYERS = 8;

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

function computeRoleDistribution(playersCount) {
  if (!Number.isInteger(playersCount) || playersCount < MIN_PLAYERS ||
      playersCount > MAX_PLAYERS) return [];
  // Pubget's existing Mafia contract is 4–8 players. Don replaces the
  // second Mafia slot and both belong to the same hidden team.
  const roles = playersCount === 4
    ? ["mafia", "doctor", "detective", "citizen"]
    : ["don", "mafia", "doctor", "detective"];
  while (roles.length < playersCount) roles.push("citizen");
  return roles;
}

function deterministicOrder(docs, seed) {
  const score = (id) => {
    let value = 2166136261;
    for (const char of `${seed}:${id}`) {
      value ^= char.charCodeAt(0);
      value = Math.imul(value, 16777619);
    }
    return value >>> 0;
  };
  return [...docs].sort(
    (a, b) => score(a.id) - score(b.id) || a.id.localeCompare(b.id),
  );
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
       minPlayers < MIN_PLAYERS || minPlayers > maxPlayers || maxPlayers > MAX_PLAYERS ||
      activePlayers.length < minPlayers || activePlayers.length > maxPlayers ||
      gameData.playersCount !== activePlayers.length) {
    await cancelInvalidStartingGame(gameId, gameData.roleAssignmentOwner);
    return false;
  }

    const orderedPlayers = deterministicOrder(activePlayers, gameId);
    const distribution = computeRoleDistribution(orderedPlayers.length);
    if (distribution.length !== orderedPlayers.length) {
      await cancelInvalidStartingGame(gameId, gameData.roleAssignmentOwner);
      return false;
    }

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
       currentMin < MIN_PLAYERS || currentMin > currentMax || currentMax > MAX_PLAYERS ||
        currentActive.length < currentMin || currentActive.length > currentMax ||
        current.data().playersCount !== currentActive.length ||
        currentActive.length !== activePlayers.length ||
        currentActive.some((snap) => !activePlayers.some((player) => player.id === snap.id))) {
      return { assigned: false, invalid: true };
    }
    orderedPlayers.forEach((playerDoc, index) => {
      const ability = ALL_ABILITIES[distribution[index]];
      tx.set(playerDoc.ref.collection("private").doc("data"), {
        role: distribution[index],
        team: ability ? ability.team : "citizens",
        assigned: true,
        mafiaTeammateIds: orderedPlayers
          .filter((other, otherIndex) =>
            ["mafia", "don"].includes(distribution[otherIndex]) &&
            ["mafia", "don"].includes(distribution[index]) &&
            other.id !== playerDoc.id)
          .map((other) => other.id),
      }, { merge: true });
      tx.update(playerDoc.ref, { revealedRole: false });
    });
    tx.update(gameRef, {
      status: "role_reveal", currentPhase: "role_reveal", currentNight: 0,
      rolesAssigned: true, countdownEndsAt: admin.firestore.FieldValue.delete(),
      phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(), phaseEndsAt,
      roleAssignmentClaim: admin.firestore.FieldValue.delete(),
    });
    tx.set(gameRef.collection("events").doc("roles-assigned"), {
      type: "RolesAssigned", message: "Roles have been assigned privately.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playersCount: orderedPlayers.length, version: "classic" },
    });
    return { assigned: true, invalid: false };
  });
  if (assignment.invalid) {
    await cancelInvalidStartingGame(gameId, gameData.roleAssignmentOwner);
  }
  if (assignment.assigned) {
    try {
      await postFromActivity(
        db,
        admin.firestore.FieldValue,
        toMafiaActivity(
          { type: "MafiaStarted", actorId: "system", payload: {} },
          { id: gameId, groupId: gameData.groupId, type: "mafia" },
        ),
      );
    } catch (_) {
      // Chat is a projection; never block role assignment.
    }
  }
  return assignment.assigned;
}

module.exports = { assignRoles, computeRoleDistribution, cancelInvalidStartingGame };