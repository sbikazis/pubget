// functions/index.js
//
// ✅ الإضافة الوحيدة: تصدير disconnectHandler، بنفس نمط الإضافات
// السابقة تماماً — بقية الملف (الإشعارات + lobbyManager + phaseScheduler)
// دون أي تغيير آخر.

const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { buildPublicProfile } = require("./src/publicProfile");

initializeApp();

exports.syncPublicProfile = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const after = event.data && event.data.after;
  const publicRef = getFirestore().collection("public_profiles").doc(uid);

  if (!after || !after.exists) {
    await publicRef.delete();
    return;
  }

  // Full replacement is intentional: fields removed from the allowlist or
  // source cannot linger in the public projection.
  await publicRef.set(buildPublicProfile(uid, after.data(), new Date(event.time)));
});

const sounds = [
  'an1','an2','an3','an4','an5','an6','an7',
  'an8','an9','an10','an11','an12','an13','an14',
  'an15','an16','an17','an18','an19','an20','an21'
];

function randomSound() {
  return sounds[Math.floor(Math.random() * sounds.length)];
}

const MAX_NOTIFICATION_TEXT = 240;
const MAX_NOTIFICATION_NAME = 80;

function validId(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128;
}

function displayText(value, fallback, limit = MAX_NOTIFICATION_NAME) {
  return typeof value === "string" && value.trim()
    ? value.trim().slice(0, limit)
    : fallback;
}

const ROLLBACK_MAX_AGE_MS = 30 * 60 * 1000;
const MAX_FAREWELL_LENGTH = 500;

function callableString(value, maxLength) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= maxLength;
}

function createdAtMillis(value) {
  if (value && typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return NaN;
}

function callableError(error) {
  if (error instanceof HttpsError) throw error;
  console.error("disbandGroup cleanup failed", error);
  throw new HttpsError("internal", "Group cleanup did not complete. Please retry.");
}

exports.disbandGroup = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const data = request.data;
  if (!data || typeof data !== "object" || !callableString(data.groupId, 128)) {
    throw new HttpsError("invalid-argument", "groupId must be a non-empty string of at most 128 characters.");
  }
  if (data.mode !== "disband" && data.mode !== "rollback") {
    throw new HttpsError("invalid-argument", "mode must be disband or rollback.");
  }
  if (data.farewellMessage !== undefined &&
      (typeof data.farewellMessage !== "string" ||
       data.farewellMessage.trim().length > MAX_FAREWELL_LENGTH)) {
    throw new HttpsError("invalid-argument", "farewellMessage must be at most 500 characters.");
  }

  const groupId = data.groupId.trim();
  const mode = data.mode;
  const uid = request.auth.uid;
  const db = getFirestore();
  const groupRef = db.collection("groups").doc(groupId);
  let groupData;

  try {
    const transactionResult = await db.runTransaction(async (transaction) => {
      const groupSnap = await transaction.get(groupRef);
      if (!groupSnap.exists) return null; // Idempotent success after deletion.

      const current = groupSnap.data() || {};
      const founderId = current.founderId || current.ownerId;
      if (founderId !== uid) {
        throw new HttpsError("permission-denied", "Only the group founder may remove this group.");
      }
      if (current.deletionPending === true &&
          (current.deletionRequestedBy !== uid || current.deletionMode !== mode)) {
        throw new HttpsError("failed-precondition", "Group deletion is already in progress.");
      }
      if (mode === "rollback") {
        const ageMs = Date.now() - createdAtMillis(current.createdAt);
        if (!Number.isInteger(current.membersCount) || current.membersCount > 1 ||
            !Number.isFinite(ageMs) || ageMs < 0 || ageMs > ROLLBACK_MAX_AGE_MS) {
          throw new HttpsError(
            "failed-precondition",
            "Rollback is only available for a recently created one-member group.",
          );
        }
      }

      // This marker closes all rule-based client access while the privileged
      // cleanup below is in progress. A retry by the same founder/mode resumes it.
      if (current.deletionPending !== true) {
        transaction.update(groupRef, {
          deletionPending: true,
          deletionRequestedBy: uid,
          deletionMode: mode,
          deletionMarkedAt: FieldValue.serverTimestamp(),
        });
      }
      return current;
    });
    if (transactionResult === null) return { ok: true, alreadyDeleted: true };
    groupData = transactionResult;
  } catch (error) {
    callableError(error);
  }

  try {
    // Read recipients only after the marker is committed, preventing clients
    // from changing membership during the teardown.
    const membersSnap = await groupRef.collection("members").get();
    const memberIds = membersSnap.docs
      .map((member) => member.id)
      .filter((memberId) => validId(memberId));
    const founderId = groupData.founderId || groupData.ownerId;

    // Delete storage first: if it fails, the marked group remains so a retry
    // can finish cleanup instead of silently leaving orphaned objects.
    await getStorage().bucket().deleteFiles({ prefix: `groups/${groupId}/` });

    if (mode === "disband") {
      const groupName = displayText(groupData.name, "مجموعة");
      const farewell = typeof data.farewellMessage === "string"
        ? data.farewellMessage.trim()
        : "";
      const body = farewell || `تم تفكيك مجموعة "${groupName}".`;
      const writer = db.bulkWriter();
      for (const memberId of memberIds) {
        if (memberId === founderId) continue;
        // A stable ID makes a retry safe if notification writing succeeded
        // before a later recursive delete failure.
        writer.set(db.collection("users").doc(memberId).collection("notifications")
          .doc(`group_disbanded_${groupId}`), {
            title: "تم تفكيك المجموعة",
            body: body.slice(0, 1000),
            type: "group_disbanded",
            refId: groupId,
            senderId: founderId,
            commentId: null,
            createdAt: FieldValue.serverTimestamp(),
            isRead: false,
          });
      }
      await writer.close();
    }

    await db.recursiveDelete(groupRef);
    return { ok: true, alreadyDeleted: false };
  } catch (error) {
    callableError(error);
  }
});

function messagePreview(message, senderName, includeSender) {
  const text = typeof message.text === "string" ? message.text.trim().slice(0, MAX_NOTIFICATION_TEXT) : "";
  const prefix = includeSender ? `${senderName}: ` : "";
  if (text) return `${prefix}${text}`;
  const media = { image: "🖼️ صورة", gif: "🎞️ GIF", sticker: "🏷️ ملصق", audio: "🎤 رسالة صوتية", video: "🎥 فيديو" };
  return `${prefix}${media[message.mediaType] || "📎 ملف"}`;
}

async function removeInvalidToken(db, userId, token, error) {
  const invalid = error && (
    error.code === "messaging/registration-token-not-registered" ||
    error.code === "messaging/invalid-registration-token"
  );
  if (!invalid || !validId(userId) || typeof token !== "string") return;
  // Do not erase a freshly rotated token after an old send fails.
  await db.runTransaction(async (tx) => {
    const ref = db.collection("users").doc(userId);
    const snap = await tx.get(ref);
    if (snap.exists && snap.data().fcmToken === token) {
      tx.update(ref, { fcmToken: FieldValue.delete() });
    }
  }).catch(() => {});
}

exports.onNewGroupMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  async (event) => {
    const message = event.data && event.data.data();
    const groupId = event.params.groupId;
    const messageId = event.params.messageId;
    const db = getFirestore();

    if (!message || typeof message !== "object" || message.type === 'systemEvent' || !validId(message.senderId)) return;
    if (typeof message.text !== "undefined" && typeof message.text !== "string") return;
    if (message.text && message.text.length > 4000) return;
    if (message.mediaType && typeof message.mediaType !== "string") return;
    const groupRef = db.collection("groups").doc(groupId);
    const [groupDoc, senderDoc, senderMember] = await Promise.all([
      groupRef.get(), db.collection("users").doc(message.senderId).get(), groupRef.collection("members").doc(message.senderId).get(),
    ]);
    if (!groupDoc.exists || !senderDoc.exists || !senderMember.exists) return;

    const membersSnap = await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .get();

    const senderId = message.senderId;
    const recipients = [];

    for (const memberDoc of membersSnap.docs) {
      const memberId = memberDoc.id;
      if (memberId === senderId) continue;
      if (memberId === 'system') continue;

      const userDoc = await db.collection("users").doc(memberId).get();
      const token = userDoc.data()?.fcmToken;
      if (typeof token === "string" && token.length <= 4096) recipients.push({ memberId, token });
    }

    if (recipients.length === 0) return;

    const senderName = displayText(senderDoc.data()?.username, "شخص ما");
    const groupName = displayText(groupDoc.data()?.name, "مجموعة");

    const body = messagePreview(message, senderName, true);

    const sound = randomSound();

    // FCM accepts at most 500 registration tokens per multicast request.
    for (let offset = 0; offset < recipients.length; offset += 500) {
      const chunk = recipients.slice(offset, offset + 500);
      const result = await getMessaging().sendEachForMulticast({
        tokens: chunk.map(({ token }) => token),
        notification: { title: groupName, body },
        android: {
          notification: {
            sound,
            channelId: `pubget_reply_group`,
          },
        },
        data: {
          type: 'group_chat',
          refId: groupId,
          senderId: senderId,
          senderName: senderName,
          contextName: groupName,
          commentId: '',
          messageId: messageId,
        },
      });
      await Promise.all(result.responses.map((response, index) =>
        response.success ? null : removeInvalidToken(db, chunk[index].memberId, chunk[index].token, response.error)
      ));
    }
  }
);

exports.onNewPrivateMessage = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data && event.data.data();
    const senderId = message.senderId;
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const db = getFirestore();

    if (!message || typeof message !== "object" || !validId(senderId) ||
        (typeof message.text !== "undefined" && (typeof message.text !== "string" || message.text.length > 4000)) ||
        (typeof message.mediaType !== "undefined" && typeof message.mediaType !== "string")) return;
    const chatDoc = await db.collection("privateChats").doc(chatId).get();
    if (!chatDoc.exists) return;
    const userA = chatDoc.data()?.userA;
    const userB = chatDoc.data()?.userB;

    if (!validId(userA) || !validId(userB) || userA === userB || (senderId !== userA && senderId !== userB)) return;
    const receiverId = userA === senderId ? userB : userA;

    const userDoc = await db.collection("users").doc(receiverId).get();
    const token = userDoc.data()?.fcmToken;
    if (typeof token !== "string" || token.length > 4096) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    if (!senderDoc.exists) return;
    const senderName = displayText(senderDoc.data()?.username, "شخص ما");

    const body = messagePreview(message, senderName, false);

    const sound = randomSound();

    await getMessaging().send({
      token,
      notification: { title: senderName, body },
      android: {
        notification: {
          sound,
          channelId: `pubget_reply_private`,
        },
      },
      data: {
        type: 'private_chat',
        refId: chatId,
        senderId: senderId,
        senderName: senderName,
        contextName: senderName,
        commentId: '',
        messageId: messageId,
      },
    }).catch(async (error) => {
      await removeInvalidToken(db, receiverId, token, error);
    });
  }
);

exports.onJoinRequest = onDocumentCreated(
  "groups/{groupId}/requests/{requestId}",
  async (event) => {
    const request = event.data && event.data.data();
    const groupId = event.params.groupId;
    const db = getFirestore();

    if (!request || typeof request !== "object" || !validId(request.userId) ||
        (typeof request.status !== "undefined" && request.status !== "pending")) return;
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;
    const groupData = groupDoc.data() || {};
    const ownerId = groupData.founderId || groupData.ownerId;
    const groupName = displayText(groupDoc.data()?.name, "مجموعة");
    if (!validId(ownerId)) return;

    const ownerDoc = await db.collection("users").doc(ownerId).get();
    const token = ownerDoc.data()?.fcmToken;
    if (typeof token !== "string" || token.length > 4096) return;

    const requesterDoc = await db
      .collection("users")
      .doc(request.userId)
      .get();
    if (!requesterDoc.exists) return;
    const requesterName = displayText(requesterDoc.data()?.username, "شخص ما");

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
        messageId: '',
      },
    }).catch(async (error) => {
      await removeInvalidToken(db, ownerId, token, error);
    });
  }
);

// ══════════════════════════════════════════════════════════════
// ✅ لعبة المافيا (مجلد منفصل تماماً src/mafia/)
// ══════════════════════════════════════════════════════════════
const lobbyManager = require("./src/mafia/lobbyManager");
const phaseScheduler = require("./src/mafia/phaseScheduler");
const disconnectHandler = require("./src/mafia/disconnectHandler");
const mafiaLeaveGame = require("./src/mafia/leaveGame");

exports.processExpiredLobbies = lobbyManager.processExpiredLobbies;
exports.processPhaseTransitions = phaseScheduler.processPhaseTransitions;
exports.markDisconnectedPlayers = disconnectHandler.markDisconnectedPlayers;
exports.leaveMafiaGame = onCall({ region: "us-central1" }, mafiaLeaveGame.leaveMafiaGame);