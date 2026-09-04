// functions/src/mafia/phaseScheduler.js
//
// ✅ الإصلاح: عند بدء ليلة جديدة (next === 'night')، إعادة ضبط
// canSpeak=true لكل اللاعبين الأحياء غير المنسحبين. هذا يجعل تأثير
// المُسكِت (silencer) يدوم "ليوم واحد فقط" كما هو مصمَّم، بدل أن يبقى
// دائماً. بقية الملف من Stage 6 دون أي تغيير آخر في المنطق.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { nextPhase, durationOf, PHASE_MESSAGES } = require("./phaseFlow");
const { resolveNight } = require("./nightResolver");
const { resolveVotes } = require("./voteResolver");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();

const ACTIVE_LOOP_STATUSES = ["night", "day", "discussion", "voting", "execution"];
const CLAIM_LEASE_MS = 5 * 60 * 1000;

const processPhaseTransitions = onSchedule("every 1 minutes", async () => {
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
  const current = gameData.currentPhase || gameData.status;
  const claimId = `${process.pid || "scheduler"}:${Date.now()}:${gameId}`;
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    const data = snap.data();
    const claimedBy = data && data.phaseTransitionClaim;
    const expiresAt = claimedBy && claimedBy.expiresAt;
    const leaseExpired = !expiresAt || typeof expiresAt.toMillis !== "function" ||
      expiresAt.toMillis() <= Date.now();
    if (!snap.exists || !data || (data.currentPhase || data.status) !== current ||
        (!data.phaseEndsAt || typeof data.phaseEndsAt.toMillis !== "function" ||
        data.phaseEndsAt.toMillis() > Date.now()) || (claimedBy && !leaseExpired) ||
        data.status === "finished" ||
        data.status === "cancelled") return false;
    tx.update(gameRef, {
      phaseTransitionClaim: {
        owner: claimId,
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + CLAIM_LEASE_MS),
      },
    });
    return true;
  });
  if (!claimed) return;

  try {
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
    await releaseClaim(gameRef, claimId);
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
    phaseTransitionClaim: admin.firestore.FieldValue.delete(),
  };

  if (next === "night") {
    updateData.currentNight = admin.firestore.FieldValue.increment(1);
  } else if (next === "day") {
    updateData.currentDay = admin.firestore.FieldValue.increment(1);
  }

  const ownership = await gameRef.get();
  if (!ownership.exists || ownership.data().phaseTransitionClaim?.owner !== claimId) return;
  const batch = db.batch();
  batch.update(gameRef, updateData);
  batch.set(gameRef.collection("events").doc(`phase-${current}-${gameData.currentNight || gameData.currentDay || 0}`), {
    type: "PhaseChanged",
    message: PHASE_MESSAGES[next] || `The game moved to ${next}.`,
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
  } catch (error) {
    // Permit the scheduled retry only if this invocation still owns the claim.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(gameRef);
      if (snap.exists && snap.data().phaseTransitionClaim?.owner === claimId) {
        tx.update(gameRef, { phaseTransitionClaim: admin.firestore.FieldValue.delete() });
      }
    });
    throw error;
  }
}

async function releaseClaim(gameRef, owner) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (snap.exists && snap.data().phaseTransitionClaim?.owner === owner) {
      tx.update(gameRef, { phaseTransitionClaim: admin.firestore.FieldValue.delete() });
    }
  });
}

module.exports = { processPhaseTransitions, advancePhase };