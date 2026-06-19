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

// ══════════════════════════════════════════════════════════════
// رسائل المجموعة
// ══════════════════════════════════════════════════════════════
exports.onNewGroupMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const groupId = event.params.groupId;
    const db = getFirestore();

    if (message.type === 'systemEvent') return;

    const membersSnap = await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .get();

    const senderId = message.senderId;
    const tokens = [];

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      if (memberId === senderId) continue;
      if (memberId === 'system') continue;

      const userDoc = await db.collection("users").doc(memberId).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "شخص ما";
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "مجموعة";

    let body;
    if (message.text && message.text.trim() !== "") {
      body = `${senderName}: ${message.text}`;
    } else if (message.mediaType === "image") {
      body = `${senderName}: 🖼️ صورة`;
    } else if (message.mediaType === "gif") {
      body = `${senderName}: 🎞️ GIF`;
    } else if (message.mediaType === "sticker") {
      body = `${senderName}: 🏷️ ملصق`;
    } else if (message.mediaType === "audio") {
      body = `${senderName}: 🎤 رسالة صوتية`;
    } else if (message.mediaType === "video") {
      body = `${senderName}: 🎥 فيديو`;
    } else {
      body = `${senderName}: 📎 ملف`;
    }

    const sound = randomSound();

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: groupName, body },
      android: {
        notification: {
          sound,
          channelId: `pubget_channel_${sound}`,
        },
      },
      data: {
        type: 'group_chat',
        refId: groupId,
        senderId: senderId,
        senderName: senderName,
        contextName: groupName,
        commentId: '',
      },
    });
  }
);

// ══════════════════════════════════════════════════════════════
// رسائل الدردشة الخاصة
// ══════════════════════════════════════════════════════════════
exports.onNewPrivateMessage = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const senderId = message.senderId;
    const chatId = event.params.chatId;
    const db = getFirestore();

    const chatDoc = await db.collection("privateChats").doc(chatId).get();
    const userA = chatDoc.data()?.userA;
    const userB = chatDoc.data()?.userB;

    const receiverId = userA === senderId ? userB : userA;
    if (!receiverId) return;

    const userDoc = await db.collection("users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = senderDoc.data()?.username ?? "شخص ما";

    let body;
    if (message.text && message.text.trim() !== "") {
      body = message.text;
    } else if (message.mediaType === "image") {
      body = "🖼️ صورة";
    } else if (message.mediaType === "gif") {
      body = "🎞️ GIF";
    } else if (message.mediaType === "sticker") {
      body = "🏷️ ملصق";
    } else if (message.mediaType === "audio") {
      body = "🎤 رسالة صوتية";
    } else if (message.mediaType === "video") {
      body = "🎥 فيديو";
    } else {
      body = "📎 ملف";
    }

    const sound = randomSound();

    await getMessaging().send({
      token,
      notification: { title: senderName, body },
      android: {
        notification: {
          sound,
          channelId: `pubget_channel_${sound}`,
        },
      },
      data: {
        type: 'private_chat',
        refId: chatId,
        senderId: senderId,
        senderName: senderName,
        contextName: senderName,
        commentId: '',
      },
    });
  }
);

// ══════════════════════════════════════════════════════════════
// طلبات الانضمام
// ══════════════════════════════════════════════════════════════
exports.onJoinRequest = onDocumentCreated(
  "groups/{groupId}/requests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const groupId = event.params.groupId;
    const db = getFirestore();

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const ownerId = groupDoc.data()?.ownerId;
    const groupName = groupDoc.data()?.name ?? "مجموعة";
    if (!ownerId) return;

    const ownerDoc = await db.collection("users").doc(ownerId).get();
    const token = ownerDoc.data()?.fcmToken;
    if (!token) return;

    const requesterDoc = await db
      .collection("users")
      .doc(request.userId)
      .get();
    const requesterName = requesterDoc.data()?.username ?? "شخص ما";

    const sound = randomSound();

    await getMessaging().send({
      token,
      notification: {
        title: groupName,
        body: `${requesterName} يريد الانضمام للمجموعة`,
      },
      android: {
        notification: {
          sound,
          channelId: `pubget_channel_${sound}`,
        },
      },
      data: {
        type: 'join_request',
        refId: groupId,
        senderId: request.userId ?? '',
        senderName: requesterName,
        contextName: groupName,
        commentId: '',
      },
    });
  }
);