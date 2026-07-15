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
// Idempotency: يتحقق من historyWritten على مستند اللعبة قبل الكتابة،
// بنفس نمط rewardsDistributed تماماً من Stage 6.

const admin = require("firebase-admin");

const db = admin.firestore();

async function writeHistory(gameId, gameRef, winner, playersSnap) {
  const gameSnap = await gameRef.get();
  const gameData = gameSnap.data();

  if (gameData?.historyWritten === true) {
    return; // ✅ حماية idempotency: لا تكرار للسجل لنفس المباراة
  }

  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) => doc.ref.collection("private").doc("data").get())
  );

  const playerDetails = [];
  const playerIds = [];

  playersSnap.docs.forEach((doc, index) => {
    const player = doc.data();
    const privateData = privateSnaps[index].exists ? privateSnaps[index].data() : {};
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

  const startedAtMs = gameData.startedAt ? gameData.startedAt.toMillis() : null;
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
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();

  batch.set(db.collection("mafia_history").doc(gameId), historyDoc);
  batch.update(gameRef, { historyWritten: true });

  // ✅ سجل شخصي مختصر لكل لاعب + تحديث إحصائياته المجمّعة بالـ increment.
  // كل هذا في نفس الـ batch لضمان اتساق الكتابة (كل شيء ينجح معاً أو لا شيء).
  playerDetails.forEach((entry) => {
    if (!entry.userId) return;

    const userHistoryRef = db
      .collection("users")
      .doc(entry.userId)
      .collection("user_mafia_history")
      .doc(gameId);

    batch.set(userHistoryRef, {
      gameId,
      role: entry.role,
      team: entry.team,
      won: entry.won,
      version: historyDoc.version,
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const statsRef = db
      .collection("users")
      .doc(entry.userId)
      .collection("user_mafia_history")
      .doc("stats");

    const statsUpdate = {
      gamesPlayed: admin.firestore.FieldValue.increment(1),
      [`roleCounts.${entry.role}`]: admin.firestore.FieldValue.increment(1),
    };
    if (entry.won) {
      statsUpdate.wins = admin.firestore.FieldValue.increment(1);
    } else {
      statsUpdate.losses = admin.firestore.FieldValue.increment(1);
    }

    // set مع merge لأن الحقول متداخلة (roleCounts.xxx) والمستند قد لا
    // يكون موجوداً بعد لهذا المستخدم في أول مباراة له.
    batch.set(statsRef, statsUpdate, { merge: true });
  });

  await batch.commit();
}

module.exports = { writeHistory };