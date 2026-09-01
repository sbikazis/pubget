"use strict";

// Private 1:1 chat callables.
//
// Reused from PROMPT 07 (groupChat.js): validString, validateMessage,
// MEDIA_TYPES, USER_MESSAGE_TYPES, message field layout, aggregate delivery
// receipts (deliveredBy/readBy + deliveredCount/readCount, batches of 50),
// media readiness check (status === ready, uploader owns the asset).
// Reused from PROMPT 05 (socialGraph.js): pairId / respectId length-prefixed
// identifiers, legacy `_` fallback with participant matching, FAN_THRESHOLD,
// block status on friendships.
// New here: Fan-or-Friend gate on start, whoCanMessageMe (related|friends),
// Block re-checked on every send, deterministic chatId = pairId(uid, other).

const {
  FAN_THRESHOLD,
  legacyPairId,
  legacyRespectId,
  matchesLegacyFriendship,
  matchesLegacyRespect,
  pairId,
  respectId,
  validUid,
} = require("./socialGraph");
const {
  MEDIA_TYPES,
  validString,
  validateMessage,
} = require("./groupChat");

const WHO_CAN_MESSAGE = new Set(["related", "friends"]);
const CHAT_ID_MAX = 320;

function requireAuth(request, HttpsError) {
  if (!request || !request.auth || !validUid(request.auth.uid)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function chatRef(db, chatId) {
  return db.collection("privateChats").doc(chatId);
}

function messageRef(db, chatId, messageId) {
  return chatRef(db, chatId).collection("messages").doc(messageId);
}

function mediaRef(db, chatId, mediaId) {
  return chatRef(db, chatId).collection("media").doc(mediaId);
}

function messageIds(request, HttpsError) {
  const chatId = request.data && request.data.chatId;
  const messageId = request.data && request.data.messageId;
  if (!validString(chatId, CHAT_ID_MAX) || !validString(messageId, 128)) {
    throw new HttpsError("invalid-argument", "chatId and messageId are required.");
  }
  return { chatId: chatId.trim(), messageId: messageId.trim() };
}

function requireMessageIdBatch(request, HttpsError) {
  const chatId = request.data && request.data.chatId;
  const ids = request.data && request.data.messageIds;
  if (!validString(chatId, CHAT_ID_MAX) || !Array.isArray(ids) ||
      ids.length < 1 || ids.length > 50 ||
      ids.some((id) => !validString(id, 128))) {
    throw new HttpsError("invalid-argument", "Provide between 1 and 50 messageIds.");
  }
  return { chatId: chatId.trim(), messageIds: ids.map((id) => id.trim()) };
}

function participantIdsOf(data) {
  if (Array.isArray(data.participantIds) && data.participantIds.length === 2) {
    return data.participantIds;
  }
  return [data.userA, data.userB].filter(Boolean);
}

function isParticipant(data, uid) {
  return data.userA === uid || data.userB === uid ||
    participantIdsOf(data).includes(uid);
}

function otherParticipant(data, uid) {
  if (data.userA === uid) return data.userB;
  if (data.userB === uid) return data.userA;
  return participantIdsOf(data).find((id) => id !== uid);
}

function displayNameOf(user, uid) {
  if (user && validString(user.username, 80)) return user.username.trim();
  if (user && validString(user.displayName, 80)) return user.displayName.trim();
  return uid;
}

async function requireUsers(transaction, db, userIds, HttpsError) {
  const snapshots = await Promise.all(
    userIds.map((uid) => transaction.get(db.collection("users").doc(uid))),
  );
  if (snapshots.some((snapshot) => !snapshot.exists)) {
    throw new HttpsError("not-found", "One of the profiles no longer exists.");
  }
  return snapshots;
}

async function readFriendship(transaction, db, uid, otherUserId) {
  const [userA, userB] = [uid, otherUserId].sort();
  const [relation, legacy] = await Promise.all([
    transaction.get(db.collection("friendships").doc(pairId(uid, otherUserId))),
    transaction.get(
      db.collection("friendships").doc(legacyPairId(uid, otherUserId)),
    ),
  ]);
  const matchingLegacy = legacy.exists &&
      matchesLegacyFriendship(legacy.data(), userA, userB)
    ? legacy
    : null;
  return relation.exists ? relation : matchingLegacy;
}

async function respectValue(transaction, db, fromUserId, toUserId) {
  const [canonical, legacy] = await Promise.all([
    transaction.get(
      db.collection("respects").doc(respectId(fromUserId, toUserId)),
    ),
    transaction.get(
      db.collection("respects").doc(legacyRespectId(fromUserId, toUserId)),
    ),
  ]);
  if (canonical.exists && Number.isInteger(canonical.data().value)) {
    return canonical.data().value;
  }
  const matchingLegacy = legacy.exists &&
      matchesLegacyRespect(legacy.data(), fromUserId, toUserId)
    ? legacy
    : null;
  if (matchingLegacy && Number.isInteger(matchingLegacy.data().value)) {
    return matchingLegacy.data().value;
  }
  return 0;
}

async function isFanEitherDirection(transaction, db, uid, otherUserId) {
  const [forward, reverse] = await Promise.all([
    respectValue(transaction, db, uid, otherUserId),
    respectValue(transaction, db, otherUserId, uid),
  ]);
  return forward >= FAN_THRESHOLD || reverse >= FAN_THRESHOLD;
}

async function relationshipState(transaction, db, uid, otherUserId) {
  const friendship = await readFriendship(transaction, db, uid, otherUserId);
  const status = friendship && friendship.exists
    ? friendship.data().status
    : null;
  const blocked = status === "blocked";
  const friend = status === "accepted";
  const fan = await isFanEitherDirection(transaction, db, uid, otherUserId);
  return { friendship, blocked, friend, fan };
}

function assertNotBlocked(state, HttpsError) {
  if (state.blocked) {
    throw new HttpsError(
      "permission-denied",
      "Messaging is unavailable for a blocked relationship.",
    );
  }
}

function assertCanStartChat(state, recipient, HttpsError) {
  assertNotBlocked(state, HttpsError);
  if (!state.friend && !state.fan) {
    throw new HttpsError(
      "permission-denied",
      "A Fan or Friend relationship is required to start a private chat.",
    );
  }
  const policy = recipient && WHO_CAN_MESSAGE.has(recipient.whoCanMessageMe)
    ? recipient.whoCanMessageMe
    : "related";
  if (policy === "friends" && !state.friend) {
    throw new HttpsError(
      "permission-denied",
      "This user only accepts messages from Friends.",
    );
  }
}

async function requireParticipantChat(transaction, db, chatId, uid, HttpsError) {
  const snapshot = await transaction.get(chatRef(db, chatId));
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Chat not found.");
  }
  const data = snapshot.data() || {};
  if (!isParticipant(data, uid)) {
    throw new HttpsError("permission-denied", "You are not a participant.");
  }
  return { snapshot, data };
}

function previewText(data) {
  return data.type === "text"
    ? data.text.trim().slice(0, 80)
    : `[${data.type}]`;
}

function createPrivateChat({ db, FieldValue, HttpsError }) {
  async function startPrivateChat(request) {
    const uid = requireAuth(request, HttpsError);
    const otherUserId = request.data && request.data.otherUserId;
    if (!validUid(otherUserId)) {
      throw new HttpsError("invalid-argument", "otherUserId is invalid.");
    }
    if (uid === otherUserId.trim()) {
      throw new HttpsError("invalid-argument", "You cannot message yourself.");
    }
    const targetId = otherUserId.trim();
    const chatId = pairId(uid, targetId);
    const [userA, userB] = [uid, targetId].sort();
    const ref = chatRef(db, chatId);
    let created = false;

    await db.runTransaction(async (transaction) => {
      const users = await requireUsers(transaction, db, [uid, targetId], HttpsError);
      const state = await relationshipState(transaction, db, uid, targetId);
      const recipient = users[1].data() || {};
      assertCanStartChat(state, recipient, HttpsError);
      const existing = await transaction.get(ref);
      if (existing.exists) {
        const hiddenFor = (existing.data() || {}).hiddenFor || {};
        if (hiddenFor[uid]) {
          transaction.update(ref, { [`hiddenFor.${uid}`]: FieldValue.delete() });
        }
        return;
      }
      const caller = users[0].data() || {};
      transaction.create(ref, {
        participantIds: [userA, userB],
        userA,
        userB,
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageText: "",
        lastMessageSenderId: "",
        createdAt: FieldValue.serverTimestamp(),
        hiddenFor: {},
        participants: {
          [uid]: {
            displayName: displayNameOf(caller, uid),
            avatarUrl: typeof caller.avatarUrl === "string" ? caller.avatarUrl : "",
            lastReadAt: FieldValue.serverTimestamp(),
          },
          [targetId]: {
            displayName: displayNameOf(recipient, targetId),
            avatarUrl: typeof recipient.avatarUrl === "string"
              ? recipient.avatarUrl
              : "",
            lastReadAt: null,
          },
        },
      });
      created = true;
    });
    return { ok: true, chatId, created };
  }

  async function sendPrivateMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { chatId, messageId } = messageIds(request, HttpsError);
    const data = request.data || {};
    validateMessage(data, HttpsError);
    const ref = messageRef(db, chatId, messageId);
    let response;
    await db.runTransaction(async (transaction) => {
      const { data: chat } = await requireParticipantChat(
        transaction, db, chatId, uid, HttpsError,
      );
      const otherUserId = otherParticipant(chat, uid);
      if (!validUid(otherUserId)) {
        throw new HttpsError("failed-precondition", "Chat participants are invalid.");
      }
      const state = await relationshipState(transaction, db, uid, otherUserId);
      assertNotBlocked(state, HttpsError);

      const existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data().senderId !== uid) {
          throw new HttpsError("already-exists", "messageId is already in use.");
        }
        response = existing.data();
        return;
      }
      if (data.replyToMessageId !== undefined && data.replyToMessageId !== null) {
        if (!validString(data.replyToMessageId, 128)) {
          throw new HttpsError("invalid-argument", "replyToMessageId is invalid.");
        }
        const reply = await transaction.get(
          messageRef(db, chatId, data.replyToMessageId),
        );
        if (!reply.exists) {
          throw new HttpsError("not-found", "Reply target not found.");
        }
      }
      let media = null;
      if (MEDIA_TYPES.has(data.type)) {
        const mediaSnapshot = await transaction.get(
          mediaRef(db, chatId, data.mediaId),
        );
        media = mediaSnapshot.exists ? mediaSnapshot.data() : null;
        const expectedType = data.type === "video" ? "video" : "image";
        if (!media || media.status !== "ready" ||
            media.uploaderId !== uid || media.mediaType !== expectedType ||
            !validString(media.originalPath, 1024) ||
            !validString(media.thumbnailPath, 1024) ||
            (expectedType === "image" && !validString(media.mediumPath, 1024))) {
          throw new HttpsError(
            "failed-precondition",
            "Media must finish processing and belong to the sender.",
          );
        }
      }
      const users = await requireUsers(transaction, db, [uid], HttpsError);
      const sender = users[0].data() || {};
      const message = {
        senderId: uid,
        senderName: displayNameOf(sender, uid),
        senderAvatar: typeof sender.avatarUrl === "string" ? sender.avatarUrl : "",
        senderRole: "",
        type: data.type,
        text: data.type === "text" ? data.text.trim() : null,
        mediaId: MEDIA_TYPES.has(data.type) ? data.mediaId : null,
        mediaUrl: media ? (media.mediumPath || media.originalPath) : null,
        thumbnailUrl: media ? media.thumbnailPath : null,
        replyToMessageId: data.replyToMessageId || null,
        createdAt: FieldValue.serverTimestamp(),
        editedAt: null,
        deletedAt: null,
        pinnedAt: null,
        reactions: {},
        reactionUsers: {},
        recipientCount: 1,
        deliveredCount: 0,
        readCount: 0,
        deliveredBy: {},
        readBy: {},
      };
      transaction.create(ref, message);
      const chatUpdate = {
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageText: previewText(data),
        lastMessageSenderId: uid,
        [`hiddenFor.${uid}`]: FieldValue.delete(),
        [`hiddenFor.${otherUserId}`]: FieldValue.delete(),
      };
      transaction.update(chatRef(db, chatId), chatUpdate);
      response = message;
    });
    return {
      ok: true,
      messageId,
      message: { ...response, createdAt: new Date().toISOString() },
    };
  }

  async function deleteMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { chatId, messageId } = messageIds(request, HttpsError);
    const ref = messageRef(db, chatId, messageId);
    await db.runTransaction(async (transaction) => {
      await requireParticipantChat(transaction, db, chatId, uid, HttpsError);
      const message = await transaction.get(ref);
      if (!message.exists) throw new HttpsError("not-found", "Message not found.");
      const current = message.data() || {};
      if (current.senderId !== uid) {
        throw new HttpsError("permission-denied", "You cannot delete this message.");
      }
      if (current.deletedAt) return;
      transaction.update(ref, {
        text: null,
        mediaUrl: null,
        thumbnailUrl: null,
        deletedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function markMessagesRead(request) {
    const uid = requireAuth(request, HttpsError);
    const { chatId, messageIds: ids } = requireMessageIdBatch(request, HttpsError);
    await db.runTransaction(async (transaction) => {
      await requireParticipantChat(transaction, db, chatId, uid, HttpsError);
      const refs = ids.map((id) => messageRef(db, chatId, id));
      const snapshots = await Promise.all(refs.map((item) => transaction.get(item)));
      snapshots.forEach((snapshot, index) => {
        if (!snapshot.exists) return;
        const message = snapshot.data() || {};
        if (message.senderId === uid || message.deletedAt) return;
        const deliveredBy = { ...(message.deliveredBy || {}), [uid]: true };
        const readBy = { ...(message.readBy || {}), [uid]: true };
        transaction.update(refs[index], {
          deliveredBy,
          readBy,
          deliveredCount: Object.keys(deliveredBy).length,
          readCount: Object.keys(readBy).length,
        });
      });
      transaction.update(chatRef(db, chatId), {
        [`participants.${uid}.lastReadAt`]: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function markMessagesDelivered(request) {
    const uid = requireAuth(request, HttpsError);
    const { chatId, messageIds: ids } = requireMessageIdBatch(request, HttpsError);
    await db.runTransaction(async (transaction) => {
      await requireParticipantChat(transaction, db, chatId, uid, HttpsError);
      const refs = ids.map((id) => messageRef(db, chatId, id));
      const snapshots = await Promise.all(refs.map((item) => transaction.get(item)));
      snapshots.forEach((snapshot, index) => {
        if (!snapshot.exists) return;
        const message = snapshot.data() || {};
        if (message.senderId === uid || message.deletedAt ||
            (message.deliveredBy && message.deliveredBy[uid])) return;
        const deliveredBy = { ...(message.deliveredBy || {}), [uid]: true };
        transaction.update(refs[index], {
          deliveredBy,
          deliveredCount: Object.keys(deliveredBy).length,
        });
      });
    });
    return { ok: true };
  }

  async function deleteChat(request) {
    const uid = requireAuth(request, HttpsError);
    const chatId = request.data && request.data.chatId;
    if (!validString(chatId, CHAT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "chatId is required.");
    }
    await db.runTransaction(async (transaction) => {
      await requireParticipantChat(transaction, db, chatId.trim(), uid, HttpsError);
      transaction.update(chatRef(db, chatId.trim()), {
        [`hiddenFor.${uid}`]: true,
      });
    });
    return { ok: true };
  }

  return {
    startPrivateChat,
    sendPrivateMessage,
    deleteMessage,
    markMessagesRead,
    markMessagesDelivered,
    deleteChat,
  };
}

module.exports = {
  CHAT_ID_MAX,
  createPrivateChat,
  privateChatId: pairId,
};
