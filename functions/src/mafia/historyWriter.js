// functions/src/mafia/historyWriter.js
//
// يُستدعى من winConditionChecker.js فور إنهاء المباراة (بعد تحديث
// status=finished مباشرة). يكتب:
// 1. mafia_history/{gameId} — سجل عام كامل للمباراة (كل لاعب، دوره،
//    فريقه، هل فاز)، مطابق تماماً لبنية MafiaHistoryModel في Flutter.
// 2. users/{userId}/user_mafia_history/{gameId} — نسخة مختصرة لكل
//    لاعب ضمن سجله الشخصي.
// 3. users/{userId}/user_mafia_history/stats — مستند إحصائيات مجمّع
//    (عدد الانتصارات/الهزائم/عدد مرات كل دور)، يُحدَّث بالـ increment
//    فقط، تمهيداً لأي شاشة إحصائيات مستقبلية دون تعديل هذا الملف لاحقاً.
//
// Idempotency (SEC-H-02): يُطالب (`claim`) بكتابة السجل داخل نفس
// المعاملة التي تكتب الإحصائيات، عبر قراءة historyWritten ثم كتبتها على
// مستند اللعبة داخل runTransaction. أي استدعاء متزامن/مكرر يقرأ
// historyWritten=true قبل الشطب، فلا تتضاعف زيادة games/wins/losses.

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
        winner: winner || null,
        durationSeconds,
        version: gameData.version || "classic",
        players: playerIds,
        playerDetails,
        endedAt: FieldValue.serverTimestamp(),
      };

      tx.set(db.collection("mafia_history").doc(gameId), historyDoc);
      tx.update(gameRef, { historyWritten: true });

      // سجل شخصي مختصر لكل لاعب + تحديث إحصائياته المجمّعة بالـ increment.
      // كل شيء داخل نفس المعاملة: أي كتابة تنجح معاً أو لا شيء.
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

        // set مع merge لأن الحقول متداخلة (roleCounts.xxx) والمستند قد لا
        // يكون موجوداً بعد لهذا المستخدم في أول مباراة له.
        tx.set(statsRef, statsUpdate, { merge: true });
      });
    });
  }

  return { writeHistory };
}

module.exports = { createHistoryWriter };