"use strict";

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function createGroupCreationOutboxHandler({
  db,
  achievements,
  FieldValue,
  clock = { now: () => Date.now() },
  randomUUID = () => require("node:crypto").randomUUID(),
  leaseMs = 2 * 60 * 1000,
  retryDelayMs = 5 * 1000,
}) {
  if (!db || !achievements || typeof achievements.evaluate !== "function" ||
      !FieldValue || typeof FieldValue.delete !== "function") {
    throw new Error("Group creation outbox dependencies are required.");
  }

  return async function processGroupCreationOutbox(event) {
    const snapshot = event && event.data;
    if (!snapshot || !snapshot.ref) return { processed: false, reason: "missing_event" };

    const eventRef = snapshot.ref;
    const owner = randomUUID();
    const claimed = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(eventRef);
      if (!current.exists) return false;
      const data = current.data() || {};
      if (data.status === "completed") return false;
      if (data.type !== "group_created" ||
          typeof data.userId !== "string" || !data.userId ||
          typeof data.groupId !== "string" || !data.groupId) {
        throw new Error("Invalid group creation outbox event.");
      }

      const now = clock.now();
      if (data.status === "processing" && timestampMillis(data.leaseUntil) > now) {
        throw new Error("Group creation outbox event is already leased.");
      }
      if (data.status === "retry" && timestampMillis(data.nextAttemptAt) > now) {
        throw new Error("Group creation outbox retry is not due yet.");
      }

      transaction.update(eventRef, {
        status: "processing",
        leaseOwner: owner,
        leaseUntil: new Date(now + leaseMs),
        attempts: (Number(data.attempts) || 0) + 1,
      });
      return true;
    });

    if (!claimed) return { processed: false, reason: "already_completed_or_missing" };

    try {
      await achievements.evaluate({
        type: "group_created",
        userId: snapshot.data().userId,
        source: "group",
        metadata: { groupId: snapshot.data().groupId },
      });

      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(eventRef);
        if (!current.exists || (current.data() || {}).leaseOwner !== owner) {
          throw new Error("Group creation outbox lease was lost before completion.");
        }
        transaction.update(eventRef, {
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
          leaseOwner: FieldValue.delete(),
          leaseUntil: FieldValue.delete(),
          nextAttemptAt: FieldValue.delete(),
          lastError: FieldValue.delete(),
        });
      });
      return { processed: true };
    } catch (error) {
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(eventRef);
        if (!current.exists || (current.data() || {}).leaseOwner !== owner) return;
        transaction.update(eventRef, {
          status: "retry",
          nextAttemptAt: new Date(clock.now() + retryDelayMs),
          leaseOwner: FieldValue.delete(),
          leaseUntil: FieldValue.delete(),
          lastError: String(error && error.message || "GROUP_CREATION_EVALUATION_FAILED").slice(0, 120),
        });
      });
      throw error;
    }
  };
}

module.exports = { createGroupCreationOutboxHandler, timestampMillis };
