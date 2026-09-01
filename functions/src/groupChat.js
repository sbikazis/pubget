"use strict";

const MESSAGE_TYPES = new Set([
  "text", "image", "video", "sticker", "gif", "audio",
  "system", "event", "game",
]);
const USER_MESSAGE_TYPES = new Set([
  "text", "image", "video", "sticker", "gif", "audio",
]);
const MEDIA_TYPES = new Set(["image", "video", "sticker", "gif", "audio"]);
const PERMISSIONS = {
  delete: "deleteMessages",
  pin: "pin",
  background: "manageBackground",
};

function validString(value, max) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= max;
}

function requireAuth(request, HttpsError) {
  if (!request || !request.auth || !validString(request.auth.uid, 128)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function groupRef(db, groupId) {
  return db.collection("groups").doc(groupId);
}

function memberRef(db, groupId, uid) {
  return groupRef(db, groupId).collection("members").doc(uid);
}

function messageRef(db, groupId, messageId) {
  return groupRef(db, groupId).collection("messages").doc(messageId);
}

function ids(request, HttpsError) {
  const groupId = request.data && request.data.groupId;
  const messageId = request.data && request.data.messageId;
  if (!validString(groupId, 128) || !validString(messageId, 128)) {
    throw new HttpsError("invalid-argument", "groupId and messageId are required.");
  }
  return { groupId: groupId.trim(), messageId: messageId.trim() };
}

function displayIdentity(member, uid) {
  const character = member.roleplayCharacter;
  const senderName = character && validString(character.name, 80)
    ? character.name.trim()
    : validString(member.displayName, 80)
      ? member.displayName.trim()
      : validString(member.realUserName, 80)
        ? member.realUserName.trim()
        : uid;
  const senderAvatar = character && typeof character.avatarUrl === "string"
    ? character.avatarUrl
    : typeof member.realUserImageUrl === "string"
      ? member.realUserImageUrl
      : "";
  return { senderName, senderAvatar };
}

function can(member, role, permission) {
  return member.role === "founder" ||
    Boolean(role && Array.isArray(role.permissions) &&
      role.permissions.includes(permission));
}

async function actorContext(transaction, db, groupId, uid, HttpsError) {
  const group = await transaction.get(groupRef(db, groupId));
  const member = await transaction.get(memberRef(db, groupId, uid));
  if (!group.exists) throw new HttpsError("not-found", "Group not found.");
  if (!member.exists) {
    throw new HttpsError("permission-denied", "You are not a group member.");
  }
  const memberData = member.data() || {};
  const role = await transaction.get(
    groupRef(db, groupId).collection("roles").doc(memberData.role || "member"),
  );
  return {
    group: group.data() || {},
    member: memberData,
    role: role.exists ? role.data() : null,
  };
}

function validateMessage(data, HttpsError) {
  if (!MESSAGE_TYPES.has(data.type) || !USER_MESSAGE_TYPES.has(data.type)) {
    throw new HttpsError("invalid-argument", "This message type is server-only or invalid.");
  }
  if (data.type === "text") {
    if (!validString(data.text, 4000)) {
      throw new HttpsError("invalid-argument", "Text must be between 1 and 4000 characters.");
    }
    return;
  }
  if (!MEDIA_TYPES.has(data.type)) {
    throw new HttpsError("invalid-argument", "A processed media upload is required.");
  }
  if (!validString(data.mediaId, 128)) {
    throw new HttpsError("invalid-argument", "mediaId is required.");
  }
  if (data.thumbnailUrl !== undefined && data.thumbnailUrl !== null &&
      !validString(data.thumbnailUrl, 2048)) {
    throw new HttpsError("invalid-argument", "thumbnailUrl is invalid.");
  }
}

function createGroupChat({ db, FieldValue, HttpsError }) {
  async function sendMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { groupId, messageId } = ids(request, HttpsError);
    const data = request.data || {};
    validateMessage(data, HttpsError);
    const ref = messageRef(db, groupId, messageId);
    let response;
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, db, groupId, uid, HttpsError);
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
          messageRef(db, groupId, data.replyToMessageId),
        );
        if (!reply.exists) {
          throw new HttpsError("not-found", "Reply target not found.");
        }
      }
      let media = null;
      if (MEDIA_TYPES.has(data.type)) {
        const mediaSnapshot = await transaction.get(
          groupRef(db, groupId).collection("media").doc(data.mediaId),
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
      const identity = displayIdentity(context.member, uid);
      const recipientCount = Math.max(0, (context.group.membersCount || 1) - 1);
      const message = {
        senderId: uid,
        senderName: identity.senderName,
        senderAvatar: identity.senderAvatar,
        senderRole: context.member.role || "member",
        type: data.type,
        text: data.type === "text" ? data.text.trim() : null,
        mediaId: MEDIA_TYPES.has(data.type) ? data.mediaId : null,
        mediaUrl: media
          ? (media.mediumPath || media.originalPath)
          : null,
        thumbnailUrl: media ? media.thumbnailPath : null,
        replyToMessageId: data.replyToMessageId || null,
        createdAt: FieldValue.serverTimestamp(),
        editedAt: null,
        deletedAt: null,
        pinnedAt: null,
        reactions: {},
        reactionUsers: {},
        recipientCount,
        deliveredCount: 0,
        readCount: 0,
        deliveredBy: {},
        readBy: {},
      };
      transaction.create(ref, message);
      transaction.update(groupRef(db, groupId), {
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageText: data.type === "text"
          ? data.text.trim().slice(0, 80)
          : `[${data.type}]`,
      });
      response = message;
    });
    return {
      ok: true,
      messageId,
      message: { ...response, createdAt: new Date().toISOString() },
    };
  }

  async function editMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { groupId, messageId } = ids(request, HttpsError);
    const text = request.data && request.data.text;
    if (!validString(text, 4000)) {
      throw new HttpsError("invalid-argument", "Text must be between 1 and 4000 characters.");
    }
    const ref = messageRef(db, groupId, messageId);
    await db.runTransaction(async (transaction) => {
      await actorContext(transaction, db, groupId, uid, HttpsError);
      const message = await transaction.get(ref);
      if (!message.exists) throw new HttpsError("not-found", "Message not found.");
      const current = message.data() || {};
      if (current.senderId !== uid || current.type !== "text" ||
          current.deletedAt) {
        throw new HttpsError("permission-denied", "This message cannot be edited.");
      }
      transaction.update(ref, {
        text: text.trim(),
        editedAt: FieldValue.serverTimestamp(),
      });
    });
    const current = await ref.get();
    return { ok: true, message: current.data() };
  }

  async function deleteMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { groupId, messageId } = ids(request, HttpsError);
    const ref = messageRef(db, groupId, messageId);
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, db, groupId, uid, HttpsError);
      const message = await transaction.get(ref);
      if (!message.exists) throw new HttpsError("not-found", "Message not found.");
      const current = message.data() || {};
      if (current.senderId !== uid &&
          !can(context.member, context.role, PERMISSIONS.delete)) {
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

  async function pinMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const { groupId, messageId } = ids(request, HttpsError);
    const pinned = request.data && request.data.pinned;
    if (typeof pinned !== "boolean") {
      throw new HttpsError("invalid-argument", "pinned must be a boolean.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, db, groupId, uid, HttpsError);
      if (!can(context.member, context.role, PERMISSIONS.pin)) {
        throw new HttpsError("permission-denied", "You cannot pin messages.");
      }
      const ref = messageRef(db, groupId, messageId);
      const message = await transaction.get(ref);
      if (!message.exists || message.data().deletedAt) {
        throw new HttpsError("not-found", "Message not found.");
      }
      transaction.update(ref, {
        pinnedAt: pinned ? FieldValue.serverTimestamp() : null,
      });
    });
    return { ok: true };
  }

  async function addReaction(request) {
    const uid = requireAuth(request, HttpsError);
    const { groupId, messageId } = ids(request, HttpsError);
    const reaction = request.data && request.data.reaction;
    if (!validString(reaction, 16)) {
      throw new HttpsError("invalid-argument", "Reaction is invalid.");
    }
    await db.runTransaction(async (transaction) => {
      await actorContext(transaction, db, groupId, uid, HttpsError);
      const ref = messageRef(db, groupId, messageId);
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data().deletedAt) {
        throw new HttpsError("not-found", "Message not found.");
      }
      const message = snapshot.data() || {};
      const reactionUsers = { ...(message.reactionUsers || {}) };
      const users = { ...(reactionUsers[reaction] || {}) };
      const reactions = { ...(message.reactions || {}) };
      if (users[uid]) {
        delete users[uid];
      } else {
        users[uid] = true;
      }
      reactionUsers[reaction] = users;
      reactions[reaction] = Object.keys(users).length;
      transaction.update(ref, { reactions, reactionUsers });
    });
    return { ok: true };
  }

  async function markMessagesRead(request) {
    const uid = requireAuth(request, HttpsError);
    const groupId = request.data && request.data.groupId;
    const messageIds = request.data && request.data.messageIds;
    if (!validString(groupId, 128) || !Array.isArray(messageIds) ||
        messageIds.length < 1 || messageIds.length > 50 ||
        messageIds.some((id) => !validString(id, 128))) {
      throw new HttpsError("invalid-argument", "Provide between 1 and 50 messageIds.");
    }
    await db.runTransaction(async (transaction) => {
      await actorContext(transaction, db, groupId, uid, HttpsError);
      const refs = messageIds.map((id) => messageRef(db, groupId, id));
      const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
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
      transaction.update(memberRef(db, groupId, uid), {
        lastReadAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function markMessagesDelivered(request) {
    const uid = requireAuth(request, HttpsError);
    const groupId = request.data && request.data.groupId;
    const messageIds = request.data && request.data.messageIds;
    if (!validString(groupId, 128) || !Array.isArray(messageIds) ||
        messageIds.length < 1 || messageIds.length > 50 ||
        messageIds.some((id) => !validString(id, 128))) {
      throw new HttpsError("invalid-argument", "Provide between 1 and 50 messageIds.");
    }
    await db.runTransaction(async (transaction) => {
      await actorContext(transaction, db, groupId, uid, HttpsError);
      const refs = messageIds.map((id) => messageRef(db, groupId, id));
      const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
      snapshots.forEach((snapshot, index) => {
        if (!snapshot.exists) return;
        const message = snapshot.data() || {};
        if (message.senderId === uid || message.deletedAt ||
            message.deliveredBy && message.deliveredBy[uid]) return;
        const deliveredBy = { ...(message.deliveredBy || {}), [uid]: true };
        transaction.update(refs[index], {
          deliveredBy,
          deliveredCount: Object.keys(deliveredBy).length,
        });
      });
    });
    return { ok: true };
  }

  async function updateBackground(request) {
    const uid = requireAuth(request, HttpsError);
    const groupId = request.data && request.data.groupId;
    const backgroundUrl = request.data && request.data.backgroundUrl;
    if (!validString(groupId, 128) ||
        (backgroundUrl !== null && backgroundUrl !== undefined &&
          !validString(backgroundUrl, 2048))) {
      throw new HttpsError("invalid-argument", "Background selection is invalid.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, db, groupId, uid, HttpsError);
      if (!can(context.member, context.role, PERMISSIONS.background)) {
        throw new HttpsError("permission-denied", "You cannot change the background.");
      }
      transaction.update(groupRef(db, groupId), {
        chatBackgroundUrl: backgroundUrl || null,
      });
    });
    return { ok: true };
  }

  return {
    addReaction,
    deleteMessage,
    editMessage,
    markMessagesRead,
    markMessagesDelivered,
    pinMessage,
    sendMessage,
    updateBackground,
  };
}

module.exports = {
  MEDIA_TYPES,
  MESSAGE_TYPES,
  USER_MESSAGE_TYPES,
  createGroupChat,
  validString,
  validateMessage,
};