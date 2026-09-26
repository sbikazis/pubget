"use strict";

const admin = require("firebase-admin");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");
const { roleLabel } = require("./roleLabels");

const db = admin.firestore();

function pickMajorityTarget(mafiaActions) {
  if (!mafiaActions || mafiaActions.length === 0) return null;
  const counts = {};
  mafiaActions.forEach((action) => {
    if (!action.targetId) return;
    counts[action.targetId] = (counts[action.targetId] || 0) + 1;
  });

  let bestTarget = null;
  let bestCount = 0;
  let ties = 0;
  for (const [targetId, count] of Object.entries(counts)) {
    if (count > bestCount) {
      bestCount = count;
      bestTarget = targetId;
      ties = 1;
    } else if (count === bestCount) {
      ties += 1;
    }
  }
  if (ties > 1) return null;
  return bestTarget;
}

function planNightResolution({ playersById, actions, nightNumber }) {
  const actionsByRole = { mafia: [], don: [], doctor: [], detective: [] };
  const actionTaken = new Set();
  for (const action of actions || []) {
    if (!action || typeof action !== "object" ||
        typeof action.playerId !== "string" || typeof action.targetId !== "string" ||
        !Number.isInteger(action.nightNumber) || action.nightNumber !== nightNumber) {
      continue;
    }
    const actualPlayer = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!actualPlayer || !target || !actionsByRole[actualPlayer.role] ||
        actualPlayer.isAlive !== true || actualPlayer.hasLeft === true ||
        actualPlayer.canUseAbility === false || target.isAlive !== true ||
        target.hasLeft === true) {
      continue;
    }
    const key = `${actualPlayer.role}:${action.playerId}`;
    if (actionTaken.has(key)) continue;
    actionTaken.add(key);
    actionsByRole[actualPlayer.role].push(action);
  }

  const validMafiaActions = [
    ...actionsByRole.mafia,
    ...actionsByRole.don,
  ].filter((action) => {
    const target = playersById[action.targetId];
    return target && target.team !== "mafias" && action.targetId !== action.playerId;
  });
  const mafiaTargetId = pickMajorityTarget(validMafiaActions);
  const doctorAction = actionsByRole.doctor[0];
  const doctorTargetId = doctorAction ? doctorAction.targetId : null;
  const doctorTargetWasRepeated = Boolean(
    doctorAction && playersById[doctorAction.playerId]?.lastDoctorTargetId &&
    playersById[doctorAction.playerId].lastDoctorTargetId === doctorTargetId,
  );
  const savedIds = [];
  const killedIds = [];
  if (mafiaTargetId) {
    if (mafiaTargetId === doctorTargetId && !doctorTargetWasRepeated) {
      savedIds.push(mafiaTargetId);
    }
    else killedIds.push(mafiaTargetId);
  }

  const investigations = [];
  for (const action of actionsByRole.detective) {
    const detective = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!detective || !target) continue;
    investigations.push({
      detectiveId: action.playerId,
      targetId: action.targetId,
      result: target.team === "mafias" ? "Mafia" : "Not Mafia",
    });
  }
  const donInvestigations = [];
  for (const action of actionsByRole.don) {
    const target = playersById[action.targetId];
    if (!target) continue;
    donInvestigations.push({
      donId: action.playerId,
      targetId: action.targetId,
      result: target.role === "detective" ? "Detective" : "Not Detective",
    });
  }

  return {
    mafiaTargetId,
    doctorTargetId,
    doctorPlayerId: doctorAction ? doctorAction.playerId : null,
    killedIds: [...new Set(killedIds)],
    savedIds,
    investigations,
    donInvestigations,
    doctorTargetWasRepeated,
  };
}

// A night may only be resolved once. `resolvedNights` on the game document is
// the guard: it is read and written inside the same transaction that applies the
// kills, so a scheduler retry, a lease expiry, or a duplicate invocation can
// never resolve the same night twice.
async function resolveNight(gameId, gameData, deps = {}) {
  const database = deps.db || db;
  const postCard = deps.postFromActivity || postFromActivity;
  const gameRef = database.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const requestedNight = gameData.currentNight || 0;
  let resolvedKilledIds = [];

  // A Firestore transaction may only read documents, never a collection query,
  // so the roster and the night's actions are discovered here and re-read by
  // reference inside the transaction. Only the *set* of documents is taken from
  // these reads; every value the decision depends on is read transactionally,
  // and the game document is re-validated before anything is written.
  const [roster, actionList] = await Promise.all([
    playersRef.get(),
    gameRef.collection("night_actions").where("nightNumber", "==", requestedNight).get(),
  ]);
  const playerRefs = roster.docs.map((doc) => doc.ref);
  const actionRefs = actionList.docs.map((doc) => doc.ref);

  const resolved = await database.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRef);
    if (!gameSnap.exists) return false;
    const game = gameSnap.data() || {};
    if (game.status !== "NIGHT" || (game.currentPhase || game.status) !== "NIGHT") {
      return false;
    }
    const nightNumber = game.currentNight || 0;
    if (nightNumber !== requestedNight) return false;
    if (Array.isArray(game.resolvedNights) && game.resolvedNights.includes(nightNumber)) {
      return false;
    }

    const [playerSnaps, privateSnaps, actionSnaps] = await Promise.all([
      Promise.all(playerRefs.map((ref) => tx.get(ref))),
      Promise.all(playerRefs.map((ref) => tx.get(ref.collection("private").doc("data")))),
      Promise.all(actionRefs.map((ref) => tx.get(ref))),
    ]);

    const playersById = {};
    playerRefs.forEach((ref, index) => {
      if (!playerSnaps[index].exists) return;
      const privateData = privateSnaps[index].exists ? privateSnaps[index].data() : {};
      playersById[ref.id] = {
        ref,
        privateRef: ref.collection("private").doc("data"),
        ...playerSnaps[index].data(),
        role: privateData.role || "citizen",
        team: privateData.team || "citizens",
        lastDoctorTargetId: privateData.lastDoctorTargetId || null,
      };
    });

    const plan = planNightResolution({
      playersById,
      actions: actionSnaps.filter((snap) => snap.exists).map((snap) => snap.data()),
      nightNumber,
    });

    const eventsRef = gameRef.collection("events");
    const killedIds = new Set(plan.killedIds);
    const savedIds = new Set(plan.savedIds);
    resolvedKilledIds = [...killedIds];

    killedIds.forEach((playerId) => {
      if (savedIds.has(playerId)) return;
      const player = playersById[playerId];
      if (!player) return;
      tx.update(player.ref, {
        isAlive: false,
        canVote: false,
        canSpeak: false,
        canUseAbility: false,
        revealedRole: true,
        eliminatedBy: "night",
        canSayLastWords: true,
      });
      const name = typeof player.username === "string" && player.username.trim()
        ? player.username.trim().slice(0, 80)
        : "A player";
      // The role is revealed to the table, not just flagged on the player
      // document: a night kill is only informative if everyone learns what died.
      const label = roleLabel(player.role);
      tx.set(eventsRef.doc(`night-${nightNumber}-killed-${playerId}`), {
        type: "PlayerKilled",
        message: `${name} was killed last night. They were ${label}.`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { playerId, role: player.role, cause: "night" },
      });
    });

    for (const investigation of plan.investigations) {
      const detective = playersById[investigation.detectiveId];
      if (!detective || !detective.privateRef) continue;
      tx.update(detective.privateRef, {
        lastInvestigationResult: {
          targetId: investigation.targetId,
          result: investigation.result,
          nightNumber,
        },
      });
    }
    for (const investigation of plan.donInvestigations) {
      const don = playersById[investigation.donId];
      if (!don || !don.privateRef) continue;
      tx.update(don.privateRef, {
        lastDonInvestigationResult: {
          targetId: investigation.targetId,
          result: investigation.result,
          nightNumber,
        },
      });
    }
    if (plan.doctorPlayerId && playersById[plan.doctorPlayerId]?.privateRef) {
      tx.update(playersById[plan.doctorPlayerId].privateRef, {
        lastDoctorTargetId: plan.doctorTargetId,
      });
    }

    tx.set(eventsRef.doc(`night-${nightNumber}-resolved`), {
      type: "NightResolved",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      message: killedIds.size > 0 ? "Night ended with an elimination." : "Night ended with no death.",
      payload: { nightNumber, deathOccurred: killedIds.size > 0 },
    }, { merge: true });

    const gameUpdate = {
      resolvedNights: admin.firestore.FieldValue.arrayUnion(nightNumber),
    };
    if (killedIds.size > 0) {
      gameUpdate.eliminations = admin.firestore.FieldValue.arrayUnion(
        ...[...killedIds].map((playerId) => ({
          playerId,
          cause: "night",
          nightNumber,
          at: new Date(),
        })),
      );
    }
    tx.update(gameRef, gameUpdate);
    return true;
  });

  if (!resolved) return false;
  if (gameData.groupId) {
    try {
      for (const playerId of resolvedKilledIds) {
        await postCard(
          database,
          admin.firestore.FieldValue,
          toMafiaActivity(
            { type: "PlayerEliminated", actorId: "system", payload: { playerId } },
            { id: gameId, groupId: gameData.groupId, type: "mafia" },
          ),
        );
      }
    } catch (_) {
      // Projection failures must not roll back authoritative resolution.
    }
  }
  return true;
}

module.exports = { resolveNight, planNightResolution, pickMajorityTarget };
