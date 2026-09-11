"use strict";

const admin = require("firebase-admin");

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
  const actionsByRole = { mafia: [], doctor: [], detective: [], sniper: [], silencer: [] };
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

  const validMafiaActions = actionsByRole.mafia.filter((action) => {
    const target = playersById[action.targetId];
    return target && target.team !== "mafias";
  });
  const mafiaTargetId = pickMajorityTarget(validMafiaActions);
  const doctorTargetId = actionsByRole.doctor[0] ? actionsByRole.doctor[0].targetId : null;
  const savedIds = [];
  const killedIds = [];
  if (mafiaTargetId) {
    if (mafiaTargetId === doctorTargetId) savedIds.push(mafiaTargetId);
    else killedIds.push(mafiaTargetId);
  }

  const sniperResults = [];
  for (const action of actionsByRole.sniper) {
    const sniper = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!sniper || sniper.usedBullet || !target) continue;
    sniperResults.push({
      sniperId: action.playerId,
      targetId: action.targetId,
      hitMafia: target.team === "mafias",
    });
    killedIds.push(action.targetId);
  }

  const silencedIds = [];
  for (const action of actionsByRole.silencer) {
    const target = playersById[action.targetId];
    if (!target || killedIds.includes(action.targetId)) continue;
    silencedIds.push(action.targetId);
  }

  const investigations = [];
  for (const action of actionsByRole.detective) {
    const detective = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!detective || !target) continue;
    investigations.push({
      detectiveId: action.playerId,
      targetId: action.targetId,
      targetTeam: target.team,
    });
  }

  return {
    mafiaTargetId,
    doctorTargetId,
    killedIds: [...new Set(killedIds)],
    savedIds,
    sniperResults,
    silencedIds,
    investigations,
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
      usedBullet: privateData.usedBullet || false,
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

  if (plan.mafiaTargetId && savedIds.has(plan.mafiaTargetId)) {
    batch.set(eventsRef.doc(`night-${nightNumber}-saved-${plan.mafiaTargetId}`), {
      type: "PlayerSaved",
      message: "Someone was attacked, but the doctor saved them.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playerId: plan.mafiaTargetId },
    });
  }

  for (const shot of plan.sniperResults) {
    const sniper = playersById[shot.sniperId];
    if (sniper && sniper.privateRef) {
      batch.update(sniper.privateRef, { usedBullet: true });
    }
    batch.set(eventsRef.doc(`night-${nightNumber}-sniper-${shot.sniperId}`), {
      type: shot.hitMafia ? "PlayerKilled" : "SniperMissed",
      message: shot.hitMafia
        ? "The sniper hit a Mafia member."
        : "The sniper hit an innocent villager.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playerId: shot.targetId, cause: "sniper" },
    });
  }

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
      payload: { playerId },
    });
  });

  for (const playerId of plan.silencedIds) {
    const target = playersById[playerId];
    if (!target || killedIds.has(playerId)) continue;
    batch.update(target.ref, { canSpeak: false });
  }

  for (const investigation of plan.investigations) {
    const detective = playersById[investigation.detectiveId];
    if (!detective || !detective.privateRef) continue;
    batch.update(detective.privateRef, {
      lastInvestigationResult: {
        targetId: investigation.targetId,
        targetTeam: investigation.targetTeam,
        nightNumber,
      },
    });
  }

  batch.set(eventsRef.doc(`night-${nightNumber}-resolved`), {
    type: "NightResolved",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { nightNumber },
  }, { merge: true });
  await batch.commit();
  return true;
}

module.exports = { resolveNight, planNightResolution, pickMajorityTarget };
