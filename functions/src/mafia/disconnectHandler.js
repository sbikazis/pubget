"use strict";

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();

const DISCONNECT_THRESHOLD_SECONDS = 90;
const RECONNECT_WINDOW_SECONDS = 60;
const ACTIVE_STATUSES = [
  "WAITING",
  "STARTING",
  "ROLE_REVEAL",
  "NIGHT",
  "DAY",
  "DISCUSSION",
  "VOTING",
  "VOTE_RESULT",
  "RESOLUTION",
];

exports.markDisconnectedPlayers = onSchedule("every 1 minutes", async () => {
  const gamesSnap = await db
    .collection("mafia_games")
    .where("status", "in", ACTIVE_STATUSES)
    .get();

  const thresholdMs = Date.now() - DISCONNECT_THRESHOLD_SECONDS * 1000;

  for (const gameDoc of gamesSnap.docs) {
    const playersSnap = await gameDoc.ref.collection("players").get();

    const batch = db.batch();
    let hasChanges = false;
    const now = Date.now();

    playersSnap.docs.forEach((playerDoc) => {
      const player = playerDoc.data();
      if (player.hasLeft === true) return;
      if (player.isDisconnected === true) {
        const reconnectUntil = player.reconnectUntil?.toMillis?.() || 0;
        if (reconnectUntil > 0 && reconnectUntil <= now) {
          batch.update(playerDoc.ref, {
            isAlive: false,
            canVote: false,
            canSpeak: false,
            canUseAbility: false,
            inactiveAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          hasChanges = true;
        }
        return;
      }

      const lastSeenMs = player.lastSeenAt ? player.lastSeenAt.toMillis() : 0;
      if (lastSeenMs === 0 || lastSeenMs < thresholdMs) {
        batch.update(playerDoc.ref, {
          isDisconnected: true,
          reconnectUntil: admin.firestore.Timestamp.fromMillis(
            now + RECONNECT_WINDOW_SECONDS * 1000,
          ),
        });
        hasChanges = true;
      }
    });

    if (hasChanges) {
      await batch.commit();
      await checkWinCondition(gameDoc.id, (await gameDoc.ref.get()).data());
    }
  }
});
