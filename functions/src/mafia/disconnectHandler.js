// functions/src/mafia/disconnectHandler.js
//
// يفحص كل دقيقة كل اللاعبين ضمن المباريات النشطة (غير finished/
// cancelled)، ويعلّم أي لاعب توقفت نبضته منذ أكثر من 90 ثانية
// كـ isDisconnected=true. لا يقتله ولا يمس بياناته الأخرى — فقط
// علامة بصرية يمكن استخدامها لاحقاً في الواجهة (Stage 9).
//
// ⚠️ هذا حل تقريبي (heartbeat-based) وليس presence فورياً حقيقياً
// مثل Firebase Realtime Database's onDisconnect(). التأخير النموذجي
// لاكتشاف الانقطاع هنا: حتى دقيقتين تقريباً (90 ثانية عتبة + حتى
// دقيقة انتظار الجدولة القادمة).

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { checkWinCondition } = require("./winConditionChecker");

const db = admin.firestore();

const DISCONNECT_THRESHOLD_SECONDS = 90;
const RECONNECT_WINDOW_SECONDS = 60;
const ACTIVE_STATUSES = [
  "waiting",
  "starting",
  "night",
  "day",
  "discussion",
  "voting",
  "execution",
];

exports.markDisconnectedPlayers = onSchedule("every 1 minutes", async () => {
  const gamesSnap = await db
    .collection("mafia_games")
    .where("status", "in", ACTIVE_STATUSES)
    .get();

  const thresholdMs = Date.now() - DISCONNECT_THRESHOLD_SECONDS * 1000;

  for (const gameDoc of gamesSnap.docs) {
    const playersSnap = await gameDoc.ref.collection("players").get();

    const batch = db.batch();
    let hasChanges = false;
    const now = Date.now();

    playersSnap.docs.forEach((playerDoc) => {
      const player = playerDoc.data();
      if (player.hasLeft === true) return;
      if (player.isDisconnected === true) {
        const reconnectUntil = player.reconnectUntil?.toMillis?.() || 0;
        if (reconnectUntil > 0 && reconnectUntil <= now) {
          batch.update(playerDoc.ref, {
            isAlive: false,
            canVote: false,
            canSpeak: false,
            canUseAbility: false,
            inactiveAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          hasChanges = true;
        }
        return;
      }

      const lastSeenMs = player.lastSeenAt ? player.lastSeenAt.toMillis() : 0;
      if (lastSeenMs === 0 || lastSeenMs < thresholdMs) {
        batch.update(playerDoc.ref, {
          isDisconnected: true,
          reconnectUntil: admin.firestore.Timestamp.fromMillis(
            now + RECONNECT_WINDOW_SECONDS * 1000,
          ),
        });
        hasChanges = true;
      }
    });

    if (hasChanges) {
      await batch.commit();
      await checkWinCondition(gameDoc.id, (await gameDoc.ref.get()).data());
    }
  }
});