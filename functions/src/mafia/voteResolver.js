// functions/src/mafia/voteResolver.js
//
// يُستدعى من phaseScheduler.js لحظة الانتقال من voting إلى execution.
// يحسب نتيجة التصويت (تعادل = لا إعدام)، وينفّذ الإعدام إن وُجدت
// أغلبية واضحة، ويكشف دور اللاعب المُعدَم في نص الحدث العام —
// وهذا سلوك تصميمي مقصود يطابق آلية "كشف الهوية عند الإعدام" في
// لعبة المافيا التقليدية، وليس تسريباً غير مقصود (بخلاف ثغرة
// Stage 4.5 التي كانت تكشف كل الأدوار طوال الوقت لأي لاعب).

const admin = require("firebase-admin");

const db = admin.firestore();

const ROLE_LABELS_AR = {
  mafia: "من عصابة المافيا",
  doctor: "الطبيب",
  detective: "المحقق",
  sniper: "القناص",
  silencer: "المُسكِت",
  good_boy: "الصديق الطيب",
  citizen: "مواطناً بريئاً",
};

async function resolveVotes(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const dayNumber = gameData.currentDay || 0;
  const currentGame = await gameRef.get();
  if (!currentGame.exists || currentGame.data().status !== "voting" ||
      currentGame.data().currentPhase !== "voting" ||
      currentGame.data().currentDay !== dayNumber) return false;

  const [playersSnap, votesSnap] = await Promise.all([
    playersRef.get(),
    gameRef
      .collection("votes")
      .where("dayNumber", "==", dayNumber)
      .get(),
  ]);

  const playersById = {};
  playersSnap.docs.forEach((doc) => {
    playersById[doc.id] = { ref: doc.ref, ...doc.data() };
  });

  // ✅ نتجاهل أصوات أي لاعب غير حي أو غير مخوَّل بالتصويت وقت
  // الفرز، حتى لو كان صوته قد أُرسل قبل موته (مثلاً لو مات بحدث
  // متزامن). هذا تحقق دفاعي بسيط لا يغيّر السلوك المعتاد.
  const validVotes = votesSnap.docs.filter((doc) => {
    const vote = doc.data();
    if (!vote || typeof vote !== "object" || typeof vote.voterId !== "string" ||
        typeof vote.targetId !== "string" || !Number.isInteger(vote.dayNumber)) return false;
    const voter = playersById[vote.voterId];
    const target = playersById[vote.targetId];
    return voter && target && vote.dayNumber === dayNumber &&
      voter.isAlive === true && voter.hasLeft !== true && voter.canVote !== false &&
      target.isAlive === true && target.hasLeft !== true;
  });

  const tally = {};
  validVotes.forEach((doc) => {
    const vote = doc.data();
    tally[vote.targetId] = (tally[vote.targetId] || 0) + 1;
  });

  const eventsRef = gameRef.collection("events");

  if (Object.keys(tally).length === 0) {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "ExecutionSkipped",
      message: "🤐 لم يصوّت أحد اليوم، ولم يُعدَم أحد.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber },
    });
    return true;
  }

  // ✅ تحديد الأعلى تصويتاً، مع فحص التعادل: لو أكثر من هدف يتشارك
  // أعلى عدد أصوات، لا يُعدَم أحد (قرار تصميم صريح تم توضيحه للمستخدم).
  let topTargetId = null;
  let topCount = 0;
  let tiedCount = 0;

  for (const [targetId, count] of Object.entries(tally)) {
    if (count > topCount) {
      topCount = count;
      topTargetId = targetId;
      tiedCount = 1;
    } else if (count === topCount) {
      tiedCount += 1;
    }
  }

  if (tiedCount > 1) {
    await eventsRef.doc(`vote-${dayNumber}-resolved`).set({
      type: "ExecutionSkipped",
      message: "⚖️ تعادلت الأصوات، ولم تتمكن القرية من اتخاذ قرار اليوم.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { dayNumber, tally },
    });
    return true;
  }

  const target = playersById[topTargetId];
  if (!target || target.isAlive !== true || target.hasLeft === true) return false;

  const privateSnap = await target.ref.collection("private").doc("data").get();
  const role = privateSnap.exists ? privateSnap.data().role : "citizen";
  const roleLabel = ROLE_LABELS_AR[role] || "مواطناً";

  const batch = db.batch();
  batch.update(target.ref, {
    isAlive: false,
    canVote: false,
    canSpeak: false,
    canUseAbility: false,
    revealedRole: true,
  });

  batch.set(eventsRef.doc(`vote-${dayNumber}-resolved`), {
    type: "PlayerExecuted",
    message: `⚖️ قررت القرية إعدام ${typeof target.username === "string" && target.username.trim() ? target.username.trim().slice(0, 80) : "لاعباً"}... وتبيّن أنه كان ${roleLabel}!`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { playerId: topTargetId, role, dayNumber },
  });

  await batch.commit();
  return true;
}

module.exports = { resolveVotes };