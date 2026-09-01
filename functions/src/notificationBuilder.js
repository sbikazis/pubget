"use strict";

const PUSH_TYPES = new Set([
  "group_message",
  "private_message",
  "join_request",
  "request_accepted",
  "friend_request",
  "respect_received",
]);

function validId(value) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= 128;
}

function unreadCounterField(type) {
  if (type === "group_message") return "unreadGroupsCount";
  if (type === "private_message") return "unreadPrivateMessagesCount";
  if (type === "mention") return "unreadMentionsCount";
  return null;
}

function createNotificationBuilder({ db, messaging, FieldValue }) {
  async function tokensForUsers(userIds) {
    const result = [];
    for (let offset = 0; offset < userIds.length; offset += 30) {
      const chunk = userIds.slice(offset, offset + 30);
      const snapshot = await db.collectionGroup("fcmTokens")
        .where("uid", "in", chunk).get();
      snapshot.docs.forEach((doc) => {
        const token = doc.data()?.token;
        if (typeof token === "string" && token.length <= 4096) {
          result.push({ ref: doc.ref, token, uid: doc.data().uid });
        }
      });
    }
    return result;
  }

  async function removeInvalidToken(item, error) {
    const invalid = error && (
      error.code === "messaging/registration-token-not-registered" ||
      error.code === "messaging/invalid-registration-token");
    if (!invalid) return;
    await item.ref.delete().catch(() => {});
  }

  async function sendPush(notification, recipientIds, title, body) {
    if (!notification.pushWorthy || recipientIds.length === 0) return;
    const recipients = await tokensForUsers(recipientIds);
    const uniqueTokens = [...new Map(
      recipients.map((item) => [item.token, item]),
    ).values()];
    for (let offset = 0; offset < uniqueTokens.length; offset += 500) {
      const chunk = uniqueTokens.slice(offset, offset + 500);
      const response = await messaging.sendEachForMulticast({
        tokens: chunk.map((item) => item.token),
        notification: { title, body },
        data: {
          type: notification.type,
          destination: notification.destination,
          targetId: notification.targetId || "",
          notificationId: notification.id,
        },
      });
      await Promise.all(response.responses.map((item, index) =>
        item.success ? null : removeInvalidToken(chunk[index], item.error)));
    }
  }

  async function build({
    id,
    recipientIds,
    type,
    actorId = null,
    targetId,
    action,
    destination,
    metadata = {},
    groupKey = null,
    title,
    body,
    pushWorthy = PUSH_TYPES.has(type),
  }) {
    if (!validId(id) || !Array.isArray(recipientIds) || !validId(targetId) ||
        !validId(action) || !validId(destination)) {
      throw new Error("Invalid notification builder input.");
    }
    const uniqueRecipients = [...new Set(recipientIds.filter(validId))];
    let createdCount = 0;
    for (let offset = 0; offset < uniqueRecipients.length; offset += 200) {
      const recipients = uniqueRecipients.slice(offset, offset + 200);
      const created = await db.runTransaction(async (transaction) => {
        const refs = recipients.map((recipientId) =>
          db.collection("users").doc(recipientId)
            .collection("notifications").doc(id));
        const snapshots = await Promise.all(
          refs.map((ref) => transaction.get(ref)),
        );
        const committed = [];
        recipients.forEach((recipientId, index) => {
          const ref = refs[index];
          const existing = snapshots[index];
          if (existing.exists) return;
          transaction.create(ref, {
            type,
            actorId: actorId && validId(actorId) ? actorId : null,
            targetId,
            action,
            destination,
            metadata,
            groupKey: groupKey || null,
            createdAt: FieldValue.serverTimestamp(),
            readAt: null,
            pushWorthy: Boolean(pushWorthy),
          });
          const counters = {
            unreadNotificationsCount: FieldValue.increment(1),
          };
          const domainCounter = unreadCounterField(type);
          if (domainCounter) counters[domainCounter] = FieldValue.increment(1);
          transaction.set(
            db.collection("users").doc(recipientId),
            counters,
            { merge: true },
          );
          committed.push(recipientId);
        });
        return committed;
      });
      createdCount += created.length;
      if (created.length > 0) {
        await sendPush({
          id, type, targetId, destination, pushWorthy,
        }, created, title || "Pubget", body || "لديك إشعار جديد");
      }
    }
    return { created: createdCount };
  }

  return { build };
}

module.exports = { createNotificationBuilder, PUSH_TYPES };