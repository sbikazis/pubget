"use strict";

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();
const NIGHT_ROLES = new Set(["mafia", "don", "doctor", "detective"]);
const MAFIA_ROLES = new Set(["mafia", "don"]);

function requireUid(request) {
  if (!request?.auth?.uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  return request.auth.uid;
}

function string(value, max = 128) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= max;
}

function idempotentRef(gameRef, uid, actionId) {
  return gameRef.collection("action_receipts").doc(`${uid}_${actionId}`);
}

/**
 * All gameplay writes go through this callable. Firestore rules intentionally
 * reject client-created actions; the scheduler remains the only writer of
 * outcomes.
 */
async function submitMafiaAction(request) {
  const uid = requireUid(request);
  const data = request.data || {};
  const gameId = data.gameId;
  const actionId = data.actionId;
  const type = data.type;
  const targetId = data.targetId;
  if (!string(gameId) || !string(actionId, 160) || !string(type, 40)) {
    throw new HttpsError("invalid-argument", "gameId, actionId and type are required.");
  }
  const gameRef = db.collection("mafia_games").doc(gameId.trim());
  const result = await db.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRef);
    if (!gameSnap.exists) throw new HttpsError("not-found", "Mafia game not found.");
    const game = gameSnap.data() || {};
    if (["game_over", "finished", "cancelled"].includes(game.status) ||
        ["game_over", "finished", "cancelled"].includes(game.currentPhase)) {
      throw new HttpsError("failed-precondition", "This Mafia game is over.");
    }
    const playerRef = gameRef.collection("players").doc(uid);
    const playerSnap = await tx.get(playerRef);
    if (!playerSnap.exists) throw new HttpsError("permission-denied", "You are not in this game.");
    const player = playerSnap.data() || {};
    const submittingLastWords = type === "last_words";
    if (player.hasLeft === true || (!submittingLastWords && player.isAlive !== true)) {
      throw new HttpsError("failed-precondition", "Spectators cannot change the game.");
    }
    const receiptRef = idempotentRef(gameRef, uid, actionId.trim());
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) return { duplicate: true, result: receipt.data().result || "accepted" };
    const privateRef = playerRef.collection("private").doc("data");
    const privateSnap = await tx.get(privateRef);
    const privateData = privateSnap.exists ? privateSnap.data() || {} : {};
    const phase = game.currentPhase || game.status;
    let resultName = "accepted";

    if (type === "last_words") {
      if (player.isAlive === true || string(player.lastWords, 280)) {
        throw new HttpsError("failed-precondition", "Last words are already closed.");
      }
      if (!string(data.text, 280)) {
        throw new HttpsError("invalid-argument", "Last words must be short.");
      }
      tx.update(playerRef, {
        lastWords: data.text.trim(),
        lastWordsAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (type === "mafia_message") {
      if (!MAFIA_ROLES.has(privateData.role) || !string(data.text, 1000)) {
        throw new HttpsError("permission-denied", "Only Mafia members can use this channel.");
      }
      tx.create(gameRef.collection("mafia_messages").doc(), {
        senderId: uid,
        text: data.text.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (type === "night_action") {
      if (phase !== "night" || !NIGHT_ROLES.has(privateData.role)) {
        throw new HttpsError("failed-precondition", "This role cannot act now.");
      }
      if (!string(targetId)) throw new HttpsError("invalid-argument", "A target is required.");
      const targetSnap = await tx.get(gameRef.collection("players").doc(targetId));
      const target = targetSnap.exists ? targetSnap.data() || {} : null;
      if (!target || target.isAlive !== true || target.hasLeft === true) {
        throw new HttpsError("invalid-argument", "Choose a living player.");
      }
      if (["mafia", "don"].includes(privateData.role) && targetId === uid) {
        throw new HttpsError("invalid-argument", "You cannot target yourself.");
      }
      const actionRef = gameRef.collection("night_actions").doc(`${uid}_n${game.currentNight}`);
      tx.set(actionRef, {
        actionId: actionId.trim(), playerId: uid, targetId: targetId.trim(),
        nightNumber: game.currentNight, role: privateData.role,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (privateData.role === "doctor") {
        // A repeated target is rejected before it reaches the resolver.
        if (privateData.lastDoctorTargetId === targetId) {
          throw new HttpsError("invalid-argument", "Doctor cannot protect the same player twice.");
        }
      }
    } else if (type === "vote") {
      if (!["voting", "revote"].includes(phase) || player.canVote === false) {
        throw new HttpsError("failed-precondition", "Voting is not open.");
      }
      if (!string(targetId) || targetId === uid) {
        throw new HttpsError("invalid-argument", "Choose another living player.");
      }
      const targetSnap = await tx.get(gameRef.collection("players").doc(targetId));
      if (!targetSnap.exists || targetSnap.data().isAlive !== true) {
        throw new HttpsError("invalid-argument", "Choose a living player.");
      }
      const candidates = Array.isArray(game.revoteCandidates) ? game.revoteCandidates : [];
      if (phase === "revote" && !candidates.includes(targetId)) {
        throw new HttpsError("invalid-argument", "The re-vote is only between tied players.");
      }
      const voteRef = gameRef.collection("votes").doc(`${uid}_d${game.currentDay}`);
      tx.set(voteRef, {
        actionId: actionId.trim(), voterId: uid, targetId: targetId.trim(),
        dayNumber: game.currentDay, revote: phase === "revote",
        time: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (type === "end_turn") {
      if (phase !== "discussion" || game.currentSpeakerId !== uid) {
        throw new HttpsError("failed-precondition", "It is not your speaking turn.");
      }
      const order = Array.isArray(game.speakingOrder) ? game.speakingOrder : [];
      const currentIndex = order.indexOf(uid);
      const nextSpeakerId = currentIndex >= 0 ? order[currentIndex + 1] : null;
      if (nextSpeakerId) {
        tx.update(gameRef, {
          currentSpeakerId: nextSpeakerId,
          turnStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          turnEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 20_000),
        });
      } else {
        tx.update(gameRef, {
          status: "voting", currentPhase: "voting",
          phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 45_000),
          currentSpeakerId: null,
        });
      }
    } else {
      throw new HttpsError("invalid-argument", "Unsupported Mafia action.");
    }
    tx.create(receiptRef, {
      actionId: actionId.trim(), uid, type, result: resultName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { duplicate: false, result: resultName };
  });
  if (result.result === "accepted" && type === "night_action") {
    // This is deliberately best effort: win checks only read server state.
    const fresh = await gameRef.get();
    if (fresh.exists) await checkWinCondition(gameId, fresh.data());
  }
  return { ok: true, ...result };
}

async function sendMafiaChat(request) {
  const uid = requireUid(request);
  const { gameId, text } = request.data || {};
  if (!string(gameId) || !string(text, 1000)) {
    throw new HttpsError("invalid-argument", "gameId and text are required.");
  }
  const gameRef = db.collection("mafia_games").doc(gameId.trim());
  await db.runTransaction(async (tx) => {
    const [gameSnap, playerSnap] = await Promise.all([
      tx.get(gameRef), tx.get(gameRef.collection("players").doc(uid)),
    ]);
    const game = gameSnap.data() || {};
    const player = playerSnap.data() || {};
    if (!playerSnap.exists || player.isAlive !== true || player.canSpeak === false ||
        !["day", "discussion", "voting"].includes(game.currentPhase)) {
      throw new HttpsError("failed-precondition", "Chat is not open for you.");
    }
    tx.create(gameRef.collection("chat").doc(), {
      senderId: uid, sender: player.username || uid, senderAvatar: player.avatar || "",
      text: text.trim(), type: "player",
      time: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
}

async function heartbeatMafia(request) {
  const uid = requireUid(request);
  const { gameId } = request.data || {};
  if (!string(gameId)) throw new HttpsError("invalid-argument", "gameId is required.");
  await db.collection("mafia_games").doc(gameId.trim()).collection("players").doc(uid).update({
    lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
    isDisconnected: false,
    reconnectUntil: admin.firestore.FieldValue.delete(),
  });
  return { ok: true };
}

module.exports = { submitMafiaAction, sendMafiaChat, heartbeatMafia };