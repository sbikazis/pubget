// functions/src/mafia/roleAssigner.js
//
// ✅ التعديل الجوهري: الأدوار تُكتب الآن على الوثيقة الخاصة
// (players/{id}/private/data) بدل وثيقة اللاعب العامة مباشرة.
// الوثيقة الخاصة موجودة أصلاً من لحظة الانضمام (بقيمة citizen)،
// لذلك هذا تحديث (update) وليس إنشاء.

const admin = require("firebase-admin");
const { ALL_ABILITIES } = require("./abilities");

const db = admin.firestore();

const FIRST_NIGHT_DURATION_SECONDS = 60;

function computeRoleDistribution(playersCount, version) {
  const distribution = [];

  if (version === "advanced") {
    distribution.push("mafia", "mafia");
    if (playersCount >= 6) distribution.push("doctor");
    if (playersCount >= 7) distribution.push("detective");
    if (playersCount >= 9) distribution.push("sniper");
    if (playersCount >= 10) distribution.push("silencer");
  } else {
    distribution.push("mafia", "mafia");
    if (playersCount >= 5) distribution.push("doctor");
    if (playersCount >= 6) distribution.push("detective");
  }

  while (distribution.length < playersCount) {
    distribution.push("citizen");
  }

  return distribution.slice(0, playersCount);
}

function shuffle(array) {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

async function assignRoles(gameId, gameData) {
  const gameRef = db.collection("mafia_games").doc(gameId);
  const playersRef = gameRef.collection("players");

  const playersSnap = await playersRef.get();
  const activePlayers = playersSnap.docs.filter(
    (doc) => doc.data().hasLeft !== true
  );

  if (activePlayers.length < (gameData.minPlayers || 8)) {
    return;
  }

  const distribution = shuffle(
    computeRoleDistribution(activePlayers.length, gameData.version || "classic")
  );

  const batch = db.batch();

  activePlayers.forEach((playerDoc, index) => {
    const role = distribution[index];
    const ability = ALL_ABILITIES[role];
    // ✅ الكتابة الآن على الوثيقة الخاصة فقط، وليس مستند اللاعب العام.
    const privateRef = playerDoc.ref.collection("private").doc("data");
    batch.update(privateRef, {
      role,
      team: ability ? ability.team : "citizens",
    });
  });

  const phaseEndsAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + FIRST_NIGHT_DURATION_SECONDS * 1000
  );

  batch.update(gameRef, {
    status: "night",
    currentPhase: "night",
    currentNight: 1,
    countdownEndsAt: admin.firestore.FieldValue.delete(),
    phaseEndsAt,
  });

  const eventRef = gameRef.collection("events").doc();
  batch.set(eventRef, {
    type: "RolesAssigned",
    message: "تم توزيع الأدوار، وبدأت الليلة الأولى في المافيا...",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payload: {
      playersCount: activePlayers.length,
      version: gameData.version || "classic",
    },
  });

  await batch.commit();
}

module.exports = { assignRoles, computeRoleDistribution };