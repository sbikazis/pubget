const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

// ✅ رسالة جديدة في مجموعة
exports.onNewGroupMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const groupId = event.params.groupId;
    const db = getFirestore();

    const membersSnap = await db.collection("groups").doc(groupId).collection("members").get();
    const senderId = message.senderId;
    const tokens = [];

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      if (memberId === senderId) continue;
      const userDoc = await db.collection("users").doc(memberId).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "Someone";
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "Group";

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: groupName,
        body: `${senderName}: ${message.content ?? "📎 media"}`,
      },
      data: { groupId },
    });
  }
);

// ✅ رسالة خاصة جديدة
exports.onNewPrivateMessage = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const senderId = message.senderId;
    const receiverId = message.receiverId;
    if (!receiverId) return;

    const db = getFirestore();
    const userDoc = await db.collection("users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "Someone";

    await getMessaging().send({
      token,
      notification: {
        title: senderName,
        body: message.content ?? "📎 media",
      },
      data: { senderId },
    });
  }
);

// ✅ طلب انضمام لمجموعة
exports.onJoinRequest = onDocumentCreated(
  "groups/{groupId}/requests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const groupId = event.params.groupId;
    const db = getFirestore();

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const ownerId = groupDoc.data()?.ownerId;
    const groupName = groupDoc.data()?.name ?? "Group";
    if (!ownerId) return;

    const ownerDoc = await db.collection("users").doc(ownerId).get();
    const token = ownerDoc.data()?.fcmToken;
    if (!token) return;

    const requesterDoc = await db.collection("users").doc(request.userId).get();
    const requesterName = requesterDoc.data()?.username ?? "Someone";

    await getMessaging().send({
      token,
      notification: {
        title: groupName,
        body: `${requesterName} wants to join`,
      },
      data: { groupId },
    });
  }
);