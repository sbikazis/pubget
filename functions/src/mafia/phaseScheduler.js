// functions/src/mafia/phaseScheduler.js
//
// ✅ الإصلاح: عند بدء ليلة جديدة (next === 'night')، إعادة ضبط
// canSpeak=true لكل اللاعبين الأحياء غير المنسحبين. هذا يجعل تأثير
// المُسكِت (silencer) يدوم "ليوم واحد فقط" كما هو مصمَّم، بدل أن يبقى
// دائماً. بقية الملف من Stage 6 دون أي تغيير آخر في المنطق.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { nextPhase, durationOf, ARABIC_MESSAGES } = require("./phaseFlow");
const { resolveNight } = require("./nightResolver");
const { resolveVotes } = require("./voteResolver");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();

const ACTIVE_LOOP_STATUSES = ["night", "day", "discussion", "voting", "execution"];

exports.processPhaseTransitions = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  const expiredGames = await db
    .collection("mafia_games")
    .where("status", "in", ACTIVE_LOOP_STATUSES)
    .where("phaseEndsAt", "<=", now)
    .get();

  for (const doc of expiredGames.docs) {
    await advancePhase(doc.id, doc.data());
  }
});

async function advancePhase(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const eventRef = gameRef.collection("events").doc();

  const current = gameData.currentPhase || gameData.status;
  const next = nextPhase(current);

  if (current === "night") {
    await resolveNight(gameId, gameData);
    await checkWinCondition(gameId, (await gameRef.get()).data());
  }

  if (current === "voting") {
    await resolveVotes(gameId, gameData);
    await checkWinCondition(gameId, (await gameRef.get()).data());
  }

  // ✅ فحص واحد موثوق بعد أي حساب قد ينهي المباراة — يحل محل الفحص
  // المكرر غير الدقيق سابقاً (كان يقرأ نسخة قديمة من البيانات).
  const freshSnap = await gameRef.get();
  const freshData = freshSnap.data();
  if (freshData.status === "finished" || freshData.status === "cancelled") {
    return;
  }

  const durationSeconds = durationOf(next);
  const phaseEndsAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + durationSeconds * 1000
  );

  const updateData = {
    status: next,
    currentPhase: next,
    phaseEndsAt,
  };

  if (next === "night") {
    updateData.currentNight = admin.firestore.FieldValue.increment(1);
  } else if (next === "day") {
    updateData.currentDay = admin.firestore.FieldValue.increment(1);
  }

  const batch = db.batch();
  batch.update(gameRef, updateData);
  batch.set(eventRef, {
    type: "PhaseChanged",
    message: ARABIC_MESSAGES[next] || `انتقلت المباراة إلى مرحلة ${next}`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { from: current, to: next },
  });

  // ✅ الإصلاح: عند بدء ليلة جديدة، حرّر أي لاعب أُسكت الليلة/اليوم
  // الماضي، حتى لا يبقى صامتاً للأبد.
  if (next === "night") {
    const playersSnap = await gameRef.collection("players").get();
    playersSnap.docs.forEach((doc) => {
      const player = doc.data();
      if (player.isAlive === true && player.hasLeft !== true && player.canSpeak === false) {
        batch.update(doc.ref, { canSpeak: true });
      }
    });
  }

  await batch.commit();
}

module.exports = { advancePhase };