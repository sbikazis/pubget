"use strict";

const MESSAGE_TYPES = new Set([
  "text", "image", "video", "sticker", "gif", "audio",
  "system", "event", "game",
]);
const USER_MESSAGE_TYPES = new Set([
  "text", "image", "video", "sticker", "gif", "audio",
]);
const MEDIA_TYPES = new Set(["image", "video", "sticker", "gif", "audio"]);
const STICKER_CATALOG = Object.freeze({
  "reactions/heart": { category: "reactions", name: "Heart" },
  "reactions/laugh": { category: "reactions", name: "Laugh" },
  "reactions/wow": { category: "reactions", name: "Wow" },
  "reactions/sad": { category: "reactions", name: "Sad" },
  "reactions/fire": { category: "reactions", name: "Fire" },
  "gestures/wave": { category: "gestures", name: "Wave" },
  "gestures/thumbsup": { category: "gestures", name: "Thumbs up" },
  "gestures/clap": { category: "gestures", name: "Clap" },
  "gestures/bow": { category: "gestures", name: "Bow" },
  "pubget/torii": { category: "pubget", name: "Torii" },
  "pubget/spark": { category: "pubget", name: "Spark" },
  "pubget/moon": { category: "pubget", name: "Moon" },
});
const REPORT_REASONS = Object.freeze([
  "inappropriate", "spam", "copyright", "harassment", "other",
]);
const AUDIO_MAX_BYTES = 10 * 1024 * 1024;
const AUDIO_MAX_DURATION_SECONDS = 60;
const { hasPermission, normalizeRole } = require("./pubgetRanks");

const PERMISSIONS = {
  delete: "deleteMessages",
  pin: "pinOwnMessages",
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

function can(member, role, permission, group) {
  return hasPermission(member, role, permission, group);
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
    groupRef(db, groupId).collection("roles").doc(memberData.role || "ronin"),
  );
  return {
    group: group.data() || {},
    member: memberData,
    role: role.exists ? role.data() : null,
  };
}

function expectedMediaType(type) {
  if (type === "video") return "video";
  if (type === "audio") return "audio";
  return "image";
}

function isCatalogSticker(data) {
  return data && data.type === "sticker" &&
    typeof data.stickerKey === "string" &&
    Object.hasOwn(STICKER_CATALOG, data.stickerKey);
}

function resolveStickerCreator(data, uid, identity) {
  if (!data || data.type !== "sticker") {
    return { stickerCreatorId: null, stickerCreatorName: null };
  }
  if (isCatalogSticker(data)) {
    return { stickerCreatorId: "pubget", stickerCreatorName: "Pubget" };
  }
  const creatorId = validString(data.stickerCreatorId, 128)
    ? data.stickerCreatorId.trim()
    : uid;
  const creatorName = validString(data.stickerCreatorName, 80)
    ? data.stickerCreatorName.trim()
    : identity.senderName;
  return { stickerCreatorId: creatorId, stickerCreatorName: creatorName };
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
  if (isCatalogSticker(data)) return;
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

function replyPreviewFrom(message) {
  if (!message || message.deletedAt) return "Original message unavailable";
  if (message.type === "text" && typeof message.text === "string") {
    return message.text.trim().slice(0, 80);
  }
  if (message.stickerKey) return "[sticker]";
  return `[${message.type || "message"}]`;
}

function previewText(data) {
  if (data.type === "text") return data.text.trim().slice(0, 80);
  if (data.stickerKey) return "[sticker]";
  return `[${data.type}]`;
}

function assertReadyMedia(media, uid, type, HttpsError) {
  const expectedType = expectedMediaType(type);
  if (!media || media.status !== "ready" || media.uploaderId !== uid ||
      media.mediaType !== expectedType ||
      !validString(media.originalPath, 1024)) {
    throw new HttpsError(
      "failed-precondition",
      "Media must finish processing and belong to the sender.",
    );
  }
  if (expectedType === "image" &&
      (!validString(media.thumbnailPath, 1024) ||
        !validString(media.mediumPath, 1024))) {
    throw new HttpsError(
      "failed-precondition",
      "Media must finish processing and belong to the sender.",
    );
  }
  if (expectedType === "video" && !validString(media.thumbnailPath, 1024)) {
    throw new HttpsError(
      "failed-precondition",
      "Media must finish processing and belong to the sender.",
    );
  }
}

function createGroupChat({ db, FieldValue, HttpsError, bucket, randomUUID, achievements }) {
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
      let replyPreview = null;
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
        replyPreview = replyPreviewFrom(reply.data());
      }
      let media = null;
      const catalogSticker = isCatalogSticker(data);
      if (MEDIA_TYPES.has(data.type) && !catalogSticker) {
        const mediaSnapshot = await transaction.get(
          groupRef(db, groupId).collection("media").doc(data.mediaId),
        );
        media = mediaSnapshot.exists ? mediaSnapshot.data() : null;
        assertReadyMedia(media, uid, data.type, HttpsError);
      }
      const identity = displayIdentity(context.member, uid);
      const recipientCount = Math.max(0, (context.group.membersCount || 1) - 1);
      const stickerCreator = resolveStickerCreator(data, uid, identity);
      const message = {
        senderId: uid,
        senderName: identity.senderName,
        senderAvatar: identity.senderAvatar,
        senderRole: context.member.role || "ronin",
        type: data.type,
        text: data.type === "text" ? data.text.trim() : null,
        mediaId: catalogSticker || !MEDIA_TYPES.has(data.type) ? null : data.mediaId,
        mediaUrl: media
          ? (media.mediumPath || media.originalPath)
          : null,
        thumbnailUrl: media ? media.thumbnailPath || null : null,
        stickerKey: catalogSticker ? data.stickerKey : null,
        stickerCreatorId: stickerCreator.stickerCreatorId,
        stickerCreatorName: stickerCreator.stickerCreatorName,
        replyToMessageId: data.replyToMessageId || null,
        replyPreview,
        forwardedFrom: null,
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
        lastMessageText: previewText(data),
      });
      response = message;
    });
    if (achievements && typeof achievements.evaluate === "function") {
      // Fire-and-forget: do not block the send callable on achievements work.
      // Awaiting this made clients keep the pending clock longer than needed.
      achievements.evaluate({
        type: "message_sent",
        userId: uid,
        source: "group_chat",
        metadata: { groupId, messageId },
      }).catch(() => {});
    }
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

  async function forwardMessage(request) {
    const uid = requireAuth(request, HttpsError);
    const sourceGroupId = request.data && request.data.sourceGroupId;
    const messageId = request.data && request.data.messageId;
    const destinationGroupId = request.data && request.data.destinationGroupId;
    const destinationChatId = request.data && request.data.destinationChatId;
    if (!validString(sourceGroupId, 128) || !validString(messageId, 128)) {
      throw new HttpsError("invalid-argument", "sourceGroupId and messageId are required.");
    }
    const destIsGroup = validString(destinationGroupId, 128);
    const destIsPrivate = validString(destinationChatId, 128);
    if (destIsGroup === destIsPrivate) {
      throw new HttpsError(
        "invalid-argument",
        "Provide exactly one destination: destinationGroupId or destinationChatId.",
      );
    }
    const destMessageId = typeof randomUUID === "function"
      ? randomUUID()
      : `${Date.now()}_${uid}`;
    const sourceSnap = await messageRef(db, sourceGroupId, messageId).get();
    if (!sourceSnap.exists) throw new HttpsError("not-found", "Message not found.");
    const source = sourceSnap.data() || {};
    if (source.deletedAt) {
      throw new HttpsError("failed-precondition", "Deleted messages cannot be forwarded.");
    }
    if (!USER_MESSAGE_TYPES.has(source.type)) {
      throw new HttpsError("failed-precondition", "This message cannot be forwarded.");
    }

    const sourceMember = await memberRef(db, sourceGroupId, uid).get();
    if (!sourceMember.exists) {
      throw new HttpsError("permission-denied", "You are not a group member.");
    }

    let destMedia = null;
    let destMediaId = null;
    if (MEDIA_TYPES.has(source.type) && source.mediaId && !source.stickerKey) {
      const sourceMedia = await groupRef(db, sourceGroupId)
        .collection("media").doc(source.mediaId).get();
      if (!sourceMedia.exists) {
        throw new HttpsError("failed-precondition", "Source media is unavailable.");
      }
      destMediaId = destMessageId;
      destMedia = await copyMediaRecord({
        source: sourceMedia.data() || {},
        destCollection: destIsGroup ? "groups" : "privateChats",
        destOwnerId: destIsGroup ? destinationGroupId : destinationChatId,
        destMediaId,
        uid,
        bucket,
      });
    }

    let response;
    await db.runTransaction(async (transaction) => {
      if (destIsGroup) {
        const context = await actorContext(
          transaction, db, destinationGroupId, uid, HttpsError,
        );
        const destRef = messageRef(db, destinationGroupId, destMessageId);
        const existing = await transaction.get(destRef);
        if (existing.exists) {
          response = existing.data();
          return;
        }
        if (destMedia && destMediaId) {
          transaction.set(
            groupRef(db, destinationGroupId).collection("media").doc(destMediaId),
            destMedia,
          );
        }
        const identity = {
          ...displayIdentity(context.member, uid),
          senderRole: context.member.role || "ronin",
        };
        const message = buildForwardedMessage({
          source,
          uid,
          identity,
          destMedia,
          destMediaId,
          recipientCount: Math.max(0, (context.group.membersCount || 1) - 1),
          forwardedFrom: {
            groupId: sourceGroupId,
            messageId,
          },
          FieldValue,
        });
        transaction.create(destRef, message);
        transaction.update(groupRef(db, destinationGroupId), {
          lastMessageAt: FieldValue.serverTimestamp(),
          lastMessageText: previewText({
            type: source.type,
            text: source.text,
            stickerKey: source.stickerKey,
          }),
        });
        response = message;
        return;
      }

      const chatRef = db.collection("privateChats").doc(destinationChatId);
      const chatSnap = await transaction.get(chatRef);
      if (!chatSnap.exists) throw new HttpsError("not-found", "Chat not found.");
      const chat = chatSnap.data() || {};
      const participants = Array.isArray(chat.participantIds)
        ? chat.participantIds
        : [chat.userA, chat.userB].filter(Boolean);
      if (!participants.includes(uid)) {
        throw new HttpsError("permission-denied", "You are not a chat participant.");
      }
      const destRef = chatRef.collection("messages").doc(destMessageId);
      const existing = await transaction.get(destRef);
      if (existing.exists) {
        response = existing.data();
        return;
      }
      if (destMedia && destMediaId) {
        transaction.set(chatRef.collection("media").doc(destMediaId), destMedia);
      }
      const sender = await transaction.get(db.collection("users").doc(uid));
      const senderData = sender.exists ? sender.data() || {} : {};
      const identity = {
        senderName: validString(senderData.displayName, 80)
          ? senderData.displayName.trim()
          : uid,
        senderAvatar: typeof senderData.avatarUrl === "string"
          ? senderData.avatarUrl
          : "",
      };
      const message = buildForwardedMessage({
        source,
        uid,
        identity: { ...identity, senderRole: "" },
        destMedia,
        destMediaId,
        recipientCount: 1,
        forwardedFrom: {
          groupId: sourceGroupId,
          messageId,
        },
        FieldValue,
      });
      transaction.create(destRef, message);
      transaction.update(chatRef, {
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageText: previewText({
          type: source.type,
          text: source.text,
          stickerKey: source.stickerKey,
        }),
        lastMessageSenderId: uid,
      });
      response = message;
    });
    return {
      ok: true,
      messageId: destMessageId,
      message: { ...response, createdAt: new Date().toISOString() },
    };
  }

  async function reportMessage(request) {
    const reporterId = requireAuth(request, HttpsError);
    const groupId = request.data && request.data.groupId;
    const messageId = request.data && request.data.messageId;
    const reason = REPORT_REASONS.includes(request.data && request.data.reason)
      ? request.data.reason
      : null;
    const details = typeof (request.data && request.data.details) === "string"
      ? request.data.details.trim().slice(0, 500)
      : "";
    if (!validString(groupId, 128) || !validString(messageId, 128) || !reason) {
      throw new HttpsError(
        "invalid-argument",
        "A structured report reason is required.",
      );
    }
    const member = await memberRef(db, groupId, reporterId).get();
    if (!member.exists) {
      throw new HttpsError("permission-denied", "You are not a group member.");
    }
    const message = await messageRef(db, groupId, messageId).get();
    if (!message.exists) throw new HttpsError("not-found", "Message not found.");
    if (message.data().senderId === reporterId) {
      throw new HttpsError("failed-precondition", "You cannot report your own message.");
    }
    const reportId = `${messageId}_${reporterId}`;
    const reportRef = groupRef(db, groupId).collection("messageReports").doc(reportId);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(reportRef);
      if (existing.exists) return;
      transaction.create(reportRef, {
        reporterId,
        messageId,
        reason,
        details,
        status: "open",
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, reportId };
  }

  return {
    addReaction,
    deleteMessage,
    editMessage,
    forwardMessage,
    markMessagesRead,
    markMessagesDelivered,
    pinMessage,
    reportMessage,
    sendMessage,
    updateBackground,
  };
}

function buildForwardedMessage({
  source, uid, identity, destMedia, destMediaId, recipientCount, forwardedFrom,
  FieldValue,
}) {
  return {
    senderId: uid,
    senderName: identity.senderName,
    senderAvatar: identity.senderAvatar,
    senderRole: identity.senderRole || "ronin",
    type: source.type,
    text: source.type === "text" ? source.text : null,
    mediaId: destMediaId,
    mediaUrl: destMedia
      ? (destMedia.mediumPath || destMedia.originalPath)
      : source.stickerKey ? null : source.mediaUrl || null,
    thumbnailUrl: destMedia ? destMedia.thumbnailPath || null : null,
    stickerKey: source.stickerKey || null,
    stickerCreatorId: source.stickerCreatorId || null,
    stickerCreatorName: source.stickerCreatorName || null,
    replyToMessageId: null,
    replyPreview: null,
    forwardedFrom,
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
}

async function copyMediaRecord({
  source, destCollection, destOwnerId, destMediaId, uid, bucket,
}) {
  const extension = (source.originalPath || "bin").split(".").pop() || "bin";
  const destOriginal =
    `${destCollection}/${destOwnerId}/media/${destMediaId}_original.${extension}`;
  const destThumb = source.thumbnailPath
    ? `${destCollection}/${destOwnerId}/media/${destMediaId}_thumb.jpg`
    : null;
  const destMedium = source.mediumPath
    ? `${destCollection}/${destOwnerId}/media/${destMediaId}_medium.jpg`
    : null;
  if (bucket && typeof bucket.file === "function" && source.originalPath) {
    await bucket.file(source.originalPath).copy(bucket.file(destOriginal));
    if (destThumb && source.thumbnailPath) {
      await bucket.file(source.thumbnailPath).copy(bucket.file(destThumb));
    }
    if (destMedium && source.mediumPath) {
      await bucket.file(source.mediumPath).copy(bucket.file(destMedium));
    }
  } else if (source.originalPath) {
    // Unit tests and local fakes still write dest metadata pointing at source
    // paths when no bucket is configured.
  }
  return {
    mediaId: destMediaId,
    uploaderId: uid,
    mediaType: source.mediaType,
    originalPath: source.originalPath ? destOriginal : source.originalPath,
    thumbnailPath: destThumb,
    mediumPath: destMedium,
    status: "ready",
    copiedFrom: source.originalPath || null,
    createdAt: new Date(),
  };
}

const ADMIN_CARD_TYPES = new Set(["system", "event", "game"]);

function adminChatCardDocument({ type, text, mediaId, extra }) {
  return {
    senderId: "system",
    senderName: "Pubget",
    senderAvatar: "",
    senderRole: "system",
    type,
    text: String(text || "").slice(0, 200),
    mediaId: mediaId || null,
    mediaUrl: null,
    thumbnailUrl: null,
    replyToMessageId: null,
    createdAt: null,
    editedAt: null,
    deletedAt: null,
    pinnedAt: null,
    reactions: {},
    reactionUsers: {},
    recipientCount: 0,
    deliveredCount: 0,
    readCount: 0,
    deliveredBy: {},
    readBy: {},
    ...(extra && typeof extra === "object" ? extra : {}),
  };
}

async function writeAdminChatCard(db, FieldValue, {
  groupId, type, text, mediaId, messageId, extra,
}) {
  if (!validString(groupId, 128) || !ADMIN_CARD_TYPES.has(type)) return null;
  const id = validString(messageId, 128) ? messageId.trim() : undefined;
  const ref = groupRef(db, groupId.trim()).collection("messages").doc(id);
  const message = adminChatCardDocument({ type, text, mediaId, extra });
  message.createdAt = FieldValue.serverTimestamp();
  await ref.set(message);
  try {
    await groupRef(db, groupId.trim()).update({
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageText: String(text || `[${type}]`).slice(0, 80),
    });
  } catch (_) {
    // Card write is authoritative even if the group preview update is skipped.
  }
  return ref.id;
}

module.exports = {
  ADMIN_CARD_TYPES,
  AUDIO_MAX_BYTES,
  AUDIO_MAX_DURATION_SECONDS,
  MEDIA_TYPES,
  MESSAGE_TYPES,
  REPORT_REASONS,
  STICKER_CATALOG,
  USER_MESSAGE_TYPES,
  adminChatCardDocument,
  createGroupChat,
  expectedMediaType,
  resolveStickerCreator,
  validString,
  validateMessage,
  writeAdminChatCard,
};