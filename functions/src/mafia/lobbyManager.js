// functions/src/mafia/lobbyManager.js
//
// مسؤول هذا الملف: إدارة دورة حياة غرفة الانتظار (Stage 1)
// + استدعاء توزيع الأدوار عند اكتمال عد starting (Stage 2).
// ✅ محوّل الآن لصيغة Firebase Functions v2 لتطابق باقي المشروع.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { assignRoles } = require("./roleAssigner");

const db = admin.firestore();

const STATUS = {
  WAITING: "waiting",
  STARTING: "starting",
  CANCELLED: "cancelled",
};
const CLAIM_LEASE_MS = 5 * 60 * 1000;

exports.processExpiredLobbies = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  const expiredWaiting = await db
    .collection("mafia_games")
    .where("status", "==", STATUS.WAITING)
    .where("countdownEndsAt", "<=", now)
    .get();

  for (const doc of expiredWaiting.docs) {
    await cancelLobby(doc.id, doc.data());
  }

  const expiredStarting = await db
    .collection("mafia_games")
    .where("status", "==", STATUS.STARTING)
    .where("countdownEndsAt", "<=", now)
    .get();

  for (const doc of expiredStarting.docs) {
    await beginGame(doc.id, doc.data());
  }
});

async function cancelLobby(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  if (typeof gameData.groupId !== "string" || !gameData.groupId) return;
  // Mark cancellation first, transactionally. Retried schedulers therefore
  // cannot delete a lobby that has subsequently started.
  const claimed = await db.runTransaction(async (tx) => {
    const groupRef = db.collection("groups").doc(gameData.groupId);
    const snap = await tx.get(gameRef);
    const group = await tx.get(groupRef);
    if (!snap.exists || snap.data().status !== STATUS.WAITING) return false;
    tx.update(gameRef, { status: STATUS.CANCELLED, currentPhase: STATUS.CANCELLED });
    if (group.exists && group.data().activeGameId === gameId) {
      tx.update(groupRef, {
        activeGameId: admin.firestore.FieldValue.delete(),
        gameStatus: admin.firestore.FieldValue.delete(), hasRunningGame: false,
      });
    }
    return true;
  });
  if (!claimed) return;
  const playersSnap = await playersRef.get();
  const batch = db.batch();
  playersSnap.docs.forEach((playerDoc) => batch.delete(playerDoc.ref));
  // Retain the cancelled game as an idempotency/audit marker.
  await batch.commit();

  await sendSystemMessage({
    groupId: gameData.groupId,
    text: "❌ تم إلغاء مباراة المافيا لعدم اكتمال عدد اللاعبين.",
    systemEventType: "mafiaGameCancelled",
    gameId,
  });
}

async function beginGame(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);

  const owner = `${process.pid || "lobby"}:${Date.now()}:${gameId}`;
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    const currentClaim = snap.exists && snap.data().roleAssignmentClaim;
    const expired = !currentClaim || !currentClaim.expiresAt ||
      typeof currentClaim.expiresAt.toMillis !== "function" ||
      currentClaim.expiresAt.toMillis() <= Date.now();
    if (!snap.exists || snap.data().status !== STATUS.STARTING ||
        snap.data().rolesAssigned === true || (currentClaim && !expired)) return false;
    tx.update(gameRef, {
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      roleAssignmentClaim: { owner, expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + CLAIM_LEASE_MS) },
    });
    return true;
  });
  if (claimed) {
    try {
      const assigned = await assignRoles(gameId, {
        ...gameData,
        roleAssignmentOwner: owner,
      });
      // assignRoles atomically cancels invalid claimed lobbies (including the
      // matching group marker). Treat a false result as handled, not a retry.
      if (!assigned) return;
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(gameRef);
        if (snap.exists && snap.data().roleAssignmentClaim?.owner === owner) {
          tx.update(gameRef, { roleAssignmentClaim: admin.firestore.FieldValue.delete() });
        }
      });
      throw error;
    }
  }
}

async function sendSystemMessage({ groupId, text, systemEventType, gameId }) {
  if (!gameId) return;
  await db.collection("mafia_games").doc(gameId).collection("events")
    .doc(`${systemEventType || "system"}-${gameId}`)
    .set({
      type: systemEventType || "System",
      message: text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { groupId: groupId || null },
    }, { merge: true });
}