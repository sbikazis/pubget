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
const { postFromActivity } = require("../chatCardWriter");
const { toMafiaActivity } = require("./mafiaActivity");

const db = admin.firestore();

const ACTIVE_LOOP_STATUSES = [
  "role_reveal", "night", "day", "discussion", "voting", "revote", "resolution",
];
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

  const discussionGames = await db.collection("mafia_games")
    .where("status", "==", "discussion").get();
  for (const doc of discussionGames.docs) {
    const turnEndsAt = doc.data().turnEndsAt;
    if (turnEndsAt?.toMillis?.() <= Date.now()) {
      await advanceDiscussionTurn(doc.id);
    }
  }
});

async function advanceDiscussionTurn(gameId) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  await db.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRef);
    if (!gameSnap.exists) return;
    const game = gameSnap.data() || {};
    if (game.currentPhase !== "discussion") return;
    const players = await tx.get(gameRef.collection("players"));
    const eligible = new Set(players.docs
      .filter((doc) => doc.data().isAlive === true &&
        doc.data().hasLeft !== true && doc.data().isDisconnected !== true)
      .map((doc) => doc.id));
    const order = (game.speakingOrder || []).filter((id) => eligible.has(id));
    const currentIndex = order.indexOf(game.currentSpeakerId);
    const nextSpeakerId = currentIndex >= 0 ? order[currentIndex + 1] : order[0];
    if (nextSpeakerId && nextSpeakerId !== game.currentSpeakerId) {
      tx.update(gameRef, {
        currentSpeakerId: nextSpeakerId,
        turnStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        turnEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 20_000),
      });
    } else {
      tx.update(gameRef, {
        status: "voting",
        currentPhase: "voting",
        currentSpeakerId: null,
        phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        phaseEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 45_000),
      });
    }
  });
}

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
         ["game_over", "finished"].includes(data.status) ||
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
   if (current === "night") {
    await resolveNight(gameId, gameData);
    await checkWinCondition(gameId, (await gameRef.get()).data());
  }

   if (current === "voting" || current === "revote") {
    await resolveVotes(gameId, gameData);
    await checkWinCondition(gameId, (await gameRef.get()).data());
  }

  // ✅ فحص واحد موثوق بعد أي حساب قد ينهي المباراة — يحل محل الفحص
  // المكرر غير الدقيق سابقاً (كان يقرأ نسخة قديمة من البيانات).
  const freshSnap = await gameRef.get();
  const freshData = freshSnap.data();
   if (["game_over", "finished", "cancelled"].includes(freshData.status)) {
    await releaseClaim(gameRef, claimId);
    return;
  }

   const afterResolution = await gameRef.get();
   const afterData = afterResolution.data() || {};
   if (afterData.currentPhase === "revote") {
     await releaseClaim(gameRef, claimId);
     return;
   }
   let next = nextPhase(current);
   if (current === "role_reveal") next = "night";
   if (current === "night") next = "day";
   if (current === "discussion") next = "voting";
   if (current === "voting" || current === "revote") next = "resolution";
   if (current === "resolution") next = "night";
   const durationSeconds = durationOf(next);
  const phaseEndsAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + durationSeconds * 1000
  );

  const updateData = {
    status: next,
    currentPhase: next,
    phaseEndsAt,
    phaseStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    phaseHistory: admin.firestore.FieldValue.arrayUnion({
      from: current,
      to: next,
      at: new Date(),
    }),
    phaseTransitionClaim: admin.firestore.FieldValue.delete(),
  };

   if (next === "night") {
    updateData.currentNight = admin.firestore.FieldValue.increment(1);
  } else if (next === "day") {
    updateData.currentDay = admin.firestore.FieldValue.increment(1);
  }
   if (next === "discussion") {
     const alive = (await gameRef.collection("players").get()).docs
       .filter((doc) => doc.data().isAlive === true && doc.data().hasLeft !== true)
       .map((doc) => doc.id);
     updateData.speakingOrder = alive;
     updateData.currentSpeakerId = alive[0] || null;
     updateData.turnStartedAt = admin.firestore.FieldValue.serverTimestamp();
     updateData.turnEndsAt = admin.firestore.Timestamp.fromMillis(Date.now() + 20_000);
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
   const chatEventType = next === "night"
     ? "NightStarted"
     : next === "day"
       ? "DayStarted"
       : null;
   if (chatEventType && freshData.groupId) {
     try {
       await postFromActivity(
         db,
         admin.firestore.FieldValue,
         toMafiaActivity(
           { type: chatEventType, actorId: "system", payload: { phase: next } },
           { id: gameId, groupId: freshData.groupId, type: "mafia" },
         ),
       );
     } catch (_) {
       // Chat cards are projections and never block the game state machine.
     }
   }
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

module.exports = { processPhaseTransitions, advancePhase, advanceDiscussionTurn };