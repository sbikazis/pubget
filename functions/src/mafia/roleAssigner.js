"use strict";

const admin = require("firebase-admin");
const { ALL_ABILITIES } = require("./abilities");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

const db = admin.firestore();

const FIRST_NIGHT_DURATION_SECONDS = 8;
// Master Spec 13.2: a Mafia game holds 7-15 players. Start is refused below
// the minimum, and joining is closed for good once the game starts.
const MIN_PLAYERS = 7;
const MAX_PLAYERS = 15;

async function cancelInvalidStartingGame(gameId, owner) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  return db.runTransaction(async (tx) => {
    const game = await tx.get(gameRef);
    if (!game.exists || game.data().status !== "STARTING" ||
        game.data().roleAssignmentClaim?.owner !== owner) return false;

    tx.update(gameRef, {
      status: "CANCELLED",
      currentPhase: "CANCELLED",
      roleAssignmentClaim: admin.firestore.FieldValue.delete(),
    });
    const groupId = game.data().groupId;
    if (typeof groupId === "string" && groupId) {
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
}

// Master Spec 13.3 fixes the registry and demands a deterministic, server-side
// distribution per player count with no re-distribution after the start. It does
// not tabulate counts per size, so this is the minimal allocation consistent with
// the spec's own rules:
//
//   - every one of the five closed roles is always present;
//   - the Don, Detective and Doctor are single-slot roles;
//   - the rest split evenly between Mafia and Citizen, so the town always holds
//     at least as many players as the mafia team, which is what makes the
//     "mafia alive >= town alive" win condition reachable rather than decided at
//     the start.
//
// The result is a pure function of the count, so two servers assign identically.
function computeRoleDistribution(playersCount) {
  if (!Number.isInteger(playersCount) || playersCount < MIN_PLAYERS ||
      playersCount > MAX_PLAYERS) return [];
  const roles = ["don", "detective", "doctor"];
  let remaining = playersCount - roles.length;
  const mafiaCount = Math.max(1, Math.floor(remaining / 2));
  remaining -= mafiaCount;
  for (let index = 0; index < mafiaCount; index += 1) roles.push("mafia");
  while (remaining > 0) {
    roles.push("citizen");
    remaining -= 1;
  }
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
  const assignment = await db.runTransaction(async (tx) => {
    const current = await tx.get(gameRef);
    if (!current.exists || current.data().status !== "STARTING" ||
        current.data().rolesAssigned === true ||
        current.data().roleAssignmentClaim?.owner !== gameData.roleAssignmentOwner ||
        typeof current.data().roleAssignmentClaim?.expiresAt?.toMillis !== "function" ||
        current.data().roleAssignmentClaim.expiresAt.toMillis() <= Date.now()) {
      return { assigned: false, invalid: false };
    }
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
      status: "ROLE_REVEAL", currentPhase: "ROLE_REVEAL", currentNight: 0,
      rolesAssigned: true, countdownEndsAt: admin.firestore.FieldValue.delete(),
      phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(), phaseEndsAt,
      serverStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      serverEndsAt: phaseEndsAt,
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
