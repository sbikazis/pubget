const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

const sounds = [
  'an1','an2','an3','an4','an5','an6','an7',
  'an8','an9','an10','an11','an12','an13','an14',
  'an15','an16','an17','an18','an19','an20','an21'
];

function randomSound() {
  return sounds[Math.floor(Math.random() * sounds.length)];
}

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
    const senderName = senderDoc.data()?.senderName ?? senderDoc.data()?.username ?? "Someone";
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "Group";

    // ✅ تحديد نوع المحتوى
    let body;
    if (message.text && message.text.trim() !== "") {
      body = `${senderName}: ${message.text}`;
    } else if (message.mediaType === "image") {
      body = `${senderName}: 🖼️ صورة`;
    } else if (message.mediaType === "video") {
      body = `${senderName}: 🎥 فيديو`;
    } else {
      body = `${senderName}: 📎 ملف`;
    }

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: groupName, body },
      android: {
        notification: {
          sound: randomSound(),
          channelId: 'pubget_main_channel',
        },
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

    let body;
    if (message.text && message.text.trim() !== "") {
      body = message.text;
    } else if (message.mediaType === "image") {
      body = "🖼️ صورة";
    } else if (message.mediaType === "video") {
      body = "🎥 فيديو";
    } else {
      body = "📎 ملف";
    }

    await getMessaging().send({
      token,
      notification: { title: senderName, body },
      android: {
        notification: {
          sound: randomSound(),
          channelId: 'pubget_main_channel',
        },
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
      android: {
        notification: {
          sound: randomSound(),
          channelId: 'pubget_main_channel',
        },
      },
      data: { groupId },
    });
  }
);