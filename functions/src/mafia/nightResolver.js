// functions/src/mafia/nightResolver.js
//
// ✅ التعديل الجوهري: بدل الوثوق بحقل action.role القادم من العميل،
// نقرأ الدور/الفريق الحقيقيين من الوثيقة الخاصة لكل لاعب (private/data)
// ونستخدمها كمصدر الحقيقة الوحيد. أي محاولة انتحال دور من العميل
// (submit action بـ role مزيّف) تُتجاهل تلقائياً هنا.
//
// كذلك: إجراء مافيا يستهدف زميله في المافيا يُتجاهل تماماً (الحماية
// اللي كانت سابقاً في الواجهة، انتقلت بالكامل هنا).

const admin = require("firebase-admin");

const db = admin.firestore();

async function resolveNight(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");
  const nightNumber = gameData.currentNight || 0;
  // The scheduler may have read a stale game. Never resolve an action for a
  // different phase/night, and make the resolution event deterministic.
  const currentGame = await gameRef.get();
  if (!currentGame.exists || currentGame.data().status !== "night" ||
      currentGame.data().currentPhase !== "night" ||
      currentGame.data().currentNight !== nightNumber) return false;

  const [playersSnap, actionsSnap] = await Promise.all([
    playersRef.get(),
    gameRef
      .collection("night_actions")
      .where("nightNumber", "==", nightNumber)
      .get(),
  ]);

  // ✅ نجلب الوثيقة الخاصة لكل لاعب بالتوازي، ونبني خريطة موحّدة
  // (public + private) للاستخدام الداخلي فقط على السيرفر — لا شيء
  // من هذا يُكتب لاحقاً في مكان يقرأه لاعب آخر.
  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) =>
      doc.ref.collection("private").doc("data").get()
    )
  );

  const playersById = {};
  playersSnap.docs.forEach((doc, index) => {
    const privateData = privateSnaps[index].exists
      ? privateSnaps[index].data()
      : {};
    playersById[doc.id] = {
      ref: doc.ref,
      privateRef: privateSnaps[index].ref,
      ...doc.data(),
      role: privateData.role || "citizen",
      team: privateData.team || "citizens",
      usedBullet: privateData.usedBullet || false,
    };
  });

  const actionsByRole = { mafia: [], doctor: [], detective: [], sniper: [], silencer: [] };
  const actionTaken = new Set();
  actionsSnap.docs.forEach((doc) => {
    const action = doc.data();
    if (!action || typeof action !== "object" ||
        typeof action.playerId !== "string" || typeof action.targetId !== "string" ||
        !Number.isInteger(action.nightNumber) || action.nightNumber !== nightNumber) return;
    const actualPlayer = playersById[action.playerId];

    // ✅ تجاهل أي إجراء لا يطابق الدور الحقيقي المخزَّن على السيرفر —
    // هذا يمنع انتحال الأدوار عبر تلاعب العميل بحقل role في الطلب.
    const target = playersById[action.targetId];
    if (!actualPlayer || !target || !actionsByRole[actualPlayer.role] ||
        actualPlayer.isAlive !== true || actualPlayer.hasLeft === true ||
        actualPlayer.canUseAbility === false || target.isAlive !== true ||
        target.hasLeft === true || action.nightNumber !== nightNumber) return;
    // The document's existence is the submitted action; role and completion
    // are server-derived, not client-controlled. One action per actor/role.
    const key = `${actualPlayer.role}:${action.playerId}`;
    if (actionTaken.has(key)) return;
    actionTaken.add(key);
    actionsByRole[actualPlayer.role].push(action);
  });

  const batch = db.batch();
  const eventsRef = gameRef.collection("events");
  const killedIds = new Set();
  const savedIds = new Set();

  // ✅ استبعاد أي تصويت مافيا يستهدف زميله في المافيا (حماية كانت
  // سابقاً في الواجهة، الآن هنا فقط على السيرفر).
  const validMafiaActions = actionsByRole.mafia.filter((action) => {
    const target = playersById[action.targetId];
    return target && target.team !== "mafias";
  });

  const mafiaTargetId = pickMajorityTarget(validMafiaActions);
  const doctorTargetId = actionsByRole.doctor[0]?.targetId || null;

  if (mafiaTargetId) {
    if (mafiaTargetId === doctorTargetId) {
      savedIds.add(mafiaTargetId);
      batch.set(eventsRef.doc(`night-${nightNumber}-saved-${mafiaTargetId}`), {
        type: "PlayerSaved",
        message: "🩹 حاول أحدهم القتل الليلة، لكن الطبيب أنقذ الضحية في اللحظة الأخيرة.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { playerId: mafiaTargetId },
      });
    } else if (playersById[mafiaTargetId]) {
      killedIds.add(mafiaTargetId);
    }
  }

  for (const action of actionsByRole.sniper) {
    const sniper = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!sniper || sniper.usedBullet || !target) continue;

    batch.update(sniper.privateRef, { usedBullet: true });

    if (target.team === "mafias") {
      killedIds.add(action.targetId);
      batch.set(eventsRef.doc(`night-${nightNumber}-sniper-${action.playerId}`), {
        type: "PlayerKilled",
        message: `🎯 أطلق القناص رصاصته بدقة، وأصاب أحد أعضاء المافيا.`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { playerId: action.targetId, cause: "sniper" },
      });
    } else {
      batch.set(eventsRef.doc(`night-${nightNumber}-sniper-${action.playerId}`), {
        type: "SniperMissed",
        message: `🎯 أطلق القناص رصاصته، لكنه أصاب مواطناً بريئاً بالخطأ!`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        payload: { playerId: action.targetId },
      });
      killedIds.add(action.targetId);
    }
  }

  killedIds.forEach((playerId) => {
    if (savedIds.has(playerId)) return;
    const player = playersById[playerId];
    if (!player) return;

    batch.update(player.ref, {
      isAlive: false,
      canVote: false,
      canSpeak: false,
      canUseAbility: false,
    });

    batch.set(eventsRef.doc(`night-${nightNumber}-killed-${playerId}`), {
      type: "PlayerKilled",
      message: `💀 استيقظت القرية لتجد ${typeof player.username === "string" && player.username.trim() ? player.username.trim().slice(0, 80) : "لاعباً"} قد قُتل الليلة الماضية.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: { playerId },
    });
  });

  for (const action of actionsByRole.silencer) {
    const target = playersById[action.targetId];
    if (!target || killedIds.has(action.targetId)) continue;
    batch.update(target.ref, { canSpeak: false });
  }

  // ✅ نتيجة الفحص تُكتب على الوثيقة الخاصة للمحقق نفسه فقط —
  // لا يقدر أي لاعب آخر قراءتها بحكم Firestore Rules.
  for (const action of actionsByRole.detective) {
    const detective = playersById[action.playerId];
    const target = playersById[action.targetId];
    if (!detective || !target) continue;

    batch.update(detective.privateRef, {
      lastInvestigationResult: {
        targetId: action.targetId,
        targetTeam: target.team,
        nightNumber,
      },
    });
  }

  // A deterministic marker makes retried scheduler invocations harmless.
  batch.set(eventsRef.doc(`night-${nightNumber}-resolved`), {
    type: "NightResolved",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: { nightNumber },
  }, { merge: true });
  await batch.commit();
  return true;
}

function pickMajorityTarget(mafiaActions) {
  if (mafiaActions.length === 0) return null;
  const counts = {};
  mafiaActions.forEach((action) => {
    if (!action.targetId) return;
    counts[action.targetId] = (counts[action.targetId] || 0) + 1;
  });

  let bestTarget = null;
  let bestCount = 0;
  for (const [targetId, count] of Object.entries(counts)) {
    if (count > bestCount) {
      bestCount = count;
      bestTarget = targetId;
    }
  }
  return bestTarget;
}

module.exports = { resolveNight };