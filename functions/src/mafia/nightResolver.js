"use strict";

const admin = require("firebase-admin");
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

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

async function resolveNight(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const nightNumber = gameData.currentNight || 0;
  const currentGame = await gameRef.get();
  if (!currentGame.exists || currentGame.data().status !== "night" ||
      currentGame.data().currentPhase !== "night" ||
      currentGame.data().currentNight !== nightNumber) return false;

  const [playersSnap, actionsSnap] = await Promise.all([
    playersRef.get(),
    gameRef.collection("night_actions").where("nightNumber", "==", nightNumber).get(),
  ]);

  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) => doc.ref.collection("private").doc("data").get()),
  );

  const playersById = {};
  playersSnap.docs.forEach((doc, index) => {
    const privateData = privateSnaps[index].exists ? privateSnaps[index].data() : {};
    playersById[doc.id] = {
      ref: doc.ref,
      privateRef: privateSnaps[index].ref,
      ...doc.data(),
      role: privateData.role || "citizen",
      team: privateData.team || "citizens",
    lastDoctorTargetId: privateData.lastDoctorTargetId || null,
    };
  });

  const plan = planNightResolution({
    playersById,
    actions: actionsSnap.docs.map((doc) => doc.data()),
    nightNumber,
  });

  const batch = db.batch();
  const eventsRef = gameRef.collection("events");
  const killedIds = new Set(plan.killedIds);
  const savedIds = new Set(plan.savedIds);

  killedIds.forEach((playerId) => {
    if (savedIds.has(playerId)) return;
    const player = playersById[playerId];
    if (!player) return;
    batch.update(player.ref, {
      isAlive: false,
      canVote: false,
      canSpeak: false,
      canUseAbility: false,
    });
    const name = typeof player.username === "string" && player.username.trim()
      ? player.username.trim().slice(0, 80)
      : "A player";
    batch.set(eventsRef.doc(`night-${nightNumber}-killed-${playerId}`), {
      type: "PlayerKilled",
      message: `${name} was killed last night.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playerId, cause: "night" },
    });
  });

  for (const investigation of plan.investigations) {
    const detective = playersById[investigation.detectiveId];
    if (!detective || !detective.privateRef) continue;
    batch.update(detective.privateRef, {
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
    batch.update(don.privateRef, {
      lastDonInvestigationResult: {
        targetId: investigation.targetId,
        result: investigation.result,
        nightNumber,
      },
    });
  }
  if (plan.doctorPlayerId && playersById[plan.doctorPlayerId]?.privateRef) {
    batch.update(playersById[plan.doctorPlayerId].privateRef, {
      lastDoctorTargetId: doctorTargetId,
    });
  }

  batch.set(eventsRef.doc(`night-${nightNumber}-resolved`), {
    type: "NightResolved",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    message: killedIds.size > 0 ? "Night ended with an elimination." : "Night ended with no death.",
    payload: { nightNumber, deathOccurred: killedIds.size > 0 },
  }, { merge: true });
  if (killedIds.size > 0) {
    batch.update(gameRef, {
      eliminations: admin.firestore.FieldValue.arrayUnion(
        ...[...killedIds].map((playerId) => ({
          playerId,
          cause: "night",
          nightNumber,
          at: new Date(),
        })),
      ),
    });
  }
  await batch.commit();
  if (gameData.groupId) {
    try {
      for (const playerId of killedIds) {
        await postFromActivity(
          db,
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
