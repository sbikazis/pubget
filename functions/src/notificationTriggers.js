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

  return {
    groupMessage,
    joinRequest,
    joinDecision,
    friendRequest,
    respectReceived,
  };
}

module.exports = { createNotificationTriggers };