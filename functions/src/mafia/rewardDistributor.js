// functions/src/mafia/rewardDistributor.js
//
// يوزّع عملات الفوز على أعضاء الفريق الفائز فقط، مرة واحدة فقط لكل
// مباراة (idempotency عبر حقل rewardsDistributed على مستند اللعبة).
//
// Economy writes go through the shared Economy domain so Mafia does not
// own coinsBalance / ledger internals.

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");
const { createEconomyDomain } = require("../economyDomain");

const db = admin.firestore();

let economy;
function economyService() {
  if (!economy) {
    economy = createEconomyDomain({
      db,
      FieldValue: admin.firestore.FieldValue,
      HttpsError,
    });
  }
  return economy;
}

/**
 * يوزّع الجائزة على كل الأعضاء الأحياء وغير الأحياء من الفريق
 * الفائز (كل من كان جزءاً من الفريق الفائز عند نهاية المباراة يُكافأ،
 * وليس فقط من نجا حتى النهاية — هذا يطابق روح "اللعب الجماعي" في
 * لعبة المافيا التقليدية).
 */
async function distributeRewards(gameId, gameRef, winner, playersSnap) {
  const alreadyDistributedSnap = await gameRef.get();
  if (alreadyDistributedSnap.data()?.rewardsDistributed === true) {
    return;
  }

  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) => doc.ref.collection("private").doc("data").get())
  );

  const winningUserIds = new Set();
  playersSnap.docs.forEach((doc, index) => {
    const player = doc.data();
    if (player.hasLeft === true) return;

    const team = privateSnaps[index].exists
      ? privateSnaps[index].data().team
      : "citizens";

    if (team === winner) {
      const userId = player.userId || doc.id;
      if (typeof userId === "string" && userId.length > 0) winningUserIds.add(userId);
    }
  });

  await economyService().grantDomainRewards([...winningUserIds], {
    type: "earn_event",
    referenceId: gameId,
    source: "mafia",
  });
  await gameRef.update({
    rewardsDistributed: true,
    rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

module.exports = { distributeRewards };
