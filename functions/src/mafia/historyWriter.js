// functions/src/mafia/historyWriter.js
//
// Writes the canonical Mafia records when a match ends:
// 1. mafia_history/{gameId} — full public record (every player, role, team,
//    win flag) plus phaseHistory/eliminations/votingResults/rewards.
// 2. users/{userId}/user_mafia_history/{gameId} — per-player short record.
// 3. users/{userId}/user_mafia_history/stats — aggregated stats doc that only
//    increments gamesPlayed/wins/losses and roleCounts.<role>.
//
// Idempotency (SEC-H-02): the whole write is claimed inside one transaction
// by reading and then setting historyWritten on the game doc, so concurrent
// or repeated invocations cannot double-increment games/wins/losses.

const admin = require("firebase-admin");

function createHistoryWriter(options = {}) {
  const db = options.db || admin.firestore();
  const FieldValue = options.FieldValue || admin.firestore.FieldValue;

  async function writeHistory(gameId, gameRef, winner, playersSnap) {
    await db.runTransaction(async (tx) => {
      const gameSnap = await tx.get(gameRef);
      if (!gameSnap.exists) return;
      if (gameSnap.data().historyWritten === true) return;

      const gameData = gameSnap.data();

      const privateSnaps = await Promise.all(
        playersSnap.docs.map((doc) =>
          tx.get(doc.ref.collection("private").doc("data")),
        ),
      );

      const playerDetails = [];
      const playerIds = [];

      playersSnap.docs.forEach((doc, index) => {
        const player = doc.data();
        const privateData = privateSnaps[index].exists
          ? privateSnaps[index].data()
          : {};
        const role = privateData.role || "citizen";
        const team = privateData.team || "citizens";

        playerIds.push(player.userId || doc.id);
        playerDetails.push({
          userId: player.userId || doc.id,
          username: player.username || "",
          role,
          team,
          won: winner != null && team === winner,
        });
      });

      const startedAtMs =
        gameData && gameData.startedAt &&
        typeof gameData.startedAt.toMillis === "function"
          ? gameData.startedAt.toMillis()
          : null;
      const durationSeconds = startedAtMs
        ? Math.max(0, Math.round((Date.now() - startedAtMs) / 1000))
        : 0;

      const historyDoc = {
        gameId,
        groupId: gameData.groupId || null,
        creatorId: gameData.createdBy || null,
        winner: winner || null,
        durationSeconds,
        version: gameData.version || "classic",
        players: playerIds,
        playerDetails,
        phaseHistory: gameData.phaseHistory || [],
        eliminations: gameData.eliminations || [],
        votingResults: gameData.votingResults || [],
        rewards: gameData.rewards || null,
        createdAt: gameData.createdAt || null,
        startedAt: gameData.startedAt || null,
        endedAt: FieldValue.serverTimestamp(),
      };

      tx.set(db.collection("mafia_history").doc(gameId), historyDoc);
      tx.update(gameRef, { historyWritten: true });

      playerDetails.forEach((entry) => {
        if (!entry.userId) return;

        const userHistoryRef = db
          .collection("users")
          .doc(entry.userId)
          .collection("user_mafia_history")
          .doc(gameId);

        tx.set(userHistoryRef, {
          gameId,
          role: entry.role,
          team: entry.team,
          won: entry.won,
          version: historyDoc.version,
          endedAt: FieldValue.serverTimestamp(),
        });

        const statsRef = db
          .collection("users")
          .doc(entry.userId)
          .collection("user_mafia_history")
          .doc("stats");

        const statsUpdate = {
          gamesPlayed: FieldValue.increment(1),
          [`roleCounts.${entry.role}`]: FieldValue.increment(1),
        };
        if (entry.won) {
          statsUpdate.wins = FieldValue.increment(1);
        } else {
          statsUpdate.losses = FieldValue.increment(1);
        }

        tx.set(statsRef, statsUpdate, { merge: true });
      });
    });
  }

  return { writeHistory };
}

module.exports = { createHistoryWriter };