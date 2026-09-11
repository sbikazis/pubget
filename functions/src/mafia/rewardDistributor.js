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
const { createAchievementsDomain } = require("../achievementsDomain");

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

let achievements;
function achievementsService() {
  if (!achievements) {
    achievements = createAchievementsDomain({
      db,
      FieldValue: admin.firestore.FieldValue,
      HttpsError,
      economy: economyService(),
    });
  }
  return achievements;
}

/**
 * Winners receive 10 coins and other participants receive 2 coins.
 * The shared economy ledger makes retries idempotent for this game.
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
  const losingUserIds = new Set();
  playersSnap.docs.forEach((doc, index) => {
    const player = doc.data();
    if (player.hasLeft === true) return;

    const team = privateSnaps[index].exists
      ? privateSnaps[index].data().team
      : "citizens";

    const userId = player.userId || doc.id;
    if (typeof userId !== "string" || userId.length === 0) return;
    if (team === winner) winningUserIds.add(userId);
    else losingUserIds.add(userId);
  });

  await economyService().grantDomainRewards([...winningUserIds], {
    type: "earn_game",
    referenceId: gameId,
    source: "mafia",
    metadata: { amountOverride: 10, result: "winner" },
  });
  await economyService().grantDomainRewards([...losingUserIds], {
    type: "earn_game",
    referenceId: `${gameId}:loss`,
    source: "mafia",
    metadata: { amountOverride: 2, result: "loser" },
  });
  await achievementsService().evaluate({
    type: "game_won",
    userIds: [...winningUserIds],
    source: "mafia",
    metadata: { gameId },
  });
  await achievementsService().evaluate({
    type: "game_completed",
    userIds: playersSnap.docs.map((doc) => doc.id),
    source: "mafia",
    metadata: { gameId },
  });
  await gameRef.update({
    rewardsDistributed: true,
    rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

module.exports = { distributeRewards };
