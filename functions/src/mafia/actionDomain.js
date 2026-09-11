"use strict";

const { canonicalPhase } = require("./phaseFlow");

const NIGHT_ACTIONS = new Set([
  "mafia_kill", "doctor_protect", "detective_investigate", "don_investigate",
]);

function validId(value) {
  return typeof value === "string" && value.trim().length > 0 && value.length <= 128;
}

function createMafiaActionDomain({ db, FieldValue, Timestamp, HttpsError }) {
  function requireUid(request) {
    if (!request?.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  function gameRef(gameId) {
    return db.collection("mafia_games").doc(gameId);
  }

  async function submitMafiaAction(request) {
    const uid = requireUid(request);
    const input = request.data || {};
    const gameId = input.gameId;
    const actionId = input.actionId;
    const actionType = input.actionType;
    const rawTargetId = input.targetId || null;
    const donInvestigation =
      actionType === "night_action" &&
      typeof rawTargetId === "string" &&
      rawTargetId.startsWith("__don_investigate__");
    const targetId = donInvestigation
      ? rawTargetId.slice("__don_investigate__".length)
      : rawTargetId;
    const expectedStateVersion = input.expectedStateVersion;
    if (!validId(gameId) || !validId(actionId) || typeof actionType !== "string") {
      throw new HttpsError("invalid-argument", "gameId, actionId, and actionType are required.");
    }

    const ref = gameRef(gameId.trim());
    const receiptRef = ref.collection("action_receipts").doc(`${uid}_${actionId.trim()}`);
    let duplicate = false;
    await db.runTransaction(async (tx) => {
      const [gameSnap, playerSnap, receiptSnap] = await Promise.all([
        tx.get(ref),
        tx.get(ref.collection("players").doc(uid)),
        tx.get(receiptRef),
      ]);
      if (receiptSnap.exists) {
        duplicate = true;
        return;
      }
      if (!gameSnap.exists) throw new HttpsError("not-found", "Mafia game not found.");
      const game = gameSnap.data() || {};
      const phase = canonicalPhase(game.currentPhase || game.status);
      if (["GAME_OVER", "CANCELLED"].includes(phase) || game.resultLocked === true) {
        throw new HttpsError("failed-precondition", "This Mafia game is locked.");
      }
      if (Number.isInteger(expectedStateVersion) &&
          Number.isInteger(game.stateVersion) &&
          expectedStateVersion !== game.stateVersion) {
        throw new HttpsError("aborted", "The game state changed. Refresh and try again.");
      }
      if (!playerSnap.exists || playerSnap.data().isAlive !== true ||
          playerSnap.data().hasLeft === true) {
        throw new HttpsError("permission-denied", "Only a living player can act.");
      }
      const player = playerSnap.data();
      const privateSnap = await tx.get(
        ref.collection("players").doc(uid).collection("private").doc("data"),
      );
      const privateData = privateSnap.exists ? privateSnap.data() : {};
      const role = privateData.role;
      const isTargetedAction = validId(targetId);
      if (phase === "NIGHT") {
        const resolvedActionType = donInvestigation ? "don_investigate"
          : actionType === "night_action"
          ? role === "doctor" ? "doctor_protect"
            : role === "detective" ? "detective_investigate"
              : role === "don" ? "mafia_kill"
                : "mafia_kill"
          : actionType;
        if (!NIGHT_ACTIONS.has(resolvedActionType) || !isTargetedAction) {
          throw new HttpsError("invalid-argument", "Invalid night action.");
        }
        const allowed = (resolvedActionType === "mafia_kill" &&
            (role === "mafia" || role === "don")) ||
          (resolvedActionType === "doctor_protect" && role === "doctor") ||
          (resolvedActionType === "detective_investigate" && role === "detective") ||
          (resolvedActionType === "don_investigate" && role === "don");
        if (!allowed || player.canUseAbility === false) {
          throw new HttpsError("permission-denied", "This role cannot use that action.");
        }
        const targetSnap = await tx.get(ref.collection("players").doc(targetId));
        if (!targetSnap.exists || targetSnap.data().isAlive !== true ||
            targetSnap.data().hasLeft === true) {
          throw new HttpsError("failed-precondition", "Choose a living player.");
        }
        if ((role === "mafia" || role === "don") &&
            targetId === uid || (role === "mafia" || role === "don") &&
            ["mafia", "don"].includes(
              (await tx.get(ref.collection("players").doc(targetId)
                .collection("private").doc("data"))).data()?.role,
            )) {
          throw new HttpsError("failed-precondition", "Mafia cannot target Mafia.");
        }
        const nightNumber = game.currentNight || 0;
        tx.set(ref.collection("night_actions").doc(`${uid}_n${nightNumber}`), {
          playerId: uid,
          targetId,
          actionType: resolvedActionType,
          nightNumber,
          actionId: actionId.trim(),
          submittedAt: FieldValue.serverTimestamp(),
        });
      } else if (phase === "VOTING") {
        if (actionType !== "vote" || !isTargetedAction || player.canVote === false) {
          throw new HttpsError("invalid-argument", "Invalid vote.");
        }
        const targetSnap = await tx.get(ref.collection("players").doc(targetId));
        if (!targetSnap.exists || targetSnap.data().isAlive !== true ||
            targetSnap.data().hasLeft === true || targetId === uid) {
          throw new HttpsError("failed-precondition", "Choose another living player.");
        }
        const dayNumber = game.currentDay || 0;
        const round = game.revoteCount || 0;
        tx.set(ref.collection("votes").doc(`${uid}_d${dayNumber}_r${round}`), {
          voterId: uid,
          targetId,
          dayNumber,
          round,
          actionId: actionId.trim(),
          submittedAt: FieldValue.serverTimestamp(),
        });
      } else if (phase === "DISCUSSION") {
        if (actionType !== "end_turn") {
          throw new HttpsError("invalid-argument", "Discussion action is invalid.");
        }
        tx.set(ref.collection("discussion_actions").doc(`${uid}_d${game.currentDay || 0}`), {
          playerId: uid,
          actionId: actionId.trim(),
          type: "end_turn",
          createdAt: FieldValue.serverTimestamp(),
        });
      } else {
        throw new HttpsError("failed-precondition", "Actions are not open in this phase.");
      }
      tx.create(receiptRef, {
        actionId: actionId.trim(),
        actionType,
        playerId: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        stateVersion: (game.stateVersion || 0) + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, duplicate };
  }

  async function sendMafiaMessage(request) {
    const uid = requireUid(request);
    const input = request.data || {};
    if (!validId(input.gameId) || typeof input.text !== "string" ||
        input.text.trim().length === 0 || input.text.trim().length > 1000) {
      throw new HttpsError("invalid-argument", "A gameId and short message are required.");
    }
    const ref = gameRef(input.gameId.trim());
    await db.runTransaction(async (tx) => {
      const gameSnap = await tx.get(ref);
      const playerSnap = await tx.get(ref.collection("players").doc(uid));
      if (!gameSnap.exists || !playerSnap.exists || playerSnap.data().isAlive !== true ||
          playerSnap.data().canSpeak === false) {
        throw new HttpsError("permission-denied", "You cannot speak in this game.");
      }
      const phase = canonicalPhase(gameSnap.data().currentPhase);
      if (!["DAY", "DISCUSSION", "VOTING"].includes(phase)) {
        throw new HttpsError("failed-precondition", "Discussion is closed.");
      }
      const privateData = (await tx.get(
        ref.collection("players").doc(uid).collection("private").doc("data"),
      )).data() || {};
      const channel = privateData.team === "mafias" ? "mafia_chat" : "chat";
      tx.create(ref.collection(channel).doc(), {
        senderId: uid,
        sender: playerSnap.data().username,
        senderAvatar: playerSnap.data().avatar || "",
        text: input.text.trim(),
        time: FieldValue.serverTimestamp(),
        type: "player",
      });
    });
    return { ok: true };
  }

  async function heartbeatMafia(request) {
    const uid = requireUid(request);
    if (!validId(request.data?.gameId)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const playerRef = gameRef(request.data.gameId.trim()).collection("players").doc(uid);
    await playerRef.update({
      lastSeenAt: FieldValue.serverTimestamp(),
      isDisconnected: false,
      disconnectExpiresAt: FieldValue.delete(),
    });
    return { ok: true };
  }

  return { submitMafiaAction, sendMafiaMessage, heartbeatMafia };
}

module.exports = { createMafiaActionDomain };