// functions/index.js
//
// ✅ الإضافة الوحيدة: تصدير disconnectHandler، بنفس نمط الإضافات
// السابقة تماماً — بقية الملف (الإشعارات + lobbyManager + phaseScheduler)
// دون أي تغيير آخر.

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { randomUUID } = require("node:crypto");
const {
  createAvatarPrivacySync,
  createUpdateSocialProfile,
} = require("./src/avatarPrivacy");
const {
  buildPublicProfile,
  shouldPublishProfile,
} = require("./src/publicProfile");
const { createSocialGraph } = require("./src/socialGraph");
const { createGroupsDomain } = require("./src/groupsDomain");
const { createGroupChat } = require("./src/groupChat");
const { createPrivateChat } = require("./src/privateChat");
const { createGroupMediaPipeline } = require("./src/groupMediaPipeline");
const { createNotificationBuilder } = require("./src/notificationBuilder");
const { createNotificationCallables } = require("./src/notificationCallables");
const { createNotificationTriggers } = require("./src/notificationTriggers");
const { createDiscoveryScheduler, onSchedule } = require("./src/discoveryEngine");
const { createRecommendationEngine } = require("./src/recommendationEngine");
const { createAnimeListsDomain } = require("./src/animeListsDomain");
const { createEditsDomain } = require("./src/editsDomain");
const { createEditPipeline } = require("./src/editPipeline");
const { createEventsDomain } = require("./src/eventsDomain");
const { createGamesDomain } = require("./src/gamesDomain");
const { createFanWorksDomain } = require("./src/fanWorksDomain");
const { createEconomyDomain } = require("./src/economyDomain");
const { createAchievementsDomain } = require("./src/achievementsDomain");
const { createMafiaDomain } = require("./src/mafia/mafiaDomain");

initializeApp();

exports.syncAvatarPrivacy = onDocumentWritten(
  "users/{uid}",
  createAvatarPrivacySync({
    db: getFirestore(),
    bucket: getStorage().bucket(),
    randomUUID,
  }),
);
exports.updateSocialProfile = onCall(
  { region: "us-central1" },
  createUpdateSocialProfile({
    db: getFirestore(),
    bucket: getStorage().bucket(),
    randomUUID,
    HttpsError,
  }),
);

exports.syncPublicProfile = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const after = event.data && event.data.after;
  const publicRef = getFirestore().collection("public_profiles").doc(uid);

  if (!after || !after.exists) {
    await publicRef.delete();
    return;
  }

  const data = after.data();
  if (!shouldPublishProfile(data)) {
    await publicRef.delete();
    return;
  }

  // Full replacement is intentional: fields removed from the allowlist or
  // source cannot linger in the public projection.
  await publicRef.set(buildPublicProfile(data));
});

const groupChat = createGroupChat({
  db: getFirestore(),
  FieldValue,
  HttpsError,
});
const privateChat = createPrivateChat({
  db: getFirestore(),
  FieldValue,
  HttpsError,
});
const notificationBuilder = createNotificationBuilder({
  db: getFirestore(),
  messaging: getMessaging(),
  FieldValue,
});
const economyDomain = createEconomyDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  notificationBuilder,
});
const achievementsDomain = createAchievementsDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  economy: economyDomain,
  notificationBuilder,
});
const socialGraph = createSocialGraph({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  achievements: achievementsDomain,
});
const groupsDomain = createGroupsDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  randomUUID,
  achievements: achievementsDomain,
});
const eventsDomain = createEventsDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  notificationBuilder,
  economy: economyDomain,
  achievements: achievementsDomain,
});
const gamesDomain = createGamesDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  notificationBuilder,
  economy: economyDomain,
  achievements: achievementsDomain,
});
const mafiaDomain = createMafiaDomain({
  db: getFirestore(),
  FieldValue,
  Timestamp,
  HttpsError,
  notificationBuilder,
});
const fanWorksDomain = createFanWorksDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  notificationBuilder,
  storage: getStorage().bucket(),
  economy: economyDomain,
  achievements: achievementsDomain,
});
const notificationCallables = createNotificationCallables({
  db: getFirestore(),
  FieldValue,
  HttpsError,
});
const notificationTriggers = createNotificationTriggers({
  db: getFirestore(),
  builder: notificationBuilder,
});
const discoveryScheduler = createDiscoveryScheduler({
  db: getFirestore(),
  FieldValue,
});
const recommendationEngine = createRecommendationEngine({
  db: getFirestore(),
  HttpsError,
});
const animeListsDomain = createAnimeListsDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
});
const editsDomain = createEditsDomain({
  db: getFirestore(),
  FieldValue,
  HttpsError,
  achievements: achievementsDomain,
});

exports.refreshGroupActivityScores = onSchedule(
  { schedule: "every 1 hours", region: "us-central1" },
  discoveryScheduler.updateScores,
);
exports.getDiscoveryFeed = onCall(
  { region: "us-central1" },
  recommendationEngine.getDiscoveryFeed,
);
exports.setAnimeListEntry = onCall(
  { region: "us-central1" },
  animeListsDomain.setAnimeListEntry,
);
exports.removeAnimeListEntry = onCall(
  { region: "us-central1" },
  animeListsDomain.removeAnimeListEntry,
);
exports.getAnimeList = onCall(
  { region: "us-central1" },
  animeListsDomain.getAnimeList,
);
exports.setCharacterFavorite = onCall(
  { region: "us-central1" },
  animeListsDomain.setCharacterFavorite,
);
exports.getCharacterFavorites = onCall(
  { region: "us-central1" },
  animeListsDomain.getCharacterFavorites,
);
exports.startEditUpload = onCall(
  { region: "us-central1" },
  editsDomain.startUpload,
);
exports.repostEdit = onCall(
  { region: "us-central1" },
  editsDomain.repost,
);
exports.deleteEdit = onCall(
  { region: "us-central1" },
  editsDomain.deleteEdit,
);
exports.likeEdit = onCall(
  { region: "us-central1" },
  editsDomain.like,
);
exports.addEditComment = onCall(
  { region: "us-central1" },
  editsDomain.comment,
);
exports.startEditPlayback = onCall(
  { region: "us-central1" },
  editsDomain.startPlayback,
);
exports.recordEditView = onCall(
  { region: "us-central1" },
  editsDomain.recordView,
);
exports.recordEditSignal = onCall(
  { region: "us-central1" },
  editsDomain.signal,
);
exports.editCommentAction = onCall(
  { region: "us-central1" },
  editsDomain.commentAction,
);
exports.processEditVideo = onObjectFinalized(
  { region: "europe-west3", memory: "1GiB", timeoutSeconds: 300 },
  createEditPipeline({
    db: getFirestore(),
    bucket: getStorage().bucket(),
    economy: economyDomain,
    achievements: achievementsDomain,
  }),
);

exports.createGroup = onCall({ region: "us-central1" }, groupsDomain.createGroup);
exports.createGroupInvite = onCall(
  { region: "us-central1" },
  groupsDomain.createInvite,
);
exports.joinGroup = onCall({ region: "us-central1" }, groupsDomain.joinGroup);
exports.requestToJoin = onCall({ region: "us-central1" }, groupsDomain.requestToJoin);
exports.leaveGroup = onCall({ region: "us-central1" }, groupsDomain.leaveGroup);
exports.acceptJoinRequest = onCall(
  { region: "us-central1" },
  groupsDomain.acceptJoinRequest,
);
exports.rejectJoinRequest = onCall(
  { region: "us-central1" },
  groupsDomain.rejectJoinRequest,
);
exports.changeRole = onCall({ region: "us-central1" }, groupsDomain.changeRole);
exports.updateRolePermissions = onCall(
  { region: "us-central1" },
  groupsDomain.updateRolePermissions,
);
exports.kickMember = onCall({ region: "us-central1" }, groupsDomain.kickMember);
exports.banMember = onCall({ region: "us-central1" }, groupsDomain.banMember);
exports.transferOwnership = onCall(
  { region: "us-central1" },
  groupsDomain.transferOwnership,
);
exports.prepareOwnershipTransfer = onCall(
  { region: "us-central1" },
  groupsDomain.prepareOwnershipTransfer,
);
exports.reserveRoleplayCharacter = onCall(
  { region: "us-central1" },
  groupsDomain.reserveRoleplayCharacter,
);
exports.releaseRoleplayCharacter = onCall(
  { region: "us-central1" },
  groupsDomain.releaseRoleplayCharacter,
);
exports.sendGroupMessage = onCall(
  { region: "us-central1" },
  groupChat.sendMessage,
);
exports.editGroupMessage = onCall(
  { region: "us-central1" },
  groupChat.editMessage,
);
exports.deleteGroupMessage = onCall(
  { region: "us-central1" },
  groupChat.deleteMessage,
);
exports.pinGroupMessage = onCall(
  { region: "us-central1" },
  groupChat.pinMessage,
);
exports.addGroupMessageReaction = onCall(
  { region: "us-central1" },
  groupChat.addReaction,
);
exports.markGroupMessagesRead = onCall(
  { region: "us-central1" },
  groupChat.markMessagesRead,
);
exports.markGroupMessagesDelivered = onCall(
  { region: "us-central1" },
  groupChat.markMessagesDelivered,
);
exports.updateGroupChatBackground = onCall(
  { region: "us-central1" },
  groupChat.updateBackground,
);
exports.startPrivateChat = onCall(
  { region: "us-central1" },
  privateChat.startPrivateChat,
);
exports.sendPrivateMessage = onCall(
  { region: "us-central1" },
  privateChat.sendPrivateMessage,
);
exports.deletePrivateMessage = onCall(
  { region: "us-central1" },
  privateChat.deleteMessage,
);
exports.markPrivateMessagesRead = onCall(
  { region: "us-central1" },
  privateChat.markMessagesRead,
);
exports.markPrivateMessagesDelivered = onCall(
  { region: "us-central1" },
  privateChat.markMessagesDelivered,
);
exports.deletePrivateChat = onCall(
  { region: "us-central1" },
  privateChat.deleteChat,
);
exports.saveEventDraft = onCall(
  { region: "us-central1" },
  eventsDomain.saveEventDraft,
);
exports.publishEvent = onCall(
  { region: "us-central1" },
  eventsDomain.publishEvent,
);
exports.cancelEvent = onCall(
  { region: "us-central1" },
  eventsDomain.cancelEvent,
);
exports.endEvent = onCall(
  { region: "us-central1" },
  eventsDomain.endEvent,
);
exports.archiveEvent = onCall(
  { region: "us-central1" },
  eventsDomain.archiveEvent,
);
exports.deleteEventDraft = onCall(
  { region: "us-central1" },
  eventsDomain.deleteEventDraft,
);
exports.joinEvent = onCall(
  { region: "us-central1" },
  eventsDomain.joinEvent,
);
exports.leaveEvent = onCall(
  { region: "us-central1" },
  eventsDomain.leaveEvent,
);
exports.submitEventResponse = onCall(
  { region: "us-central1" },
  eventsDomain.submitEventResponse,
);
exports.createGame = onCall(
  { region: "us-central1" },
  gamesDomain.createGame,
);
exports.initializeGame = onCall(
  { region: "us-central1" },
  gamesDomain.initializeGame,
);
exports.joinGame = onCall(
  { region: "us-central1" },
  gamesDomain.joinGame,
);
exports.leaveGame = onCall(
  { region: "us-central1" },
  gamesDomain.leaveGame,
);
exports.startGame = onCall(
  { region: "us-central1" },
  gamesDomain.startGame,
);
exports.pauseGame = onCall(
  { region: "us-central1" },
  gamesDomain.pauseGame,
);
exports.resumeGame = onCall(
  { region: "us-central1" },
  gamesDomain.resumeGame,
);
exports.submitGameAction = onCall(
  { region: "us-central1" },
  gamesDomain.submitGameAction,
);
exports.endGame = onCall(
  { region: "us-central1" },
  gamesDomain.endGame,
);
exports.cancelGame = onCall(
  { region: "us-central1" },
  gamesDomain.cancelGame,
);
exports.processExpiredGames = onSchedule(
  { region: "us-central1", schedule: "every 1 minutes" },
  gamesDomain.processExpiredGames,
);
exports.createMafiaGame = onCall(
  { region: "us-central1" },
  mafiaDomain.createMafiaGame,
);
exports.joinMafiaGame = onCall(
  { region: "us-central1" },
  mafiaDomain.joinMafiaGame,
);
exports.startMafiaGame = onCall(
  { region: "us-central1" },
  mafiaDomain.startMafiaGame,
);
exports.getAchievements = onCall(
  { region: "us-central1" },
  achievementsDomain.getAchievements,
);
exports.saveFanWorkDraft = onCall(
  { region: "us-central1" },
  fanWorksDomain.saveFanWorkDraft,
);
exports.publishFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.publishFanWork,
);
exports.revisePublishedFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.revisePublishedFanWork,
);
exports.requestFanWorkRemoval = onCall(
  { region: "us-central1" },
  fanWorksDomain.requestFanWorkRemoval,
);
exports.archiveFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.archiveFanWork,
);
exports.deleteFanWorkDraft = onCall(
  { region: "us-central1" },
  fanWorksDomain.deleteFanWorkDraft,
);
exports.startFanWorkMediaUpload = onCall(
  { region: "us-central1" },
  fanWorksDomain.startFanWorkMediaUpload,
);
exports.confirmFanWorkMedia = onCall(
  { region: "us-central1" },
  fanWorksDomain.confirmFanWorkMedia,
);
exports.likeFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.likeFanWork,
);
exports.bookmarkFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.bookmarkFanWork,
);
exports.reportFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.reportFanWork,
);
exports.rateFanWork = onCall(
  { region: "us-central1" },
  fanWorksDomain.rateFanWork,
);
exports.addFanWorkComment = onCall(
  { region: "us-central1" },
  fanWorksDomain.commentFanWork,
);
exports.fanWorkCommentAction = onCall(
  { region: "us-central1" },
  fanWorksDomain.fanWorkCommentAction,
);
exports.getEconomy = onCall(
  { region: "us-central1" },
  economyDomain.getEconomy,
);
exports.getInventory = onCall(
  { region: "us-central1" },
  economyDomain.getInventory,
);
exports.getEconomyTransactions = onCall(
  { region: "us-central1" },
  economyDomain.getEconomyTransactions,
);
exports.getPremiumEntitlement = onCall(
  { region: "us-central1" },
  economyDomain.getPremiumEntitlement,
);
exports.restorePremiumPurchases = onCall(
  { region: "us-central1" },
  economyDomain.restorePremiumPurchases,
);
exports.claimEconomyReward = onCall(
  { region: "us-central1" },
  economyDomain.claimEconomyReward,
);
exports.purchaseStoreItem = onCall(
  { region: "us-central1" },
  economyDomain.purchaseStoreItem,
);
exports.equipCosmetic = onCall(
  { region: "us-central1" },
  economyDomain.equipCosmetic,
);
exports.unequipCosmetic = onCall(
  { region: "us-central1" },
  economyDomain.unequipCosmetic,
);
exports.processEventLifecycle = onSchedule(
  { region: "us-central1", schedule: "every 1 minutes" },
  eventsDomain.processEventLifecycle,
);
exports.processGroupChatMedia = onObjectFinalized(
  { region: "europe-west3", memory: "1GiB", timeoutSeconds: 300 },
  createGroupMediaPipeline({
    db: getFirestore(),
    bucket: getStorage().bucket(),
    randomUUID,
  }),
);
exports.recalculateInviteRanks = onDocumentUpdated(
  "groups/{groupId}/invites/{inviteId}",
  groupsDomain.recalculateInviteRanks,
);

exports.giveRespect = onCall(
  { region: "us-central1" },
  socialGraph.giveRespect,
);
exports.sendFriendRequest = onCall(
  { region: "us-central1" },
  socialGraph.sendFriendRequest,
);
exports.respondToFriendRequest = onCall(
  { region: "us-central1" },
  socialGraph.respondToFriendRequest,
);
exports.removeFriend = onCall(
  { region: "us-central1" },
  socialGraph.removeFriend,
);
exports.blockUser = onCall(
  { region: "us-central1" },
  socialGraph.blockUser,
);
exports.markNotificationRead = onCall(
  { region: "us-central1" },
  notificationCallables.markRead,
);
exports.markAllNotificationsRead = onCall(
  { region: "us-central1" },
  notificationCallables.markAllRead,
);
exports.registerFcmToken = onCall(
  { region: "us-central1" },
  notificationCallables.registerToken,
);
exports.unregisterFcmToken = onCall(
  { region: "us-central1" },
  notificationCallables.unregisterToken,
);

// PROMPT 08 replaces the legacy group-push implementation below with one
// central, deterministic builder and batched token lookup.
exports.onNewGroupMessage = onDocumentCreated(
  "groups/{groupId}/messages/{messageId}",
  notificationTriggers.groupMessage,
);
exports.onJoinRequest = onDocumentCreated(
  "groups/{groupId}/requests/{requestId}",
  notificationTriggers.joinRequest,
);
exports.onJoinRequestDecision = onDocumentUpdated(
  "groups/{groupId}/requests/{requestId}",
  notificationTriggers.joinDecision,
);
exports.onFriendRequest = onDocumentCreated(
  "friendships/{friendshipId}",
  notificationTriggers.friendRequest,
);
exports.onRespectReceived = onDocumentCreated(
  "respects/{respectId}",
  notificationTriggers.respectReceived,
);
exports.unblockUser = onCall(
  { region: "us-central1" },
  socialGraph.unblockUser,
);

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

const legacyOnNewGroupMessage = onDocumentCreated(
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

// Replaces the legacy per-token FCM path with the PROMPT 08 builder so
// unreadPrivateMessagesCount and push share one idempotent write.
exports.onNewPrivateMessage = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  notificationTriggers.privateMessage,
);

const legacyOnJoinRequest = onDocumentCreated(
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