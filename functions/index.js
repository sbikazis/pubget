const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

// ✅ إشعار عند وصول رسالة جديدة في مجموعة
exports.onNewGroupMessage = onDocumentCreated(
  "Groups/{groupId}/Messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const groupId = event.params.groupId;

    const db = getFirestore();

    // جلب أعضاء المجموعة
    const membersSnap = await db
      .collection("Groups")
      .doc(groupId)
      .collection("Members")
      .get();

    const senderId = message.senderId;
    const tokens = [];

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      if (memberId === senderId) continue;

      const userDoc = await db.collection("Users").doc(memberId).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const senderDoc = await db.collection("Users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "Someone";

    const groupDoc = await db.collection("Groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "Group";

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${groupName}`,
        body: `${senderName}: ${message.content ?? "📎 media"}`,
      },
      data: { groupId },
    });
  }
);

// ✅ إشعار عند وصول رسالة خاصة
exports.onNewPrivateMessage = onDocumentCreated(
  "PrivateChats/{chatId}/Messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const senderId = message.senderId;
    const receiverId = message.receiverId;

    if (!receiverId) return;

    const db = getFirestore();
    const userDoc = await db.collection("Users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;

    if (!token) return;

    const senderDoc = await db.collection("Users").doc(senderId).get();
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

// ✅ إشعار عند طلب انضمام لمجموعة
exports.onJoinRequest = onDocumentCreated(
  "Groups/{groupId}/JoinRequests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const groupId = event.params.groupId;

    const db = getFirestore();
    const groupDoc = await db.collection("Groups").doc(groupId).get();
    const ownerId = groupDoc.data()?.ownerId;
    const groupName = groupDoc.data()?.name ?? "Group";

    if (!ownerId) return;

    const ownerDoc = await db.collection("Users").doc(ownerId).get();
    const token = ownerDoc.data()?.fcmToken;

    if (!token) return;

    const requesterDoc = await db
      .collection("Users")
      .doc(request.userId)
      .get();
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