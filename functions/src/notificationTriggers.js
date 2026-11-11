"use strict";

function createNotificationTriggers({ db, builder }) {
  async function groupMessage(event) {
    const message = event.data && event.data.data();
    if (!message || !message.senderId || message.type === "system") return;
    const groupId = event.params.groupId;
    const messageId = event.params.messageId;
    const groupRef = db.collection("groups").doc(groupId);
    const [group, members, sender] = await Promise.all([
      groupRef.get(),
      groupRef.collection("members").get(),
      db.collection("users").doc(message.senderId).get(),
    ]);
    if (!group.exists || !sender.exists) return;
    const recipientIds = members.docs.map((doc) => doc.id)
      .filter((uid) => uid !== message.senderId && uid !== "system");
    if (!recipientIds.length) return;
    const senderName = sender.data()?.username || "شخص ما";
    const groupName = group.data()?.name || "مجموعة";
    const body = typeof message.text === "string" && message.text.trim()
      ? `${senderName}: ${message.text.trim().slice(0, 240)}`
      : `${senderName}: رسالة جديدة`;
    return builder.build({
      id: `group_message_${groupId}_${messageId}`,
      recipientIds,
      type: "group_message",
      actorId: message.senderId,
      targetId: groupId,
      action: "message_created",
      destination: `/group-chat?groupId=${encodeURIComponent(groupId)}`,
      metadata: { messageId },
      groupKey: `group_message_${groupId}`,
      title: groupName,
      body,
    });
  }

  async function joinRequest(event) {
    const request = event.data && event.data.data();
    if (!request) return;
    const groupId = event.params.groupId;
    const group = await db.collection("groups").doc(groupId).get();
    if (!group.exists) return;
    const ownerId = group.data()?.founderId || group.data()?.ownerId;
    const requesterId = request.userId || request.uid || event.params.requestId;
    if (!ownerId || !requesterId) return;
    return builder.build({
      id: `join_request_${groupId}_${event.params.requestId}`,
      recipientIds: [ownerId],
      type: "join_request",
      actorId: requesterId,
      targetId: groupId,
      action: "join_requested",
      destination: `/group-requests?groupId=${encodeURIComponent(groupId)}`,
      metadata: { requestId: event.params.requestId },
      groupKey: `join_request_${groupId}`,
      title: group.data()?.name || "مجموعة",
      body: "لديك طلب انضمام جديد",
    });
  }

  async function friendRequest(event) {
    const data = event.data && event.data.data();
    if (!data || data.status !== "pending" || !data.requestedBy) return;
    const recipientIds = (data.userIds || [data.userA, data.userB])
      .filter((uid) => uid && uid !== data.requestedBy);
    if (!recipientIds.length) return;
    return builder.build({
      id: `friend_request_${event.params.friendshipId}`,
      recipientIds,
      type: "friend_request",
      actorId: data.requestedBy,
      targetId: event.params.friendshipId,
      action: "friend_requested",
      destination: "/friend-requests",
      metadata: {},
      groupKey: `friend_request_${event.params.friendshipId}`,
      body: "لديك طلب صداقة جديد",
    });
  }

  async function joinDecision(event) {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!before || !after || before.status === after.status ||
        after.status !== "accepted") {
      return;
    }
    const groupId = event.params.groupId;
    const recipientId = after.userId || after.uid || event.params.requestId;
    const group = await db.collection("groups").doc(groupId).get();
    if (!group.exists || !recipientId) return;
    return builder.build({
      id: `request_accepted_${groupId}_${event.params.requestId}`,
      recipientIds: [recipientId],
      type: "request_accepted",
      actorId: after.decidedBy || null,
      targetId: groupId,
      action: "join_accepted",
      destination: `/group?groupId=${encodeURIComponent(groupId)}`,
      metadata: { requestId: event.params.requestId },
      groupKey: `join_decision_${groupId}`,
      title: group.data()?.name || "مجموعة",
      body: "تم قبول طلب انضمامك",
    });
  }

  async function privateMessage(event) {
    const message = event.data && event.data.data();
    if (!message || !message.senderId || message.deletedAt ||
        message.type === "system") {
      return;
    }
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const chat = await db.collection("privateChats").doc(chatId).get();
    if (!chat.exists) return;
    const data = chat.data() || {};
    const participants = Array.isArray(data.participantIds)
      ? data.participantIds
      : [data.userA, data.userB];
    const recipientIds = participants.filter(
      (uid) => uid && uid !== message.senderId,
    );
    if (!recipientIds.length) return;
    const sender = await db.collection("users").doc(message.senderId).get();
    const senderName = (sender.exists && sender.data()?.username) ||
      message.senderName ||
      "شخص ما";
    const body = typeof message.text === "string" && message.text.trim()
      ? message.text.trim().slice(0, 240)
      : "رسالة خاصة جديدة";
    return builder.build({
      id: `private_message_${chatId}_${messageId}`,
      recipientIds,
      type: "private_message",
      actorId: message.senderId,
      targetId: chatId,
      action: "message_created",
      destination: `/private-chat?chatId=${encodeURIComponent(chatId)}`,
      metadata: { messageId },
      groupKey: `private_message_${chatId}`,
      title: senderName,
      body,
    });
  }

  function friendshipDocumentId(first, second) {
    const [userA, userB] = [first, second].sort();
    return userA.length + ":" + userA + userB.length + ":" + userB;
  }

  async function isBlockedPair(first, second) {
    if (!first || !second || first === second) return false;
    const relation = await db.collection("friendships")
      .doc(friendshipDocumentId(first, second)).get().catch(() => null);
    return Boolean(relation && relation.exists &&
      relation.data()?.status === "blocked");
  }

  async function isMuted(recipientId, actorId) {
    const muted = await db.collection("users").doc(recipientId)
      .collection("kirariMutedCreators").doc(actorId).get().catch(() => null);
    return Boolean(muted && muted.exists);
  }

  async function respectReceived(event) {
    const after = event.data && event.data.after && event.data.after.data();
    const before = event.data && event.data.before && event.data.before.data();
    if (!after || !after.toUserId || !after.fromUserId ||
        after.fromUserId === after.toUserId ||
        !(Number(after.value) > 0) ||
        (before && before.value === after.value)) return;
    if (await isBlockedPair(after.fromUserId, after.toUserId)) return;
    return builder.build({
      id: "respect_received_" + event.params.respectId + "_" + event.id,
      recipientIds: [after.toUserId],
      type: "respect_received",
      actorId: after.fromUserId,
      targetId: after.toUserId,
      action: "respect_received",
      destination: "/profile?uid=" + encodeURIComponent(after.fromUserId),
      metadata: { value: after.value },
      groupKey: "respect_received_" + after.toUserId,
      pushWorthy: true,
      body: "تلقيت Respect جديدًا",
    });
  }

  async function friendAccepted(event) {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!before || !after || before.status === after.status ||
        after.status !== "accepted" || !after.requestedBy) {
      return;
    }
    const participants = after.userIds || [after.userA, after.userB];
    const accepterId = participants.find((uid) =>
      uid && uid !== after.requestedBy);
    if (!accepterId) return;
    return builder.build({
      id: `friend_accepted_${event.params.friendshipId}`,
      recipientIds: [after.requestedBy],
      type: "friend_accepted",
      actorId: accepterId,
      targetId: event.params.friendshipId,
      action: "friend_accepted",
      destination: `/profile?uid=${encodeURIComponent(accepterId)}`,
      metadata: {},
      groupKey: `friend_accepted_${event.params.friendshipId}`,
      pushWorthy: true,
      title: "Pubget",
      body: "تم قبول طلب الصداقة",
    });
  }

  async function kirariPublished(event) {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!after || after.status !== "published" ||
        after.moderationStatus !== "approved" ||
        (before && before.status === "published" &&
          before.moderationStatus === "approved")) return;
    const reelId = event.params.reelId;
    const creatorId = after.creatorId;
    if (!creatorId) return;
    const followerQuery = db.collection("respects")
      .where("toUserId", "==", creatorId)
      .where("value", ">=", 5);
    let followerPage = await followerQuery.limit(200).get();
    const followerDocs = [...(followerPage.docs || [])];
    while ((followerPage.docs || []).length === 200) {
      followerPage = await followerQuery
        .startAfter(followerPage.docs[followerPage.docs.length - 1])
        .limit(200).get();
      followerDocs.push(...(followerPage.docs || []));
    }
    let recipientIds = [...new Set(followerDocs
      .map((doc) => doc.data()?.fromUserId)
      .filter((uid) => uid && uid !== creatorId))];
    if (!recipientIds.length) return;
    const [muted, creatorBlocksA, creatorBlocksB] = await Promise.all([
      db.collectionGroup("kirariMutedCreators").where("creatorId", "==", creatorId).get(),
      db.collection("friendships").where("userA", "==", creatorId).get(),
      db.collection("friendships").where("userB", "==", creatorId).get(),
    ]);
    const excluded = new Set([
      ...(muted.docs || []).map((doc) => doc.ref.parent.parent?.id).filter(Boolean),
      ...(creatorBlocksA.docs || []).filter((doc) => doc.data()?.status === "blocked").map((doc) => doc.data()?.userB),
      ...(creatorBlocksB.docs || []).filter((doc) => doc.data()?.status === "blocked").map((doc) => doc.data()?.userA),
    ]);
    recipientIds = recipientIds.filter((uid) => !excluded.has(uid));
    const blockedByRecipient = await Promise.all(recipientIds.map(async (fanId) => {
      const [userA, userB] = [creatorId, fanId].sort();
      const pairId = userA.length + ":" + userA + userB.length + ":" + userB;
      const pair = await db.collection("friendships").doc(pairId).get().catch(() => null);
      return pair && pair.exists && pair.data()?.status === "blocked" ? fanId : null;
    }));
    const blockedIds = new Set(blockedByRecipient.filter(Boolean));
    recipientIds = recipientIds.filter((uid) => !blockedIds.has(uid));
    if (!recipientIds.length) return;
    return builder.build({
      id: "kirari_published_" + reelId, recipientIds, type: "kirari_published",
      actorId: creatorId, targetId: reelId, action: "reel_published",
      destination: "/reel/" + encodeURIComponent(reelId),
      metadata: { audioId: after.audioId || null }, groupKey: "kirari_creator_" + creatorId,
      pushWorthy: false, title: "Kirari", body: String(after.caption || "New video").slice(0, 180),
    });
  }

  async function kirariComment(event) {
    const comment = event.data && event.data.data();
    if (!comment || comment.status !== "published" || !comment.authorId) return;
    const reelId = event.params.reelId;
    const reel = await db.collection("kirari").doc(reelId).get();
    if (!reel.exists || reel.data()?.status !== "published" ||
        reel.data()?.moderationStatus !== "approved") return;
    const creatorId = reel.data()?.creatorId;
    const recipients = new Set();
    if (creatorId) recipients.add(creatorId);
    if (comment.parentId) {
      const parent = await db.collection("kirari").doc(reelId)
        .collection("comments").doc(comment.parentId).get();
      if (parent.exists && parent.data()?.status === "published" &&
          parent.data()?.authorId) recipients.add(parent.data().authorId);
    }
    recipients.delete(comment.authorId);
    const allowed = [];
    for (const recipientId of recipients) {
      const [blockedAuthor, mutedAuthor, blockedCreator] = await Promise.all([
        isBlockedPair(recipientId, comment.authorId),
        isMuted(recipientId, comment.authorId),
        creatorId && creatorId !== comment.authorId
          ? isBlockedPair(recipientId, creatorId) : Promise.resolve(false),
      ]);
      if (!blockedAuthor && !mutedAuthor && !blockedCreator) allowed.push(recipientId);
    }
    if (!allowed.length) return;
    return builder.build({
      id: "kirari_comment_" + event.params.commentId,
      recipientIds: allowed,
      type: comment.parentId ? "kirari_comment_reply" : "kirari_comment",
      actorId: comment.authorId, targetId: reelId,
      action: comment.parentId ? "comment_replied" : "comment_created",
      destination: "/reel/" + encodeURIComponent(reelId),
      metadata: { commentId: event.params.commentId, parentId: comment.parentId || null },
      groupKey: "kirari_comments_" + reelId,
      pushWorthy: false, title: comment.parentId ? "New reply" : "New comment",
      body: String(comment.text || "Someone commented on your video").slice(0, 180),
    });
  }

  async function kirariLike(event) {
    const actionData = event.data && event.data.data();
    if (!actionData || actionData.kind !== "like" || !actionData.uid) return;
    const reelId = event.params.reelId;
    const reel = await db.collection("kirari").doc(reelId).get();
    if (!reel.exists || reel.data()?.status !== "published" ||
        reel.data()?.moderationStatus !== "approved") return;
    const creatorId = reel.data()?.creatorId;
    const actorId = actionData.uid;
    if (!creatorId || creatorId === actorId) return;
    const [blocked, muted] = await Promise.all([
      isBlockedPair(creatorId, actorId),
      isMuted(creatorId, actorId),
    ]);
    if (blocked || muted) return;
    return builder.build({
      id: "kirari_like_" + reelId + "_" + event.id,
      recipientIds: [creatorId],
      type: "kirari_like",
      actorId,
      targetId: reelId,
      action: "reel_liked",
      destination: "/reel/" + encodeURIComponent(reelId),
      metadata: { actionId: event.params.actionId },
      groupKey: "kirari_likes_" + reelId,
      pushWorthy: false,
      title: "Kirari",
      body: "Someone liked your video",
    });
  }

  async function kirariCommentLike(event) {
    const reel = await db.collection("kirari").doc(event.params.reelId).get();
    if (!reel.exists || reel.data()?.status !== "published" ||
        reel.data()?.moderationStatus !== "approved") return;
    const comment = await db.collection("kirari").doc(event.params.reelId)
      .collection("comments").doc(event.params.commentId).get();
    if (!comment.exists || comment.data()?.status !== "published") return;
    const recipientId = comment.data()?.authorId;
    const actorId = event.params.uid;
    if (!recipientId || !actorId || recipientId === actorId) return;
    const [blocked, muted] = await Promise.all([
      isBlockedPair(recipientId, actorId),
      isMuted(recipientId, actorId),
    ]);
    if (blocked || muted) return;
    return builder.build({
      id: "kirari_comment_like_" + event.params.reelId + "_" +
        event.params.commentId + "_" + event.id,
      recipientIds: [recipientId],
      type: "kirari_comment_like",
      actorId,
      targetId: event.params.reelId,
      action: "comment_liked",
      destination: "/reel/" + encodeURIComponent(event.params.reelId),
      metadata: { commentId: event.params.commentId },
      groupKey: "kirari_comment_likes_" + event.params.commentId,
      pushWorthy: false,
      title: "Kirari",
      body: "Someone liked your comment",
    });
  }

  return {
    kirariPublished,
    kirariComment,
    kirariLike,
    kirariCommentLike,
    groupMessage,
    privateMessage,
    joinRequest,
    joinDecision,
    friendRequest,
    friendAccepted,
    respectReceived,
  };
}

module.exports = { createNotificationTriggers };