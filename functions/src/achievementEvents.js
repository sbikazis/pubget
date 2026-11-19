"use strict";

/**
 * Consumes achievement events written by the authenticated Worker group route.
 *
 * Firestore triggers are at-least-once, so a claim document is created before
 * evaluation. Without it, a retried delivery would run the threshold / keeper
 * evaluators twice and corrupt the counters they patch.
 */
function createAchievementEventProcessor({ db, achievements, FieldValue }) {
  async function handleEvent(event) {
    const snapshot = event && event.data;
    if (!snapshot) return null;
    const payload = snapshot.data() || {};
    if (payload.type !== "group_created" || !payload.userId) return null;
    const eventId = event.params && event.params.eventId;
    if (!eventId) return null;

    const claimRef = db.collection("achievementEventClaims").doc(eventId);
    let claimed = false;
    try {
      await db.runTransaction(async (transaction) => {
        claimed = false;
        if ((await transaction.get(claimRef)).exists) return;
        transaction.create(claimRef, {
          claimedAt: FieldValue.serverTimestamp(),
          type: payload.type,
          userId: payload.userId,
        });
        claimed = true;
      });
    } catch (error) {
      // ALREADY_EXISTS means a concurrent delivery claimed it first.
      if (error && error.code === 6) return null;
      throw error;
    }
    if (!claimed) return null;

    try {
      await achievements.evaluate({
        type: payload.type,
        userId: payload.userId,
        source: payload.source || "group",
        metadata: Object.assign({}, payload.metadata || {}),
      });
      await snapshot.ref.set(
        { processedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    } catch (error) {
      // Let the trigger retry: a partially evaluated event must not be
      // permanently marked as claimed with no way to recover.
      await claimRef.delete();
      throw error;
    }
    return null;
  }

  return { handleEvent };
}

module.exports = { createAchievementEventProcessor };
