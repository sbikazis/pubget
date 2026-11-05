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

  async function respectReceived(event) {
    const data = event.data && event.data.data();
    if (!data || !data.toUserId || !data.fromUserId) return;
    return builder.build({
      id: `respect_received_${event.params.respectId}`,
      recipientIds: [data.toUserId],
      type: "respect_received",
      actorId: data.fromUserId,
      targetId: data.toUserId,
      action: "respect_received",
      destination: `/profile?uid=${encodeURIComponent(data.fromUserId)}`,
      metadata: { value: data.value || 0 },
      groupKey: `respect_received_${data.toUserId}`,
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
    if (!after || after.status !== "published" || after.moderationStatus !== "approved" || (before && before.status === "published")) return;
    const reelId = event.params.reelId;
    const creatorId = after.creatorId;
    if (!creatorId) return;
    const followers = await db.collection("respects").where("toUserId", "==", creatorId).where("value", ">=", 5).limit(100).get();
    let recipientIds = [...new Set(followers.docs.map((doc) => doc.data()?.fromUserId).filter((uid) => uid && uid !== creatorId))];
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
    if (!comment || comment.status !== "published") return;
    const reelId = event.params.reelId;
    const reel = await db.collection("kirari").doc(reelId).get();
    if (!reel.exists) return;
    const creatorId = reel.data()?.creatorId;
    if (!creatorId || creatorId === comment.authorId) return;
    const [blockedPair, mutedAuthor] = await Promise.all([
      db.collection("friendships").doc(
        [creatorId, comment.authorId].sort().map((id) => id.length + ":" + id).join(""),
      ).get().catch(() => null),
      db.collection("users").doc(creatorId).collection("kirariMutedCreators")
        .doc(comment.authorId).get().catch(() => null),
    ]);
    if ((blockedPair && blockedPair.exists && blockedPair.data()?.status === "blocked") ||
        (mutedAuthor && mutedAuthor.exists)) return;
    return builder.build({
      id: "kirari_comment_" + event.params.commentId, recipientIds: [creatorId],
      type: "kirari_comment", actorId: comment.authorId, targetId: reelId,
      action: "comment_created", destination: "/reel/" + encodeURIComponent(reelId),
      metadata: { commentId: event.params.commentId }, groupKey: "kirari_comments_" + reelId,
      pushWorthy: false, title: "New comment",
      body: String(comment.text || "Someone commented on your video").slice(0, 180),
    });
  }
  return {
    kirariPublished,
    kirariComment,
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