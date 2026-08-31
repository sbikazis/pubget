// functions/src/mafia/rewardDistributor.js
//
// يوزّع عملات الفوز على أعضاء الفريق الفائز فقط، مرة واحدة فقط لكل
// مباراة (idempotency عبر حقل rewardsDistributed على مستند اللعبة،
// بالإضافة إلى معرّف transaction ثابت لكل مستخدم يمنع التكرار حتى
// لو أُعيد استدعاء الدالة بالخطأ).
//
// ⚠️ تصميم مقصود: هذا الملف لا يستدعي coin_service.dart (ملف Flutter
// لا يُستدعى من Cloud Functions أصلاً)، بل يكرر نفس بالضبط منطق
// rewardEventWin() الموجود هناك، لكن بصلاحيات admin SDK على السيرفر:
// - نفس مسار daily_rewards/event_{today} (حد 3 مرات/يوم مشترك مع
//   بقية فعاليات التطبيق، وليس عداداً منفصلاً خاصاً بالمافيا).
// - نفس مسار transactions/{gameId} كمعرّف idempotent لكل مباراة.
// - نفس قيمة StoreConstants.rewardEventWin ونفس الحد
//   StoreConstants.maxEventWinsPerDay من lib/core/constants/store_constants.dart.
//
// أي تعديل مستقبلي على قيم المكافآت في store_constants.dart يجب أن
// يُرافقه تعديل مطابق يدوياً في الثوابت أدناه.

const admin = require("firebase-admin");

const db = admin.firestore();

// ✅ مطابقة تماماً لـ lib/core/constants/store_constants.dart
const REWARD_EVENT_WIN = 10;
const MAX_EVENT_WINS_PER_DAY = 3;

/**
 * يوزّع الجائزة على كل الأعضاء الأحياء وغير الأحياء من الفريق
 * الفائز (كل من كان جزءاً من الفريق الفائز عند نهاية المباراة يُكافأ،
 * وليس فقط من نجا حتى النهاية — هذا يطابق روح "اللعب الجماعي" في
 * لعبة المافيا التقليدية).
 */
async function distributeRewards(gameId, gameRef, winner, playersSnap) {
  const alreadyDistributedSnap = await gameRef.get();
  if (alreadyDistributedSnap.data()?.rewardsDistributed === true) {
    return; // ✅ حماية idempotency أساسية: لا توزيع مزدوج لنفس المباراة
  }

  const privateSnaps = await Promise.all(
    playersSnap.docs.map((doc) => doc.ref.collection("private").doc("data").get())
  );

  const winningUserIds = new Set();
  playersSnap.docs.forEach((doc, index) => {
    const player = doc.data();
    if (player.hasLeft === true) return; // المنسحبون لا يُكافؤون

    const team = privateSnaps[index].exists
      ? privateSnaps[index].data().team
      : "citizens";

    if (team === winner) {
      const userId = player.userId || doc.id;
      if (typeof userId === "string" && userId.length > 0) winningUserIds.add(userId);
    }
  });

  for (const userId of winningUserIds) {
    await rewardSingleUser(userId, gameId);
  }
  // Only mark completion after every per-user idempotent transaction has
  // completed. A transient failure can therefore be retried safely.
  await gameRef.update({
    rewardsDistributed: true,
    rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * نسخة طبق الأصل من منطق CoinService.rewardEventWin في Flutter،
 * لكن عبر admin SDK. نفس الشروط، نفس المسارات، نفس الحد اليومي.
 */
async function rewardSingleUser(userId, gameId) {
  const today = new Date().toISOString().split("T")[0];
  const userRef = db.collection("users").doc(userId);
  const dailyRef = userRef.collection("daily_rewards").doc(`event_${today}`);
  const txRef = userRef.collection("transactions").doc(gameId);

  await db.runTransaction(async (tx) => {
    const existingTx = await tx.get(txRef);
    if (existingTx.exists) return; // نفس المباراة سبق ورُصدت لهذا المستخدم

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;
    const dailySnap = await tx.get(dailyRef);
    const count = dailySnap.exists ? (dailySnap.data().count || 0) : 0;
    if (count >= MAX_EVENT_WINS_PER_DAY) return; // وصل الحد اليومي المشترك

    tx.update(userRef, {
      coinsBalance: admin.firestore.FieldValue.increment(REWARD_EVENT_WIN),
    });

    tx.set(
      dailyRef,
      {
        count: count + 1,
        date: today,
        lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(txRef, {
      id: gameId,
      amount: REWARD_EVENT_WIN,
      type: "event_win",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      description: `الفوز في مباراة مافيا (${count + 1}/${MAX_EVENT_WINS_PER_DAY} اليوم)`,
    });
  });
}

module.exports = { distributeRewards };